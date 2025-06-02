import UIKit
import RealityKit
import FirebaseStorage

final class AvatarResourceManager {
    static let shared = AvatarResourceManager()
    private init() {}

    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    private var modelEntities: [String: ModelEntity] = [:]
    private var modelFileURLs: [String: URL] = [:]
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private var cachedColors: [ColorModel] = []
    private var cachedModels: [String: [String: [String]]] = [:]

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
        try await (colorsTask, modelsTask)
        
        print("✅ All resources preloaded successfully")
    }

    private func loadColors() async throws {
        print("🔄 Loading colors...")
        let jsonRef = storage.reference().child("avatar_assets/json/colors.json")
        let maxSize: Int64 = 1 * 1024 * 1024
        let data = try await jsonRef.data(maxSize: maxSize)
        let colors = try JSONDecoder().decode([ColorModel].self, from: data)
        self.cachedColors = colors
        print("✅ Colors loaded: \(colors.count)")
    }

    private func loadModels() async throws {
        print("🔄 Loading models...")
        let categories = ["base", "hair", "clothes"]
        for category in categories {
            print("📦 Loading models for category: \(category)")
            let jsonRef = storage.reference().child("avatar_assets/json/\(category).json")
            let maxSize: Int64 = 1 * 1024 * 1024
            let data = try await jsonRef.data(maxSize: maxSize)
            let models = try JSONDecoder().decode([String: [String]].self, from: data)
            self.cachedModels[category] = models
            print("✅ Loaded \(models.count) subcategories for \(category)")
        }
    }

    // MARK: - API for color/model index
    var colorModels: [ColorModel] {
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
        if let entity = modelEntities[modelName] {
            return entity
        }
        let modelFileURL = cacheDirectory.appendingPathComponent("\(modelName).usdz")
        if !fileManager.fileExists(atPath: modelFileURL.path) {
            try await downloadModel(named: modelName, to: modelFileURL)
        }
        let modelEntity: ModelEntity
        if #available(iOS 15.0, *) {
            modelEntity = try await ModelEntity.loadModel(contentsOf: modelFileURL)
        } else {
            let entity = try await ModelEntity.load(contentsOf: modelFileURL)
            guard let modelEntityCasted = entity as? ModelEntity else {
                throw NSError(domain: "AvatarResourceManager", code: 422, userInfo: [NSLocalizedDescriptionKey: "Loaded entity is not a ModelEntity"])
            }
            modelEntity = modelEntityCasted
        }
        modelEntities[modelName] = modelEntity
        modelFileURLs[modelName] = modelFileURL
        return modelEntity
    }

    private func downloadModel(named modelName: String, to fileURL: URL) async throws {
        let (category, subcategory) = AvatarResourceManager.getCategoryAndSubcategory(from: modelName)
        let remotePath = "avatar_assets/models/\(category)/\(subcategory)/\(modelName).usdz"
        let modelRef = storage.reference().child(remotePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            modelRef.write(toFile: fileURL) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url, self.fileManager.fileExists(atPath: url.path) {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "AvatarResourceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Download succeeded but file doesn't exist"]))
                }
            }
        }
    }

    // MARK: - Thumbnail Loading & Caching
    func loadThumbnail(for modelName: String) async -> UIImage? {
        if let cached = thumbnailCache.object(forKey: modelName as NSString) {
            return cached
        }
        let (category, subcategory) = AvatarResourceManager.getCategoryAndSubcategory(from: modelName)
        let remotePath = "avatar_assets/thumbnails/\(category)/\(subcategory)/\(modelName).jpg"
        let thumbnailRef = storage.reference().child(remotePath)
        do {
            let data = try await thumbnailRef.data(maxSize: 1 * 1024 * 1024)
            if let image = UIImage(data: data) {
                thumbnailCache.setObject(image, forKey: modelName as NSString)
                return image
            }
        } catch {
            print("Failed to load thumbnail for \(modelName): \(error)")
        }
        return nil
    }

    func clearCache() {
        modelEntities.removeAll()
        modelFileURLs.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
        _ = cacheDirectory
        thumbnailCache.removeAllObjects()
        cachedColors.removeAll()
        cachedModels.removeAll()
    }

    // MARK: - Utility: Category/Subcategory Mapping
    static func getCategoryAndSubcategory(from modelName: String) -> (category: String, subcategory: String) {
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
        return ("base", "base")
    }
}
