import UIKit
import RealityKit
import FirebaseStorage

/// A manager class that handles loading and caching of avatar resources
final class AvatarResourceManager {
    
    // MARK: - Types
    
    private enum Constants {
        static let thumbnailCacheLimit = 50
        static let modelCacheQueueLabel = "com.avatar.modelCache"
        static let storageBasePath = "avatar_assets"
        static let jsonCacheKey = "avatar_json_cache"
        static let modelExtension = "usdz"
        static let thumbnailExtension = "jpg"
    }
    
    private enum ResourceError: Error {
        case resourceNotFound(String)
        case decodingError(String)
        case invalidData(String)
        case downloadError(String)
    }
    
    // MARK: - Singleton
    
    static let shared = AvatarResourceManager()
    private init() {
        loadResources()
    }
    
    // MARK: - Properties
    
    /// Firebase Storage reference
    private let storage = Storage.storage()
    
    /// Cached color models
    private var cachedColors: [ColorModel] = []
    
    /// Cached models organized by category and subcategory
    private var cachedModels: [String: [String: [String]]] = [:]
    
    /// Cached model entities
    private var modelEntities: [String: ModelEntity] = [:]
    
    /// Active loading tasks
    private var loadingTasks: [String: Task<ModelEntity, Error>] = [:]
    
    /// Loading state
    private var isLoading: Bool = false
    private var loadingCompletion: (() -> Void)?
    
    /// Queue for thread-safe model cache access
    private let modelCacheQueue = DispatchQueue(
        label: Constants.modelCacheQueueLabel,
        attributes: .concurrent
    )
    
