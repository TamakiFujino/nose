import Foundation
import FirebaseFirestore

struct CollectionAvatar: Codable {
    // MARK: - Properties
    let collectionId: String
    let avatarData: AvatarData
    let createdAt: Date
    let isOwner: Bool
    
    // MARK: - Nested Types
    struct AvatarData: Codable {
        // MARK: - Properties
        var selections: [String: [String: String]]
        
        // MARK: - Computed Properties
        // Get color values
        var skinColor: String { AvatarCategory.getColor(from: selections, category: AvatarCategory.skin) }
        
        // Get model values for each category
        var models: [String: String] {
            var result: [String: String] = [:]
            for category in AvatarCategory.modelCategories {
                let model = AvatarCategory.getModel(from: selections, category: category)
                if !model.isEmpty {
                    result[category] = model
                }
            }
            return result
        }
        
        // MARK: - Firestore Serialization
        func toFirestoreDict() -> [String: Any] {
            return selections
        }
        
        static func fromFirestoreDict(_ dict: [String: Any]) -> CollectionAvatar.AvatarData? {
            var selections: [String: [String: String]] = [:]
            for (category, value) in dict {
                if let valueDict = value as? [String: String] {
                    selections[category] = valueDict
                }
            }
            return CollectionAvatar.AvatarData(selections: selections)
        }
    }
    
    // MARK: - Firestore Serialization
    func toFirestoreData() -> [String: Any] {
        return [
            "avatarData": avatarData.toFirestoreDict(),
            "createdAt": Timestamp(date: createdAt),
            "isOwner": isOwner
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> CollectionAvatar? {
        guard let collectionId = data["collectionId"] as? String,
              let avatarDataDict = data["avatarData"] as? [String: Any],
              let avatarData = AvatarData.fromFirestoreDict(avatarDataDict),
              let timestamp = data["createdAt"] as? Timestamp,
              let isOwner = data["isOwner"] as? Bool else {
            return nil
        }
        
        return CollectionAvatar(
            collectionId: collectionId,
            avatarData: avatarData,
            createdAt: timestamp.dateValue(),
            isOwner: isOwner
        )
    }
    
    // MARK: - Firestore Path
    static func getPath(for collectionId: String, isOwner: Bool) -> String {
        let type = isOwner ? "owned" : "shared"
        return "collections/\(type)/\(type)/\(collectionId)"
    }
}
