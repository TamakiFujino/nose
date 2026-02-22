import UIKit
import RealityKit
import FirebaseStorage
import Foundation

@MainActor
final class AvatarResourceManager {
    static let shared = AvatarResourceManager()
    private init() {
        // Configure URLCache
        cache.diskCapacity = maxCacheSize
        cache.memoryCapacity = maxCacheSize / 2
        
        // Start periodic cache cleanup
        startCacheCleanup()
    }

    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    private var modelEntities: [String: ModelEntity] = [:]
    private var modelFileURLs: [String: URL] = [:]
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private var cachedColors: [String] = [] // Store hex strings directly
    private var cachedModels: [String: [String: [String]]] = [:]
    private let cache = URLCache.shared
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    private var loadingTasks: [String: Task<ModelEntity?, Error>] = [:]
    private var loadedCategories: Set<String> = []  // Track loaded categories
    private var thumbnailLoadingTasks: [String: Task<UIImage?, Error>] = [:]
    private let thumbnailSize: CGSize = CGSize(width: 200, height: 200) // Low-res thumbnail size
    private var loadedThumbnails: Set<String> = [] // Track loaded thumbnails
    private let thumbnailLoadingQueue = DispatchQueue(label: "com.avatar.thumbnailLoading", qos: .userInitiated)
    private let thumbnailTaskQueue = DispatchQueue(label: "com.avatar.thumbnailTaskSync", qos: .userInitiated)
    // LRU cache management for modelEntities
    private let maxCachedModels = 50
    private var modelAccessTimes: [String: Date] = [:]

    // MARK: - Directory for caching
    private var cacheDirectory: URL {
        let cache = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AvatarModels", isDirectory: true)
        if !fileManager.fileExists(atPath: cache.path) {
            try? fileManager.createDirectory(at: cache, withIntermediateDirectories: true, attributes: nil)
        }
        return cache
    }

    // MARK: - Preload all resources (colors & model index jsons)
    func preloadAllResources() async throws {
        Logger.log("Starting to preload all resources...", level: .debug, category: "AvatarRes")
        
        // Load colors and models concurrently
        async let colorsTask = loadColors()
        async let modelsTask = loadModels()
        
        // Wait for both tasks to complete
        let colors = try await colorsTask
        let models = try await modelsTask
        
        // Store the loaded data
        cachedColors = colors.map { color in
            color.toHexString()
        }
        cachedModels = models
        
        Logger.log("Preloaded \(colors.count) colors and \(models.count) model categories", level: .info, category: "AvatarRes")
    }

    private func loadColors() async throws -> [UIColor] {
        Logger.log("Loading colors...", level: .debug, category: "AvatarRes")

        let jsonRef = storage.reference().child("avatar_assets/json/colors.json")
        let maxSize: Int64 = 10 * 1024 // 10KB is more than enough for hex codes

        do {
            let data = try await jsonRef.data(maxSize: maxSize)
            Logger.log("Downloaded colors.json: \(String(data: data, encoding: .utf8) ?? "unable to decode")", level: .debug, category: "AvatarRes")

            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let colorObjects = jsonObject as? [[String: String]] else {
                Logger.log("colors.json is not in expected format [[String: String]]", level: .error, category: "AvatarRes")
                return []
            }

            Logger.log("Found \(colorObjects.count) color objects", level: .debug, category: "AvatarRes")

            let colors: [UIColor] = colorObjects.compactMap { obj -> UIColor? in
                guard let hex = obj["hex"] else {
                    Logger.log("Skipping color object due to missing 'hex'", level: .warn, category: "AvatarRes")
                    return nil
                }
                guard let color = UIColor(hex: hex) else {
                    Logger.log("Failed to convert hex '\(hex)' to UIColor", level: .warn, category: "AvatarRes")
                    return nil
                }
                // Store hex in cachedColors
                cachedColors.append(hex)
                Logger.log("Converted hex \(hex) to color: \(color.toHexString())", level: .debug, category: "AvatarRes")
                return color
            }

            Logger.log("Successfully loaded \(colors.count) valid colors", level: .info, category: "AvatarRes")
            return colors
        } catch {
            Logger.log("Error loading colors.json: \(error.localizedDescription)", level: .error, category: "AvatarRes")
            throw error
        }
    }

