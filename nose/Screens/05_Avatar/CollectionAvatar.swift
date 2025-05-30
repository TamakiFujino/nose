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
    
    // Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        print("DEBUG: Converting CollectionAvatar to Firestore data")
        let data: [String: Any] = [
            "avatarData": avatarData.toFirestoreDict(),
            "createdAt": Timestamp(date: createdAt)
        ]
        return data
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> CollectionAvatar? {
        print("DEBUG: Creating CollectionAvatar from Firestore data: \(data)")
        guard let collectionId = data["collectionId"] as? String,
              let avatarDataDict = data["avatarData"] as? [String: Any],
              let avatarData = AvatarData.fromFirestoreDict(avatarDataDict),
              let timestamp = data["createdAt"] as? Timestamp else {
            print("DEBUG: Failed to create CollectionAvatar from data")
            return nil
        }
        let avatar = CollectionAvatar(
            collectionId: collectionId,
            avatarData: avatarData,
            createdAt: timestamp.dateValue()
        )
        print("DEBUG: Created CollectionAvatar: \(avatar)")
        return avatar
    }
}
