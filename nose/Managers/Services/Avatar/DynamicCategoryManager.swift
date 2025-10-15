import Foundation
import FirebaseStorage

@MainActor
final class DynamicCategoryManager {
    static let shared = DynamicCategoryManager()
    private init() {}
    
    // MARK: - Properties
    private let storage = Storage.storage()
    private var cachedCategories: [String: [String: [String]]] = [:]
    private var mainCategories: [String] = []
    private var categoryGroups: [String: [String]] = [:]
    private var categoryOrder: [String] = []
    private var categoryMetadata: [String: [String: String]] = [:]
    private var isLoaded = false
    private var loadingTask: Task<Void, Error>?
    
    // MARK: - Public Interface
    
    /// Load all categories from Firebase Storage
    func loadCategories() async throws {
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
    
    /// Get all main categories in the specified order
    func getMainCategories() -> [String] {
        return categoryOrder.isEmpty ? mainCategories : categoryOrder
    }
    
    /// Get display name for a category
    func getDisplayName(for category: String) -> String {
        return categoryMetadata[category]?["displayName"] ?? category.capitalized
    }
    

    
    /// Get all subcategories for a main category
    func getSubcategories(for mainCategory: String) -> [String] {
        return cachedCategories[mainCategory]?.keys.sorted() ?? []
    }
    
    /// Get all models for a specific subcategory
    func getModels(for mainCategory: String, subcategory: String) -> [String] {
        return cachedCategories[mainCategory]?[subcategory] ?? []
    }
    
    /// Get category groups (e.g., bodyCategories, hairCategories, etc.)
    func getCategoryGroups() -> [String: [String]] {
        return categoryGroups
    }
    
    /// Check if categories are loaded
    func isCategoriesLoaded() -> Bool {
        return isLoaded
    }
    
    /// Check if the manager is ready for use (loaded and has categories)
    func isReady() -> Bool {
        return isLoaded && !getMainCategories().isEmpty
    }
    
    /// Get parent category for a subcategory
    func getParentCategory(for subcategory: String) -> String {
        for (mainCategory, subcategories) in categoryGroups {
            if subcategories.contains(subcategory) {
                return mainCategory
            }
        }
        return ""
    }
    
    /// Get all subcategories across all main categories
    func getAllSubcategories() -> [String] {
        return Array(categoryGroups.values.joined())
    }
    
    /// Check if a category is valid
    func isValidCategory(_ category: String) -> Bool {
        return getAllSubcategories().contains(category)
    }
    
    /// Get tab items for UI
    func getTabItems() -> [String: [String]] {
        var tabItems: [String: [String]] = [:]
        for mainCategory in mainCategories {
            tabItems[mainCategory] = getSubcategories(for: mainCategory)
        }
        return tabItems
    }
    
    /// Get models that can have colors
    func getColorCategories() -> [String] {
        // For now, only skin can have colors
        // This could be made dynamic in the future
        return ["skin"]
    }
    
    /// Get models that can have 3D models
    func getModelCategories() -> [String] {
        return getAllSubcategories().filter { $0 != "skin" }
    }
    
    /// Safely get a category with validation
    func getValidCategory(_ category: String) -> String? {
        guard isLoaded else { return nil }
        return isValidCategory(category) ? category : nil
    }
    
    // MARK: - Private Methods
    
    private func performCategoryLoad() async throws {
        Logger.log("Load categories from Firebase Storage", level: .debug, category: "DynamicCategory")
        
        // Load categories index file first
        try await loadCategoriesIndex()
        
        // Discover available JSON files in Firebase Storage
        let jsonFiles = try await discoverJsonFiles()
        Logger.log("Found JSON files: \(jsonFiles.count)", level: .debug, category: "DynamicCategory")
        
        // Load each JSON file concurrently
        var allCategories: [String: [String: [String]]] = [:]
        
        try await withThrowingTaskGroup(of: (String, [String: [String]]).self) { group in
            for jsonFile in jsonFiles {
                group.addTask {
                    let categoryData = try await self.loadJsonFile(jsonFile)
                    return (jsonFile, categoryData)
                }
            }
            
            for try await (jsonFile, categoryData) in group {
                let mainCategory = jsonFile.replacingOccurrences(of: ".json", with: "")
                allCategories[mainCategory] = categoryData
            }
        }
        
        // Update cached data
        cachedCategories = allCategories
        mainCategories = Array(allCategories.keys).sorted()
        
        // Build category groups
        buildCategoryGroups()
        
        // Apply custom ordering if available
        applyCategoryOrdering()
        
        isLoaded = true
        loadingTask = nil
        
        print("✅ Categories loaded successfully:")
        print("   Main categories: \(getMainCategories())")
        print("   Category groups: \(categoryGroups)")
    }
    
    private func discoverJsonFiles() async throws -> [String] {
        // List files in the avatar_assets/json/ directory
        let jsonRef = storage.reference().child("avatar_assets/json/")
        
        do {
            let result = try await jsonRef.listAll()
            let jsonFiles = result.items
                .map { $0.name }
                .filter { $0.hasSuffix(".json") && $0 != "colors.json" && $0 != "categories.json" }
                .sorted { file1, file2 in
                    // Sort by numeric prefix if present, otherwise alphabetically
                    let prefix1 = extractNumericPrefix(from: file1)
                    let prefix2 = extractNumericPrefix(from: file2)
                    
                    if let num1 = prefix1, let num2 = prefix2 {
                        return num1 < num2
                    } else if prefix1 != nil {
                        return true // Files with numeric prefixes come first
                    } else if prefix2 != nil {
                        return false
                    } else {
                        return file1 < file2 // Alphabetical fallback
                    }
                }
            
            print("📁 Discovered JSON files: \(jsonFiles)")
            return jsonFiles
        } catch {
            print("❌ Failed to discover JSON files: \(error)")
            throw CategoryLoadError.discoveryFailed(error.localizedDescription)
        }
    }
    
    private func extractNumericPrefix(from filename: String) -> Int? {
        let nameWithoutExtension = filename.replacingOccurrences(of: ".json", with: "")
        let components = nameWithoutExtension.components(separatedBy: "_")
        
        if let firstComponent = components.first, let number = Int(firstComponent) {
            return number
        }
        return nil
    }
    
    private func loadJsonFile(_ filename: String) async throws -> [String: [String]] {
        let jsonRef = storage.reference().child("avatar_assets/json/\(filename)")
        let maxSize: Int64 = 1 * 1024 * 1024 // 1MB
        
        do {
            let data = try await jsonRef.data(maxSize: maxSize)
        Logger.log("Downloaded: \(filename)", level: .debug, category: "DynamicCategory")
            
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let categoryData = json as? [String: [String]] else {
                Logger.log("Invalid format in \(filename)", level: .warn, category: "DynamicCategory")
                throw CategoryLoadError.invalidFormat(filename)
            }
            
            Logger.log("Loaded \(categoryData.count) subcategories from \(filename)", level: .info, category: "DynamicCategory")
            return categoryData
        } catch let error as NSError {
            if error.domain == "com.google.HTTPStatus" && error.code == 404 {
                Logger.log("\(filename) not found; using empty", level: .warn, category: "DynamicCategory")
                return [:]
            }
            Logger.log("Load error for \(filename): \(error.localizedDescription)", level: .error, category: "DynamicCategory")
            throw CategoryLoadError.loadFailed(filename, error.localizedDescription)
        }
    }
    
    private func loadCategoriesIndex() async throws {
        let indexRef = storage.reference().child("avatar_assets/json/categories.json")
        let maxSize: Int64 = 10 * 1024 // 10KB
        
        do {
            let data = try await indexRef.data(maxSize: maxSize)
            Logger.log("Downloaded categories.json", level: .debug, category: "DynamicCategory")
            
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let indexDict = json as? [String: Any] else {
                print("❌ categories.json is not in expected format")
                return
            }
            
            // Load order
            if let orderArray = indexDict["order"] as? [String] {
                categoryOrder = orderArray
                Logger.log("Loaded category order: \(categoryOrder.count)", level: .debug, category: "DynamicCategory")
            }
            
            // Load metadata
            if let metadataDict = indexDict["metadata"] as? [String: [String: String]] {
                categoryMetadata = metadataDict
                Logger.log("Loaded category metadata: \(categoryMetadata.keys.count)", level: .debug, category: "DynamicCategory")
            }
            
        } catch let error as NSError {
            if error.domain == "com.google.HTTPStatus" && error.code == 404 {
                Logger.log("categories.json not found; alphabetical order", level: .warn, category: "DynamicCategory")
                categoryOrder = []
                categoryMetadata = [:]
            } else {
                Logger.log("categories.json error: \(error.localizedDescription)", level: .error, category: "DynamicCategory")
                throw error
            }
        }
    }
    
    private func buildCategoryGroups() {
        categoryGroups.removeAll()
        
        for (mainCategory, subcategories) in cachedCategories {
            categoryGroups[mainCategory] = Array(subcategories.keys)
        }
        
        Logger.log("Built category groups: \(categoryGroups.keys.count)", level: .debug, category: "DynamicCategory")
    }
    
    private func applyCategoryOrdering() {
        // Filter categoryOrder to only include categories that actually exist
        let validOrder = categoryOrder.filter { mainCategories.contains($0) }
        
        // Add any missing categories to the end
        let missingCategories = mainCategories.filter { !validOrder.contains($0) }
        categoryOrder = validOrder + missingCategories
        
        Logger.log("Applied ordering: \(categoryOrder.count)", level: .debug, category: "DynamicCategory")
    }
    
    // MARK: - Error Types
    
    enum CategoryLoadError: LocalizedError {
        case discoveryFailed(String)
        case loadFailed(String, String)
        case invalidFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .discoveryFailed(let message):
                return "Failed to discover category files: \(message)"
            case .loadFailed(let filename, let message):
                return "Failed to load \(filename): \(message)"
            case .invalidFormat(let filename):
                return "Invalid format in \(filename)"
            }
        }
    }
} 