    /// Cache for thumbnails
    private var thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = Constants.thumbnailCacheLimit
        return cache
    }()
    
    // MARK: - Public Interface
    
    /// Available color models
    var colorModels: [ColorModel] {
        return cachedColors
    }
    
    /// Available UI colors
    var uiColors: [UIColor] {
        return cachedColors.compactMap { UIColor(hex: $0.hex) }
    }
    
    /// Get models for a specific category and subcategory
    /// - Parameters:
    ///   - category: The main category (e.g., "clothes")
    ///   - subcategory: The subcategory (e.g., "tops")
    /// - Returns: Array of model names for the category and subcategory
    func models(for category: String, subcategory: String) -> [String] {
        return cachedModels[category]?[subcategory] ?? []
    }
    
    /// Get all subcategories for a category
    /// - Parameter category: The main category
    /// - Returns: Array of subcategory names
    func subcategories(for category: String) -> [String] {
        guard let categoryDict = cachedModels[category] else { return [] }
        return Array(categoryDict.keys)
    }
    
    /// Preload all resources
    /// - Parameter completion: Called when all resources are loaded
    func preloadAllResources(completion: @escaping () -> Void) {
        guard !isLoading else {
            loadingCompletion = completion
            return
        }
        
        isLoading = true
        Task {
            do {
                try await loadColors()
                try await loadModels()
                isLoading = false
                DispatchQueue.main.async {
                    completion()
                }
            } catch {
                print("Failed to preload resources: \(error)")
                isLoading = false
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    /// Load a model entity asynchronously
    /// - Parameter modelName: The name of the model to load
    /// - Returns: The loaded model entity
    /// - Throws: Error if loading fails
    func loadModelEntity(named modelName: String) async throws -> ModelEntity {
        // Check cache first using thread-safe access
        if let cachedEntity = modelCacheQueue.sync(execute: { modelEntities[modelName] }) {
            print("✅ Using cached model for: \(modelName)")
            return cachedEntity
        }
        
        // Check for existing loading task
        if let existingTask = modelCacheQueue.sync(execute: { loadingTasks[modelName] }) {
            print("⏳ Using existing loading task for: \(modelName)")
            return try await existingTask.value
        }
        
        // Create new loading task
        let task = Task<ModelEntity, Error> { [weak self] in
            guard let self = self else {
                throw ResourceError.resourceNotFound("Manager deallocated while loading model: \(modelName)")
            }
            
            do {
                // Get the category and subcategory from the model name
                let (category, subcategory) = self.getCategoryAndSubcategory(from: modelName)
                
                // Construct the full path
                let fullPath = "\(Constants.storageBasePath)/models/\(category)/\(subcategory)/\(modelName).\(Constants.modelExtension)"
                print("📥 Attempting to load model from path: \(fullPath)")
                
                // Download model file from Firebase Storage
                let modelRef = self.storage.reference().child(fullPath)
                
                // Check if file exists in Firebase Storage
                do {
                    let metadata = try await modelRef.getMetadata()
                    print("✅ File exists in Firebase Storage. Size: \(metadata.size) bytes")
                    print("🔗 Full Firebase Storage URL: \(modelRef.fullPath)")
                } catch {
                    print("❌ File does not exist in Firebase Storage: \(error)")
                    throw ResourceError.resourceNotFound("Model file not found in Firebase Storage: \(modelName)")
                }
                
                // Create a unique temporary file name to avoid conflicts
                let uniqueFileName = "\(modelName)_\(UUID().uuidString).\(Constants.modelExtension)"
                let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
                print("📝 Will download to temporary file: \(localURL.path)")
                
                // Download the file
                do {
                    try await modelRef.write(toFile: localURL)
                    print("✅ Model downloaded successfully to: \(localURL.path)")
                } catch {
                    print("❌ Failed to download model: \(error)")
                    throw ResourceError.downloadError("Failed to download model: \(error.localizedDescription)")
                }
                
                // Verify file exists and has content
                guard FileManager.default.fileExists(atPath: localURL.path) else {
                    print("❌ Downloaded file does not exist at path: \(localURL.path)")
                    throw ResourceError.resourceNotFound("Downloaded file does not exist")
                }
                
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
                let fileSize = fileAttributes[.size] as? UInt64 ?? 0
                print("📊 Downloaded file size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    print("❌ Downloaded file is empty")
                    throw ResourceError.invalidData("Downloaded model file is empty")
                }
                
                // Verify file extension
                guard localURL.pathExtension.lowercased() == Constants.modelExtension.lowercased() else {
                    print("❌ Invalid file extension. Expected: \(Constants.modelExtension), Got: \(localURL.pathExtension)")
                    throw ResourceError.invalidData("Invalid file extension")
                }
                
                // Load the model from local file
                print("🔄 Attempting to load model from: \(localURL.path)")
                do {
                    let loadedEntity = try await ModelEntity.load(contentsOf: localURL)
                    guard let entity = loadedEntity as? ModelEntity else {
                        print("❌ Entity is not a ModelEntity")
                        throw ResourceError.resourceNotFound("Failed to load model: \(modelName) - Entity is not a ModelEntity")
                    }
                    
                    print("✅ Model loaded successfully: \(modelName)")
                    
                    // Store in cache using thread-safe access
                    self.modelCacheQueue.async(flags: .barrier) {
                        self.modelEntities[modelName] = entity
                        self.loadingTasks.removeValue(forKey: modelName)
                    }
                    
                    // Clean up temporary file
                    do {
                        try FileManager.default.removeItem(at: localURL)
                        print("🧹 Cleaned up temporary file")
                    } catch {
                        print("⚠️ Failed to clean up temporary file: \(error)")
                    }
                    
                    return entity
                } catch {
                    print("❌ Failed to load ModelEntity: \(error)")
                    // Try to read file contents for debugging
                    do {
                        let fileContents = try Data(contentsOf: localURL)
                        print("📄 File contents size: \(fileContents.count) bytes")
                        print("📄 First 100 bytes: \(fileContents.prefix(100).map { String(format: "%02x", $0) }.joined())")
                    } catch {
                        print("❌ Could not read file contents: \(error)")
                    }
                    throw ResourceError.resourceNotFound("Failed to load model: \(modelName) - \(error.localizedDescription)")
                }
            } catch let error as ResourceError {
                print("❌ Resource error loading model \(modelName): \(error)")
                throw error
            } catch {
                print("❌ Unexpected error loading model \(modelName): \(error)")
                throw ResourceError.resourceNotFound("Failed to load model: \(modelName) - \(error.localizedDescription)")
            }
        }
        
        // Store task reference using thread-safe access
        modelCacheQueue.async(flags: .barrier) {
            self.loadingTasks[modelName] = task
        }
        
        return try await task.value
    }
    
    /// Get the category and subcategory from a model name
    private func getCategoryAndSubcategory(from modelName: String) -> (category: String, subcategory: String) {
        if modelName.starts(with: "tops_") {
            return ("clothes", "tops")
        } else if modelName.starts(with: "bottoms_") {
            return ("clothes", "bottoms")
        } else if modelName.starts(with: "socks_") {
            return ("clothes", "socks")
        } else if modelName.starts(with: "hair_") {
            if modelName.contains("_base") {
                return ("hair", "base")
            } else if modelName.contains("_front") {
                return ("hair", "front")
            } else if modelName.contains("_back") {
                return ("hair", "back")
            }
        } else if modelName.starts(with: "eye_") {
            return ("base", "eyes")
        } else if modelName.starts(with: "eyebrow_") {
            return ("base", "eyebrows")
        }
        
        // Default to base category if no match
        return ("base", "base")
    }
    
    /// Load a thumbnail image for a model
    /// - Parameter modelName: The name of the model to load the thumbnail for
    /// - Returns: The thumbnail image if available
    func loadThumbnail(for modelName: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = thumbnailCache.object(forKey: modelName as NSString) {
            return cachedImage
        }
        
        do {
            // Get the category and subcategory from the model name
            let (category, subcategory) = getCategoryAndSubcategory(from: modelName)
            
            // Download thumbnail from Firebase Storage
            let thumbnailRef = storage.reference().child("\(Constants.storageBasePath)/thumbnails/\(category)/\(subcategory)/\(modelName).\(Constants.thumbnailExtension)")
            let maxSize: Int64 = 1 * 1024 * 1024 // 1MB max size
            let data = try await thumbnailRef.data(maxSize: maxSize)
            
            if let image = UIImage(data: data) {
                thumbnailCache.setObject(image, forKey: modelName as NSString)
                return image
            }
        } catch {
            print("Failed to load thumbnail for \(modelName): \(error)")
        }
        
        return nil
    }
    
    /// Clear the model cache
    func clearModelCache() {
        modelCacheQueue.async(flags: .barrier) {
            self.modelEntities.removeAll()
            self.loadingTasks.removeAll()
        }
    }
    
    /// Clear the thumbnail cache
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
    }
    
    /// Refresh all resources from Firebase Storage
    func refreshResources() async {
        do {
            try await loadColors()
            try await loadModels()
        } catch {
            print("Failed to refresh resources: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadResources() {
        Task {
            do {
                try await loadColors()
                try await loadModels()
            } catch {
                print("Failed to load resources: \(error)")
            }
        }
    }
    
    private func loadColors() async throws {
        do {
            let colors = try await loadResourceFromStorage(named: "colors", type: [ColorModel].self)
            cachedColors = colors
            print("Successfully loaded \(colors.count) colors")
        } catch {
            print("Failed to load colors: \(error)")
            throw error
        }
    }
    
    private func loadModels() async throws {
        let categories = ["base", "hair", "clothes"]
        for category in categories {
            do {
                let models = try await loadResourceFromStorage(named: category, type: [String: [String]].self)
                cachedModels[category] = models
                print("Successfully loaded models for category: \(category)")
            } catch {
                print("Failed to load models for category \(category): \(error)")
                throw error
            }
        }
    }
    
    private func loadResourceFromStorage<T: Decodable>(named name: String, type: T.Type) async throws -> T {
        let jsonRef = storage.reference().child("\(Constants.storageBasePath)/json/\(name).json")
        
        do {
            let maxSize: Int64 = 1 * 1024 * 1024 // 1MB max size
            let data = try await jsonRef.data(maxSize: maxSize)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ResourceError.downloadError("Failed to download or decode \(name).json: \(error)")
        }
    }
}
