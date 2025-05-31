import Foundation
import FirebaseFirestore

struct CollectionAvatar: Codable {
    // MARK: - Properties
    let collectionId: String
    let avatarData: AvatarData
    let createdAt: Date
    
    // MARK: - Nested Types
    struct AvatarData: Codable {
        // MARK: - Properties
        var selections: [String: [String: String]]
        
        // MARK: - Computed Properties
        var color: String { selections["skin"]?["color"] ?? "" }
        var style: String { selections["style"]?["model"] ?? "" }
        var accessories: [String] { selections["accessories"]?["model"]?.components(separatedBy: ",") ?? [] }
        
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
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> CollectionAvatar? {
        guard let collectionId = data["collectionId"] as? String,
              let avatarDataDict = data["avatarData"] as? [String: Any],
              let avatarData = AvatarData.fromFirestoreDict(avatarDataDict),
              let timestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        return CollectionAvatar(
            collectionId: collectionId,
            avatarData: avatarData,
            createdAt: timestamp.dateValue()
        )
    }
}
