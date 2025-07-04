import Foundation

enum AvatarCategory {
    // MARK: - Property Types
    enum PropertyType {
        static let model = "model"
        static let color = "color"
    }
    
    // MARK: - Main Categories
    static let body = "body"
    static let hair = "hair"
    static let clothes = "clothes"
    static let colors = "colors"
    
    // MARK: - JSON File Names
    static let jsonFiles: [String: String] = [
        body: "\(body).json",
        hair: "\(hair).json",
        clothes: "\(clothes).json"
    ]
    
    // MARK: - Body Categories
    static let eyes = "eyes"
    static let eyebrows = "eyebrows"
    static let skin = "skin"
    
    // Body categories
    static let base = "base"
    static let front = "front"
    static let side = "side"
    static let back = "back"
    
    // Clothing categories
    static let tops = "tops"
    static let bottoms = "bottoms"
    static let socks = "socks"
    
    // All categories array
    static let all: [String] = [
        skin,
        eyes,
        eyebrows,
        tops,
        bottoms,
        socks,
        base,
        front,
        side,
        back
    ]
    
    // Category groups
    static let bodyCategories: [String] = [skin, eyes, eyebrows]
    static let clothingCategories: [String] = [tops, bottoms, socks]
    static let hairCategories: [String] = [base, front, side, back]
    
    // All categories that can have models
    static let modelCategories: [String] = [
        eyes, eyebrows,
        base, front, side, back,
        tops, bottoms, socks
    ]
    
    // Categories that can have colors
    static let colorCategories: [String] = [
        skin
        // Add more categories here that can have colors
    ]
    
    // Tab items for UI
    static let bodyTabItems = [skin, eyes, eyebrows]
    static let hairTabItems = [base, front, side, back]
    static let clothesTabItems = [tops, bottoms, socks]
    static let parentTabItems = [body, hair, clothes]
    
    // Subcategory mapping
    private static let subcategoryMap: [String: String] = [
        skin: skin,
        eyes: eyes,
        eyebrows: eyebrows,
        base: base,
        front: front,
        side: side,
        back: back,
        tops: tops,
        bottoms: bottoms,
        socks: socks
    ]
    
    // Helper function to check if a category is valid
    static func isValid(_ category: String) -> Bool {
        return all.contains(category)
    }
    
    // Helper function to get parent category
    static func getParentCategory(for category: String) -> String {
        if bodyCategories.contains(category) {
            return body
        } else if hairCategories.contains(category) {
            return hair
        } else if clothingCategories.contains(category) {
            return clothes
        }
        return ""
    }
    
    // Helper function to get subcategory
    static func getSubcategory(for category: String) -> String {
        return subcategoryMap[category] ?? category
    }
    
    // Helper function to get property value from selections
    static func getValue(from selections: [String: [String: String]], 
                        category: String, 
                        propertyType: String) -> String {
        return selections[category]?[propertyType] ?? ""
    }
    
    // Helper function to get model value
    static func getModel(from selections: [String: [String: String]], category: String) -> String {
        return getValue(from: selections, category: category, propertyType: PropertyType.model)
    }
    
    // Helper function to get color value
    static func getColor(from selections: [String: [String: String]], category: String) -> String {
        return getValue(from: selections, category: category, propertyType: PropertyType.color)
    }
} 
