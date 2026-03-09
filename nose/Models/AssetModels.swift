import Foundation

struct AssetItem: Codable {
    let id: String
    let name: String
    let modelPath: String
    let thumbnailPath: String?
    let category: String
    let subcategory: String
    let isActive: Bool
    let metadata: [String: String]?
}

struct CategoryAssets: Codable {
    let category: String
    let subcategory: String
    let assets: [AssetItem]
}
