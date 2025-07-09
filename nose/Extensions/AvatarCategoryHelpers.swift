import Foundation

// MARK: - Avatar Category Helpers
// These helper methods replace the static methods from AvatarCategory
extension String {
    /// Get property value from selections dictionary
    static func getValue(from selections: [String: [String: String]], 
                        category: String, 
                        propertyType: String) -> String {
        return selections[category]?[propertyType] ?? ""
    }
    
    /// Get model value from selections
    static func getModel(from selections: [String: [String: String]], category: String) -> String {
        return getValue(from: selections, category: category, propertyType: "model")
    }
    
    /// Get color value from selections
    static func getColor(from selections: [String: [String: String]], category: String) -> String {
        return getValue(from: selections, category: category, propertyType: "color")
    }
} 