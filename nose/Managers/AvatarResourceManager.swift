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
    private var modelCache: [String: ModelEntity] = [:]
    private var loadingTasks: [String: Task<ModelEntity?, Error>] = [:]
    private var loadedCategories: Set<String> = []  // Track loaded categories
    private var thumbnailLoadingTasks: [String: Task<UIImage?, Error>] = [:]
    private let thumbnailSize: CGSize = CGSize(width: 200, height: 200) // Low-res thumbnail size
    private var loadedThumbnails: Set<String> = [] // Track loaded thumbnails
    private let thumbnailLoadingQueue = DispatchQueue(label: "com.avatar.thumbnailLoading", qos: .userInitiated)

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
        print("🔄 Starting to preload all resources...")
        
        // Load colors and models concurrently
        async let colorsTask = loadColors()
        async let modelsTask = loadModels()
        
        // Wait for both tasks to complete
        let colors = try await colorsTask
        let models = try await modelsTask
        
        // Store the loaded data
        cachedColors = colors.map { color in
            color.toHexString() ?? ""
        }
        cachedModels = models
        
        print("✅ Preloaded \(colors.count) colors and \(models.count) model categories")
    }

    private func loadColors() async throws -> [UIColor] {
        print("🔄 Loading colors...")

        let jsonRef = storage.reference().child("avatar_assets/json/colors.json")
        let maxSize: Int64 = 10 * 1024 // 10KB is more than enough for hex codes

        do {
            let data = try await jsonRef.data(maxSize: maxSize)
            print("📦 Downloaded colors.json: \(String(data: data, encoding: .utf8) ?? "unable to decode")")

            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let colorObjects = jsonObject as? [[String: String]] else {
                print("❌ colors.json is not in expected format [[String: String]]")
                return []
            }

            print("🎨 Found \(colorObjects.count) color objects")

            let colors: [UIColor] = colorObjects.compactMap { obj -> UIColor? in
                guard let hex = obj["hex"] else {
                    print("⚠️ Skipping color object due to missing 'hex'")
                    return nil
                }
                guard let color = UIColor(hex: hex) else {
                    print("⚠️ Failed to convert hex '\(hex)' to UIColor")
                    return nil
                }
                // Store hex in cachedColors
                cachedColors.append(hex)
                print("🎨 Converted hex \(hex) to color: \(color.toHexString() ?? "n/a")")
                return color
            }

            print("✅ Successfully loaded \(colors.count) valid colors")
            return colors
        } catch {
            print("❌ Error loading colors.json: \(error.localizedDescription)")
            throw error
        }
    }

    private func loadModels() async throws -> [String: [String: [String]]] {
        print("🔄 Loading models...")
        
        // Load each JSON file concurrently using AvatarCategory constants
        async let bodyTask = loadModelFile(AvatarCategory.jsonFiles[AvatarCategory.body] ?? "")
        async let clothesTask = loadModelFile(AvatarCategory.jsonFiles[AvatarCategory.clothes] ?? "")
        async let hairTask = loadModelFile(AvatarCategory.jsonFiles[AvatarCategory.hair] ?? "")
        async let accessoriesTask = loadModelFile(AvatarCategory.jsonFiles[AvatarCategory.accessories] ?? "")
        
        // Wait for all tasks to complete
        let body = try await bodyTask
        let clothes = try await clothesTask
        let hair = try await hairTask
        let accessories = try await accessoriesTask
        
        // Combine all models using AvatarCategory constants
        var allModels: [String: [String: [String]]] = [:]
        allModels[AvatarCategory.body] = body
        allModels[AvatarCategory.clothes] = clothes
        allModels[AvatarCategory.hair] = hair
        allModels[AvatarCategory.accessories] = accessories
        
        print("✅ Successfully loaded models from all categories")
        return allModels
    }
    
    private func loadModelFile(_ filename: String) async throws -> [String: [String]] {
        let jsonRef = storage.reference().child("avatar_assets/json/\(filename)")
        let maxSize: Int64 = 1 * 1024 * 1024 // 1MB
        
        do {
            let data = try await jsonRef.data(maxSize: maxSize)
            print("📦 Downloaded \(filename): \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let modelObjects = json as? [String: [String]] else {
                print("❌ \(filename) is not in expected format [String: [String]]")
                return [:]
            }
            
            print("✅ Successfully loaded \(modelObjects.count) categories from \(filename)")
            return modelObjects
        } catch let error as NSError {
            if error.domain == "com.google.HTTPStatus" && error.code == 404 {
                print("⚠️ \(filename) not found in Firebase Storage. Using empty model list.")
                return [:]
            }
            print("❌ Error loading \(filename): \(error.localizedDescription)")
            throw error
        }
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
            print("📦 Using cached model entity for: \(modelName)")
            return entity.clone(recursive: true)
        }
        
        // Check if there's an ongoing loading task
        if let existingTask = loadingTasks[modelName] {
            print("⏳ Using existing loading task for: \(modelName)")
            do {
                if let entity = try await existingTask.value {
                    return entity.clone(recursive: true)
                }
            } catch {
                print("❌ Error in existing task for \(modelName): \(error)")
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
                print("📦 Found cached file for: \(modelName)")
                do {
                    let modelEntity = try await self.loadModelFromFile(modelFileURL)
                    self.applyOptimizedMaterials(to: modelEntity)
                    self.modelEntities[modelName] = modelEntity
                    self.modelFileURLs[modelName] = modelFileURL
                    return modelEntity
                } catch {
                    print("❌ Error loading cached model: \(error)")
                }
            }
            
            // Download if not in cache
            print("⬇️ Downloading model: \(modelName)")
            try await self.downloadModel(named: modelName, to: modelFileURL)
            
            let modelEntity = try await self.loadModelFromFile(modelFileURL)
            self.applyOptimizedMaterials(to: modelEntity)
            self.modelEntities[modelName] = modelEntity
            self.modelFileURLs[modelName] = modelFileURL
            return modelEntity
        }
        
        // Store task and clean up when done
        loadingTasks[modelName] = task
        
        do {
            if let entity = try await task.value {
                // Clean up task after successful completion
                loadingTasks.removeValue(forKey: modelName)
                return entity.clone(recursive: true)
            } else {
                // Clean up task after failure
                loadingTasks.removeValue(forKey: modelName)
                throw NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to load model: \(modelName)"])
            }
        } catch {
            // Clean up task after error
            loadingTasks.removeValue(forKey: modelName)
            print("❌ Error loading model for \(modelName): \(error)")
            throw error
        }
    }
    
    private func applyOptimizedMaterials(to entity: ModelEntity) {
        guard let model = entity.model else { return }
        let optimizedMaterials = model.materials.map { material -> Material in
            if var simpleMaterial = material as? SimpleMaterial {
                simpleMaterial.roughness = 0.5
                simpleMaterial.metallic = 0.0
                return simpleMaterial
            }
            return material
        }
        entity.model = ModelComponent(mesh: model.mesh, materials: optimizedMaterials)
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
        
        print("🔍 Loading model from file: \(fileURL.lastPathComponent)")
        print("📊 File size: \(fileSize) bytes")
        
        // Load model based on iOS version
        let entity: ModelEntity
        if #available(iOS 15.0, *) {
            do {
                print("🔄 Using ModelEntity.loadModel...")
                entity = try await ModelEntity.loadModel(contentsOf: fileURL)
            } catch {
                print("❌ ModelEntity.loadModel failed: \(error)")
                throw error
            }
        } else {
            do {
                print("🔄 Using ModelEntity.load...")
                let loadedEntity = try await ModelEntity.load(contentsOf: fileURL)
                guard let modelEntity = loadedEntity as? ModelEntity else {
                    print("❌ Loaded entity is not a ModelEntity")
                    throw NSError(domain: "AvatarResourceManager", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid model type"])
                }
                entity = modelEntity
            } catch {
                print("❌ ModelEntity.load failed: \(error)")
                throw error
            }
        }
        
        // Optimize entity settings
        print("⚙️ Optimizing entity settings...")
        entity.generateCollisionShapes(recursive: false)
        entity.components[PhysicsBodyComponent.self] = nil
        
        print("✅ Model loaded and optimized successfully")
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
            print("📦 Using cached thumbnail for: \(modelName)")
            return cached
        }
        
        // Check if there's an ongoing loading task
        if let existingTask = thumbnailLoadingTasks[modelName] {
            print("⏳ Using existing thumbnail loading task for: \(modelName)")
            do {
                if let image = try await existingTask.value {
                    return image
                }
            } catch {
                print("❌ Error in existing task for \(modelName): \(error)")
                // Remove failed task and continue with new task
                thumbnailLoadingTasks.removeValue(forKey: modelName)
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
                self.loadedThumbnails.insert(modelName)
                
                return resizedImage
            } catch {
                print("❌ Failed to load thumbnail for \(modelName): \(error)")
                throw error
            }
        }
        
        // Store task and clean up when done
        thumbnailLoadingTasks[modelName] = task
        
        do {
            if let image = try await task.value {
                // Clean up task after successful completion
                thumbnailLoadingTasks.removeValue(forKey: modelName)
                return image
            } else {
                // Clean up task after failure
                thumbnailLoadingTasks.removeValue(forKey: modelName)
                throw NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to load thumbnail for: \(modelName)"])
            }
        } catch {
            // Clean up task after error
            thumbnailLoadingTasks.removeValue(forKey: modelName)
            print("❌ Error loading thumbnail for \(modelName): \(error)")
            throw error
        }
    }
    
    // MARK: - Batch Thumbnail Loading
    func loadThumbnails(for models: [String]) async throws -> [String: UIImage] {
        print("🔄 Loading \(models.count) thumbnails...")
        var results: [String: UIImage] = [:]
        
        // Filter out already loaded thumbnails
        let modelsToLoad = models.filter { !loadedThumbnails.contains($0) }
        
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
        
        print("✅ Loaded \(results.count) thumbnails")
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
        loadedThumbnails.removeAll()  // Clear loaded thumbnails tracking
        thumbnailLoadingTasks.removeAll()  // Clear thumbnail loading tasks
    }

    // MARK: - Utility: Category/Subcategory Mapping
    static func getCategoryAndSubcategory(from modelName: String) -> (category: String, subcategory: String) {
        // Special case for eyebrows since it contains "eye"
        if modelName.hasPrefix("eyebrow") {
            return (AvatarCategory.body, AvatarCategory.eyebrows)
        }
        
        // Check body categories
        for category in AvatarCategory.bodyCategories {
            if modelName.hasPrefix(category) {
                return (AvatarCategory.body, category)
            }
        }
        
        // Check clothing categories
        for category in AvatarCategory.clothingCategories {
            if modelName.hasPrefix(category) {
                return (AvatarCategory.clothes, category)
            }
        }
        
        // Check hair categories
        for category in AvatarCategory.hairCategories {
            if modelName.hasPrefix("hair_\(category)") {
                return (AvatarCategory.hair, category)
            }
        }
        
        // Check accessories categories
        for category in AvatarCategory.accessoriesCategories {
            if modelName.hasPrefix("\(category)_") {
                return (AvatarCategory.accessories, category)
            }
        }
        
        // If we can't determine the category, log an error and return a safe default
        print("⚠️ Warning: Could not determine category for model: \(modelName)")
        return (AvatarCategory.body, AvatarCategory.eyes)
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
            print("Error cleaning cache: \(error)")
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
            print("✅ Category \(category) already loaded")
            return
        }
        
        print("🔄 Loading category: \(category)")
        guard let subcategories = cachedModels[category] else {
            print("❌ Category \(category) not found in cached models")
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
        print("✅ Category \(category) loaded successfully")
    }
}