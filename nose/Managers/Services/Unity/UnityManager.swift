import Foundation
import UIKit

/// Unified manager for all Unity communication and asset management
@MainActor
final class UnityManager {
    static let shared = UnityManager()
    private init() {}
    
    // MARK: - Properties
    private var cachedCategories: [String: [String: [String]]] = [:]
    private var mainCategories: [String] = []
    private var categoryGroups: [String: [String]] = [:]
    private var isLoaded = false
    private var loadingTask: Task<Void, Error>?
    
    // Callback system for Unity responses
    private var pendingCallbacks: [String: (String) -> Void] = [:]
    private let callbackQueue = DispatchQueue(label: "com.nose.unityCallbacks", qos: .userInitiated)
    
    // MARK: - Public Interface
    
    /// Load all categories from Unity via UnityBridge
    func loadCategories() async throws {
        // Configure remote catalog URL for Unity based on Config.plist
        configureUnityRemoteCatalogURL()
        // Prevent multiple simultaneous loads
        if let existingTask = loadingTask {
            try await existingTask.value
            return
        }
        
        loadingTask = Task {
            try await performCategoryLoad()
        }
        
        do {
            try await loadingTask?.value
        } catch {
            loadingTask = nil
            throw error
        }
    }

    private func configureUnityRemoteCatalogURL() {
        guard let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any] else { return }
        let env = Bundle.main.object(forInfoDictionaryKey: "NoseEnvironment") as? String ?? "Development"
        let isStaging = env.caseInsensitiveCompare("Staging") == .orderedSame || env.caseInsensitiveCompare("Production") == .orderedSame
        let key = isStaging ? "AddressablesCatalogURLStaging" : "AddressablesCatalogURL"
        let catalogUrl = plistDict[key] as? String
        if let url = catalogUrl, !url.isEmpty {
            // Send to Unity to override
            UnityLauncher.shared().sendMessage(
                toUnity: "AssetManager",
                method: "SetRemoteCatalogURL",
                message: url
            )
        }
    }
    
    /// Get all main categories
    func getMainCategories() -> [String] {
        return mainCategories
    }
    
    /// Get all subcategories for a main category
    func getSubcategories(for mainCategory: String) -> [String] {
        return cachedCategories[mainCategory]?.keys.sorted() ?? []
    }
    
    /// Get all models for a specific subcategory
    func getModels(for mainCategory: String, subcategory: String) -> [String] {
        return cachedCategories[mainCategory]?[subcategory] ?? []
    }
    
    /// Get AssetItem objects for a specific category/subcategory
    func getAssetsForCategory(_ mainCategory: String, subcategory: String) -> [AssetItem] {
        guard let modelNames = cachedCategories[mainCategory]?[subcategory] else {
            return []
        }
        
        return modelNames.map { name in
            AssetItem(
                id: "\(mainCategory)_\(subcategory)_\(name)",
                name: name,
                modelPath: "Models/\(mainCategory)/\(subcategory)/\(name)",
                thumbnailPath: "Thumbs/\(mainCategory)/\(subcategory)/\(name).jpg",
                category: mainCategory,
                subcategory: subcategory,
                isActive: true,
                metadata: [:]
            )
        }
    }
    
    /// Get category groups
    func getCategoryGroups() -> [String: [String]] {
        return categoryGroups
    }
    
    /// Check if categories are loaded
    func isCategoriesLoaded() -> Bool {
        return isLoaded
    }
    
    /// Check if the manager is ready to use
    func isReady() -> Bool {
        return isLoaded && !cachedCategories.isEmpty
    }
    
    // MARK: - Unity Communication Methods
    
    /// Get available categories from Unity with callback
    func getAvailableCategories(completion: @escaping (String) -> Void) {
        let callbackId = generateCallbackId()
        storeCallback(callbackId, completion: completion)
        
        UnityLauncher.shared().sendMessage(
            toUnity: "UnityBridge", 
            method: "GetAvailableCategories", 
            message: callbackId
        )
    }
    
    /// Get assets for a specific category and subcategory with callback
    func getAssetsForCategory(category: String, subcategory: String, completion: @escaping (String) -> Void) {
        let callbackId = generateCallbackId()
        storeCallback(callbackId, completion: completion)
        
        let message = """
        {
            "category": "\(category)",
            "subcategory": "\(subcategory)",
            "callbackId": "\(callbackId)"
        }
        """
        
        UnityLauncher.shared().sendMessage(
            toUnity: "UnityBridge", 
            method: "GetAssetsForCategory", 
            message: message
        )
    }

    /// Get available body poses from Unity with callback
    func getBodyPoses(completion: @escaping (String) -> Void) {
        let callbackId = generateCallbackId()
        storeCallback(callbackId, completion: completion)

        UnityLauncher.shared().sendMessage(
            toUnity: "UnityBridge",
            method: "GetBodyPoses",
            message: callbackId
        )
    }
    
    /// Check if Unity asset catalog is loaded with callback
    func isAssetCatalogLoaded(completion: @escaping (String) -> Void) {
        let callbackId = generateCallbackId()
        storeCallback(callbackId, completion: completion)
        
        UnityLauncher.shared().sendMessage(
            toUnity: "UnityBridge", 
            method: "IsAssetCatalogLoaded", 
            message: callbackId
        )
    }
    
    /// Check if Unity asset catalog is loaded (synchronous version)
    func isAssetCatalogLoaded() async -> Bool {
        return await withCheckedContinuation { continuation in
            isAssetCatalogLoaded { response in
                let isLoaded = response.lowercased() == "true"
                continuation.resume(returning: isLoaded)
            }
        }
    }

    // Capture avatar thumbnail as Data (PNG) via Unity
    func requestAvatarThumbnail(completion: @escaping (Result<Data, Error>) -> Void) {
        let callbackId = generateCallbackId()
        storeCallback(callbackId) { [weak self] json in
            guard let self = self else { return }
            // Parse { imageBase64, width, height } or { error }
            if let data = json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorMsg = obj["error"] as? String {
                    completion(.failure(NSError(domain: "UnityManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
                if let b64 = obj["imageBase64"] as? String, let bytes = Data(base64Encoded: b64) {
                    completion(.success(bytes))
                    return
                }
            }
            completion(.failure(NSError(domain: "UnityManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid thumbnail response"])));
        }
        UnityLauncher.shared().sendMessage(
            toUnity: "UnityBridge",
            method: "CaptureAvatarThumbnail",
            message: callbackId
        )
    }
    
    // MARK: - Unity Response Handling
    
    /// Handle response from Unity
    func handleUnityResponse(_ response: String) {
        Logger.log("UnityManager: Received response from Unity: \(response)", level: .debug, category: "Unity")
        
        guard let data = response.data(using: .utf8),
              let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let callbackId = responseData["callbackId"] as? String else {
            Logger.log("Invalid Unity response format", level: .error, category: "Unity")
            return
        }
        
        // Extract the actual data
        let dataString = responseData["data"] as? String ?? ""
        
        // Execute callback on main queue
        DispatchQueue.main.async { [weak self] in
            self?.executeCallback(callbackId, with: dataString)
        }
    }
    
    // MARK: - Private Methods
    
    private func performCategoryLoad() async throws {
        Logger.log("UnityManager: Loading categories from Unity via UnityBridge...", level: .debug, category: "Unity")
        
        // Wait for Unity to be ready and get categories
        let categoriesJson = await getCategoriesFromUnity()
        
        // Parse the categories from Unity
        try await parseCategoriesFromUnity(categoriesJson)
        
        // Build category groups
        buildCategoryGroups()
        
        isLoaded = true
        loadingTask = nil
        
        Logger.log("UnityManager: Categories loaded successfully from Unity:", level: .info, category: "Unity")
        Logger.log("   Main categories: \(getMainCategories())", level: .debug, category: "Unity")
        Logger.log("   Category groups: \(categoryGroups)", level: .debug, category: "Unity")
    }
    
    private func getCategoriesFromUnity() async -> String {
        // Wait for Unity to be ready
        let isReady = await isAssetCatalogLoaded()
        
        if !isReady {
            Logger.log("Unity not ready, proceeding anyway", level: .warn, category: "Unity")
        }
        
        // Get categories from Unity
        return await withCheckedContinuation { continuation in
            getAvailableCategories { categoriesJson in
                continuation.resume(returning: categoriesJson)
            }
        }
    }
    
    private func parseCategoriesFromUnity(_ categoriesJson: String) async throws {
        guard let data = categoriesJson.data(using: .utf8) else {
            throw UnityError.invalidFormat("categories")
        }
        
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let response = json as? [String: Any],
              let categoriesArray = response["categories"] as? [[String: Any]] else {
            throw UnityError.invalidFormat("categories")
        }
        
        var allCategories: [String: [String: [String]]] = [:]
        
        // Process each category from Unity
        for categoryData in categoriesArray {
            guard let category = categoryData["category"] as? String,
                  let subcategories = categoryData["subcategories"] as? [String] else {
                continue
            }
            
            var categoryModels: [String: [String]] = [:]
            
            // Get models for each subcategory
            for subcategory in subcategories {
                let modelsJson = await withCheckedContinuation { continuation in
                    getAssetsForCategory(
                        category: category, 
                        subcategory: subcategory
                    ) { modelsJson in
                        continuation.resume(returning: modelsJson)
                    }
                }
                
                if let modelsData = modelsJson.data(using: .utf8),
                   let modelsResponse = try? JSONSerialization.jsonObject(with: modelsData) as? [String: Any],
                   let assetsArray = modelsResponse["assets"] as? [[String: Any]] {
                    
                    let modelNames = assetsArray.compactMap { asset -> String? in
                        return asset["name"] as? String
                    }
                    
                    categoryModels[subcategory] = modelNames
                    Logger.log("UnityManager: Loaded \(modelNames.count) models for \(category)/\(subcategory)", level: .info, category: "Unity")
                } else {
                    categoryModels[subcategory] = []
                    Logger.log("UnityManager: No models found for \(category)/\(subcategory)", level: .warn, category: "Unity")
                }
            }
            
            allCategories[category] = categoryModels
        }
        
        // Update cached data
        cachedCategories = allCategories
        mainCategories = Array(allCategories.keys).sorted()
        
        Logger.log("UnityManager: Successfully parsed categories from Unity: \(allCategories.count) main categories", level: .info, category: "Unity")
    }
    
    private func buildCategoryGroups() {
        categoryGroups.removeAll()
        
        for (mainCategory, subcategories) in cachedCategories {
            categoryGroups[mainCategory] = Array(subcategories.keys)
        }
        
        Logger.log("UnityManager: Built category groups: \(categoryGroups)", level: .debug, category: "Unity")
    }
    
    private func generateCallbackId() -> String {
        return UUID().uuidString
    }
    
    private func storeCallback(_ callbackId: String, completion: @escaping (String) -> Void) {
        callbackQueue.async { [weak self] in
            self?.pendingCallbacks[callbackId] = completion
        }
    }
    
    private func executeCallback(_ callbackId: String, with data: String) {
        callbackQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let completion = self.pendingCallbacks.removeValue(forKey: callbackId) {
                completion(data)
            } else {
                Logger.log("UnityManager: No callback found for ID: \(callbackId)", level: .warn, category: "Unity")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clear all pending callbacks
    func clearAllCallbacks() {
        callbackQueue.async { [weak self] in
            self?.pendingCallbacks.removeAll()
        }
    }
    
    /// Get count of pending callbacks
    var pendingCallbacksCount: Int {
        var count = 0
        callbackQueue.sync {
            count = pendingCallbacks.count
        }
        return count
    }
}

// MARK: - Error Types
enum UnityError: LocalizedError {
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let filename):
            return "\(filename) has invalid format"
        }
    }
}
