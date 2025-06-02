import Foundation

enum AvatarCategory {
    // Parent categories
    static let base = "base"
    static let hair = "hair"
    static let clothes = "clothes"
    
    // Base categories
    static let skin = "skin"
    static let eyes = "eyes"
    static let eyebrows = "eyebrows"
    
    // Clothing categories
    static let tops = "tops"
    static let bottoms = "bottoms"
    static let socks = "socks"
    
    // Hair categories
    static let hairBase = "hairbase"
    static let hairFront = "hairfront"
    static let hairSide = "hairside"
    static let hairBack = "hairback"
    
    // All categories array
    static let all: [String] = [
        skin,
        eyes,
        eyebrows,
        tops,
        bottoms,
        socks,
        hairBase,
        hairFront,
        hairSide,
        hairBack
    ]
    
    // Category groups
    static let baseCategories: [String] = [skin, eyes, eyebrows]
    static let clothingCategories: [String] = [tops, bottoms, socks]
    static let hairCategories: [String] = [hairBase, hairFront, hairSide, hairBack]
    
    // Tab items for UI
    static let baseTabItems = ["Skin", "Eyes", "Eyebrows"]
    static let hairTabItems = ["Base", "Front", "Side", "Back"]
    static let clothesTabItems = ["Tops", "Bottoms", "Socks"]
    static let parentTabItems = ["Base", "Hair", "Clothes"]
    
    // Subcategory mapping
    private static let subcategoryMap: [String: String] = [
        skin: skin,
        eyes: eyes,
        eyebrows: eyebrows,
        hairBase: "base",
        hairFront: "front",
        hairSide: "side",
        hairBack: "back",
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
        if baseCategories.contains(category) {
            return base
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
} 