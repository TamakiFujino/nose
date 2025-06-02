import Foundation

enum AvatarCategory {
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
    
    // Helper function to check if a category is valid
    static func isValid(_ category: String) -> Bool {
        return all.contains(category)
    }
} 