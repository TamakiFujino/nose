import Foundation
import FirebaseFirestore

struct CollectionAvatar: Codable {
    let collectionId: String
    let avatarData: AvatarData
    let createdAt: Date
    
    struct AvatarData: Codable {
        // Store selections as [category: ["model": modelName, "color": colorString]]
        var selections: [String: [String: String]]
        
        // Convenience for old code (optional)
        var color: String { selections["skin"]?["color"] ?? "" }
        var style: String { selections["style"]?["model"] ?? "" }
        var accessories: [String] { selections["accessories"]?["model"]?.components(separatedBy: ",") ?? [] }
        
        // MARK: - Firestore Serialization
        func toFirestoreDict() -> [String: Any] {
            return selections
        }
        static func fromFirestoreDict(_ dict: [String: Any]) -> CollectionAvatar.AvatarData? {
            // Convert [String: Any] to [String: [String: String]]
            var selections: [String: [String: String]] = [:]
            for (category, value) in dict {
                if let valueDict = value as? [String: String] {
                    selections[category] = valueDict
                }
            }
            return CollectionAvatar.AvatarData(selections: selections)
        }
    }
    
    // Convert to Firestore data (for legacy, not used in new flow)
    func toFirestoreData() -> [String: Any] {
        return [
            "collectionId": collectionId,
            "avatarData": avatarData.toFirestoreDict(),
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    // Create from Firestore data (for legacy, not used in new flow)
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