    private func loadModels() async throws -> [String: [String: [String]]] {
        Logger.log("Loading models...", level: .debug, category: "AvatarRes")
        
        // Load categories dynamically from Firebase Storage
        try await DynamicCategoryManager.shared.loadCategories()
        
        // Get the loaded categories
        let categoryGroups = DynamicCategoryManager.shared.getCategoryGroups()
        var allModels: [String: [String: [String]]] = [:]
        
        // Load models for each main category
        for (mainCategory, subcategories) in categoryGroups {
            var categoryModels: [String: [String]] = [:]
            
            for subcategory in subcategories {
                let models = DynamicCategoryManager.shared.getModels(for: mainCategory, subcategory: subcategory)
                categoryModels[subcategory] = models
            }
            
            allModels[mainCategory] = categoryModels
        }
        
        Logger.log("Successfully loaded models from all categories", level: .info, category: "AvatarRes")
        return allModels
    }
    
    // MARK: - API for color/model index
    var colorModels: [String] {  // Return hex strings directly
        cachedColors
    }

    /// Get models for a specific category and subcategory
    func models(for category: String, subcategory: String) -> [String] {
        return cachedModels[category]?[subcategory] ?? []
    }

    /// Get all subcategories for a category
    func subcategories(for category: String) -> [String] {
        guard let categoryDict = cachedModels[category] else { return [] }
        return Array(categoryDict.keys)
    }

    // MARK: - ModelEntity Loading (with download & cache)
    func loadModelEntity(named modelName: String) async throws -> ModelEntity {
        // Check memory cache first
        if let entity = modelEntities[modelName] {
            // Update access time for LRU
            modelAccessTimes[modelName] = Date()
            Logger.log("Using cached model entity for: \(modelName)", level: .debug, category: "AvatarRes")
            return entity.clone(recursive: true)
        }
        
        // Check if there's an ongoing loading task
        if let existingTask = loadingTasks[modelName] {
            Logger.log("Using existing loading task for: \(modelName)", level: .debug, category: "AvatarRes")
            do {
                let entity = try await existingTask.value
                guard let entity = entity else {
                    throw NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to load model: \(modelName)"])
                }
                return entity.clone(recursive: true)
            } catch {
                Logger.log("Error in existing task for \(modelName): \(error)", level: .error, category: "AvatarRes")
                // Remove failed task and continue with new task
                loadingTasks.removeValue(forKey: modelName)
            }
        }
        
        // Create new loading task
        let task = Task<ModelEntity?, Error> { [weak self] in
            guard let self = self else {
                throw NSError(domain: "AvatarResourceManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Resource manager deallocated"])
            }
            
            let modelFileURL = self.cacheDirectory.appendingPathComponent("\(modelName).usdz")
            
            // Check if file exists in cache
            if self.fileManager.fileExists(atPath: modelFileURL.path) {
                Logger.log("Found cached file for: \(modelName)", level: .debug, category: "AvatarRes")
                do {
                    let modelEntity = try await self.loadModelFromFile(modelFileURL)
                    await self.applyOptimizedMaterials(to: modelEntity)
                    self.modelEntities[modelName] = modelEntity
                    self.modelFileURLs[modelName] = modelFileURL
                    // Update access time for LRU
                    self.modelAccessTimes[modelName] = Date()
                    // LRU eviction if needed
                    if self.modelEntities.count > self.maxCachedModels {
                        let sorted = self.modelAccessTimes.sorted { $0.value < $1.value }
                        let toRemove = sorted.prefix(self.modelEntities.count - self.maxCachedModels)
                        for (oldModel, _) in toRemove {
                            self.modelEntities.removeValue(forKey: oldModel)
                            self.modelAccessTimes.removeValue(forKey: oldModel)
                            self.modelFileURLs.removeValue(forKey: oldModel)
                        }
                    }
                    return modelEntity
                } catch {
                    Logger.log("Error loading cached model: \(error)", level: .error, category: "AvatarRes")
                    // Continue to download if cached file is corrupted
                }
            }
            
            // Download if not in cache
            Logger.log("Downloading model: \(modelName)", level: .debug, category: "AvatarRes")
            try await self.downloadModel(named: modelName, to: modelFileURL)
            
            let modelEntity = try await self.loadModelFromFile(modelFileURL)
            await self.applyOptimizedMaterials(to: modelEntity)
            self.modelEntities[modelName] = modelEntity
            self.modelFileURLs[modelName] = modelFileURL
            // Update access time for LRU
            self.modelAccessTimes[modelName] = Date()
            // LRU eviction if needed
            if self.modelEntities.count > self.maxCachedModels {
                let sorted = self.modelAccessTimes.sorted { $0.value < $1.value }
                let toRemove = sorted.prefix(self.modelEntities.count - self.maxCachedModels)
                for (oldModel, _) in toRemove {
                    self.modelEntities.removeValue(forKey: oldModel)
                    self.modelAccessTimes.removeValue(forKey: oldModel)
                    self.modelFileURLs.removeValue(forKey: oldModel)
                }
            }
            return modelEntity
        }
        
        // Store task and clean up when done
        loadingTasks[modelName] = task
        
        do {
            let entity = try await task.value
            guard let entity = entity else {
                // Clean up task after failure
                loadingTasks.removeValue(forKey: modelName)
                throw NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to load model: \(modelName)"])
            }
            // Clean up task after successful completion
            loadingTasks.removeValue(forKey: modelName)
            return entity.clone(recursive: true)
        } catch {
            // Clean up task after error
            loadingTasks.removeValue(forKey: modelName)
            Logger.log("Error loading model for \(modelName): \(error)", level: .error, category: "AvatarRes")
            throw error
        }
    }
    
    private func applyOptimizedMaterials(to entity: ModelEntity) async {
        guard let model = entity.model else { return }
        
        // Guard against missing materials after clone
        guard !model.materials.isEmpty else {
            Logger.log("Model has no materials, skipping optimization: \(entity.name)", level: .error, category: "AvatarRes")
            return
        }
        
        let optimizedMaterials = model.materials.map { material -> Material in
            if var simpleMaterial = material as? SimpleMaterial {
                simpleMaterial.roughness = 0.5
                simpleMaterial.metallic = 0.0
                return simpleMaterial
            }
            return material
        }
        
        // Ensure material assignment happens on main queue
        await MainActor.run {
            entity.model = ModelComponent(mesh: model.mesh, materials: optimizedMaterials)
        }
    }
    
    private func loadModelFromFile(_ fileURL: URL) async throws -> ModelEntity {
        // Validate file
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model file not found at path: \(fileURL.path)"])
        }
        
        // Check file size
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            throw NSError(domain: "AvatarResourceManager", code: 422, userInfo: [NSLocalizedDescriptionKey: "Model file is empty"])
        }
        
        Logger.log("Loading model from file: \(fileURL.lastPathComponent)", level: .debug, category: "AvatarRes")
        Logger.log("File size: \(fileSize) bytes", level: .debug, category: "AvatarRes")
        
        // Load model based on iOS version
        let entity: ModelEntity
        if #available(iOS 15.0, *) {
            do {
                Logger.log("Using ModelEntity.loadModel...", level: .debug, category: "AvatarRes")
                entity = try await ModelEntity.loadModel(contentsOf: fileURL)
            } catch {
                Logger.log("ModelEntity.loadModel failed: \(error)", level: .error, category: "AvatarRes")
                throw error
            }
        } else {
            do {
                Logger.log("Using ModelEntity.load...", level: .debug, category: "AvatarRes")
                let loadedEntity = try await ModelEntity.load(contentsOf: fileURL)
                guard let modelEntity = loadedEntity as? ModelEntity else {
                    Logger.log("Loaded entity is not a ModelEntity", level: .error, category: "AvatarRes")
                    throw NSError(domain: "AvatarResourceManager", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid model type"])
                }
                entity = modelEntity
            } catch {
                Logger.log("ModelEntity.load failed: \(error)", level: .error, category: "AvatarRes")
                throw error
            }
        }
        
        // Optimize entity settings
        Logger.log("Optimizing entity settings...", level: .debug, category: "AvatarRes")
        entity.generateCollisionShapes(recursive: false)
        entity.components[PhysicsBodyComponent.self] = nil
        
        Logger.log("Model loaded and optimized successfully", level: .info, category: "AvatarRes")
        return entity
    }

    private func downloadModel(named modelName: String, to fileURL: URL) async throws {
        let (category, subcategory) = AvatarResourceManager.getCategoryAndSubcategory(from: modelName)
        let remotePath = "avatar_assets/models/\(category)/\(subcategory)/\(modelName).usdz"
        let modelRef = storage.reference().child(remotePath)
        
        // Use a more efficient download method
        let maxSize: Int64 = 10 * 1024 * 1024 // 10MB max size
        let data = try await modelRef.data(maxSize: maxSize)
        try data.write(to: fileURL)
    }

    // MARK: - Thumbnail Loading & Caching
    func loadThumbnail(for modelName: String) async throws -> UIImage {
        // Check memory cache first
        if let cached = thumbnailCache.object(forKey: modelName as NSString) {
            Logger.log("Using cached thumbnail for: \(modelName)", level: .debug, category: "AvatarRes")
            return cached
        }
        
        // Check if there's an ongoing loading task with synchronization
        let existingTask = await withCheckedContinuation { continuation in
            thumbnailTaskQueue.async {
                let task = self.thumbnailLoadingTasks[modelName]
                continuation.resume(returning: task)
            }
        }
        
        if let existingTask = existingTask {
            Logger.log("Using existing thumbnail loading task for: \(modelName)", level: .debug, category: "AvatarRes")
            do {
                if let image = try await existingTask.value {
                    return image
                }
            } catch {
                Logger.log("Error in existing task for \(modelName): \(error)", level: .error, category: "AvatarRes")
                // Remove failed task and continue with new task
                await withCheckedContinuation { continuation in
                    thumbnailTaskQueue.async {
                        self.thumbnailLoadingTasks.removeValue(forKey: modelName)
                        continuation.resume(returning: ())
                    }
                }
            }
        }
        
        // Create new loading task
        let task = Task<UIImage?, Error> { [weak self] in
            guard let self = self else {
                throw NSError(domain: "AvatarResourceManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Resource manager deallocated"])
            }
            
            let (category, subcategory) = AvatarResourceManager.getCategoryAndSubcategory(from: modelName)
            let remotePath = "avatar_assets/thumbnails/\(category)/\(subcategory)/\(modelName).jpg"
            let thumbnailRef = self.storage.reference().child(remotePath)
            
            do {
                let data = try await thumbnailRef.data(maxSize: 1 * 1024 * 1024)
                guard let image = UIImage(data: data) else {
                    throw NSError(domain: "AvatarResourceManager", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid image data for: \(modelName)"])
                }
                
                // Resize image on background queue
                let resizedImage = await self.resizeImage(image, to: self.thumbnailSize)
                
                // Cache the resized image
                self.thumbnailCache.setObject(resizedImage, forKey: modelName as NSString)
                
                // Synchronize access to loadedThumbnails
                await withCheckedContinuation { continuation in
                    self.thumbnailTaskQueue.async {
                        self.loadedThumbnails.insert(modelName)
                        continuation.resume(returning: ())
                    }
                }
                
                return resizedImage
            } catch {
                Logger.log("Failed to load thumbnail for \(modelName): \(error)", level: .error, category: "AvatarRes")
                throw error
            }
        }
        
        // Store task with synchronization
        await withCheckedContinuation { continuation in
            thumbnailTaskQueue.async {
                self.thumbnailLoadingTasks[modelName] = task
                continuation.resume(returning: ())
            }
        }
        
        do {
            if let image = try await task.value {
                // Clean up task after successful completion
                await withCheckedContinuation { continuation in
                    thumbnailTaskQueue.async {
                        self.thumbnailLoadingTasks.removeValue(forKey: modelName)
                        continuation.resume(returning: ())
                    }
                }
                return image
            } else {
                // Clean up task after failure
                await withCheckedContinuation { continuation in
                    thumbnailTaskQueue.async {
                        self.thumbnailLoadingTasks.removeValue(forKey: modelName)
                        continuation.resume(returning: ())
                    }
                }
                throw NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to load thumbnail for: \(modelName)"])
            }
        } catch {
            // Clean up task after error
            await withCheckedContinuation { continuation in
                thumbnailTaskQueue.async {
                    self.thumbnailLoadingTasks.removeValue(forKey: modelName)
                    continuation.resume(returning: ())
                }
            }
            Logger.log("Error loading thumbnail for \(modelName): \(error)", level: .error, category: "AvatarRes")
            throw error
        }
    }
    
    // MARK: - Batch Thumbnail Loading
    func loadThumbnails(for models: [String]) async throws -> [String: UIImage] {
        Logger.log("Loading \(models.count) thumbnails...", level: .debug, category: "AvatarRes")
        var results: [String: UIImage] = [:]
        
        // Filter out already loaded thumbnails with synchronization
        let modelsToLoad = await withCheckedContinuation { continuation in
            thumbnailTaskQueue.async {
                let modelsToLoad = models.filter { !self.loadedThumbnails.contains($0) }
                continuation.resume(returning: modelsToLoad)
            }
        }
        
        // Load thumbnails concurrently with a limit
        try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
            let semaphore = DispatchSemaphore(value: 3) // Limit concurrent downloads
            
            for modelName in modelsToLoad {
                group.addTask {
                    semaphore.wait()
                    defer { semaphore.signal() }
                    
                    let image = try await self.loadThumbnail(for: modelName)
                    return (modelName, image)
                }
            }
            
            // Collect results
            for try await (modelName, image) in group {
                results[modelName] = image
            }
        }
        
        Logger.log("Loaded \(results.count) thumbnails", level: .info, category: "AvatarRes")
        return results
    }
    
    // MARK: - Image Processing
    private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        await withCheckedContinuation { continuation in
            thumbnailLoadingQueue.async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let resizedImage = renderer.image { context in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                continuation.resume(returning: resizedImage)
            }
        }
    }
    
    func clearCache() {
        modelEntities.removeAll()
        modelFileURLs.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
        _ = cacheDirectory
        thumbnailCache.removeAllObjects()
        cachedColors.removeAll()
        cachedModels.removeAll()
        loadedCategories.removeAll()
        
        // Synchronize clearing of thumbnail-related data
        thumbnailTaskQueue.sync {
            loadedThumbnails.removeAll()  // Clear loaded thumbnails tracking
            thumbnailLoadingTasks.removeAll()  // Clear thumbnail loading tasks
        }
        
        modelAccessTimes.removeAll() // Clear model access times
    }

    // MARK: - Utility: Category/Subcategory Mapping
    static func getCategoryAndSubcategory(from modelName: String) -> (category: String, subcategory: String) {
        // Use DynamicCategoryManager if available
        if DynamicCategoryManager.shared.isCategoriesLoaded() {
            let categoryGroups = DynamicCategoryManager.shared.getCategoryGroups()
            
            // Search through all categories and subcategories to find the model
            for (mainCategory, subcategories) in categoryGroups {
                for subcategory in subcategories {
                    // Get the models for this subcategory
                    let models = DynamicCategoryManager.shared.getModels(for: mainCategory, subcategory: subcategory)
                    
                    // Check if the model name exists in this subcategory's models
                    if models.contains(modelName) {
                        return (mainCategory, subcategory)
                    }
                }
            }
            
            // If we can't determine the category, log an error and return a safe default
            Logger.log("Could not determine category for model: \(modelName)", level: .warn, category: "AvatarRes")
            if let firstCategory = categoryGroups.first {
                return (firstCategory.key, firstCategory.value.first ?? "unknown")
            }
        }
        
        // If DynamicCategoryManager is not loaded, we can't determine the category
        // This should not happen in normal operation since categories are loaded before models
        Logger.log("DynamicCategoryManager not loaded, cannot determine category for model: \(modelName)", level: .error, category: "AvatarRes")
        return ("unknown", "unknown")
    }

    // MARK: - Cache Management
    private func startCacheCleanup() {
        // Clean cache every 24 hours
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.cleanCache()
        }
    }
    
    private func cleanCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            // Sort files by modification date
            let sortedFiles = try contents.sorted { url1, url2 in
                let date1 = try url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                let date2 = try url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // Remove oldest files if cache size exceeds limit
            var currentSize = try getCacheSize()
            for file in sortedFiles {
                if currentSize <= maxCacheSize {
                    break
                }
                let fileSize = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                try fileManager.removeItem(at: file)
                currentSize -= fileSize
            }
        } catch {
            Logger.log("Error cleaning cache: \(error)", level: .error, category: "AvatarRes")
        }
    }
    
    private func getCacheSize() throws -> Int {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        return try contents.reduce(0) { sum, url in
            sum + (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
    }
    
    // MARK: - Cache Operations
    private func getCachedFilePath(for path: String) -> URL {
        // Create a unique filename based on the Firebase path
        let filename = path.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    private func isFileCached(at path: String) -> Bool {
        let filePath = getCachedFilePath(for: path)
        return fileManager.fileExists(atPath: filePath.path)
    }
    
    private func saveToCache(data: Data, for path: String) {
        let filePath = getCachedFilePath(for: path)
        try? data.write(to: filePath)
    }
    
    private func loadFromCache(for path: String) -> Data? {
        let filePath = getCachedFilePath(for: path)
        return try? Data(contentsOf: filePath)
    }
    
    // MARK: - Category Loading
    func loadCategory(_ category: String) async throws {
        // Check if category is already loaded
        if loadedCategories.contains(category) {
            Logger.log("Category \(category) already loaded", level: .info, category: "AvatarRes")
            return
        }
        
        Logger.log("Loading category: \(category)", level: .debug, category: "AvatarRes")
        guard let subcategories = cachedModels[category] else {
            Logger.log("Category \(category) not found in cached models", level: .error, category: "AvatarRes")
            return
        }
        
        // Load all models in the category concurrently
        var tasks: [Task<Void, Error>] = []
        for (_, models) in subcategories {
            for modelName in models {
                let task = Task {
                    _ = try await loadModelEntity(named: modelName)
                }
                tasks.append(task)
            }
        }
        
        // Wait for all models to load
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }
            try await group.waitForAll()
        }
        
        // Mark category as loaded
        loadedCategories.insert(category)
        Logger.log("Category \(category) loaded successfully", level: .info, category: "AvatarRes")
    }
}
