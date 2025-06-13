import Foundation
import Firebase
import FirebaseFirestore

struct CollectionAvatar: Codable {
    // MARK: - Constants
    enum Version: Int, Codable {
        case v1 = 1
        case v2 = 2 // Add new versions here when making breaking changes
        
        static var current: Version { .v1 }
    }
    
    // MARK: - Properties
    let collectionId: String
    let avatarData: AvatarData
    let createdAt: Date
    let isOwner: Bool
    let version: Version
    
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
        
        static func fromFirestoreDict(_ dict: [String: Any], version: Version) -> CollectionAvatar.AvatarData? {
            var selections: [String: [String: String]] = [:]
            
            switch version {
            case .v1:
                // Original format
                for (category, value) in dict {
                    if let valueDict = value as? [String: String] {
                        selections[category] = valueDict
                    }
                }
            case .v2:
                // Example of how to handle a new version
                // Add new version handling here when needed
                for (category, value) in dict {
                    if let valueDict = value as? [String: String] {
                        selections[category] = valueDict
                    }
                }
            }
            
            return CollectionAvatar.AvatarData(selections: selections)
        }
    }
    
    // MARK: - Initialization
    init(collectionId: String, avatarData: AvatarData, createdAt: Date, isOwner: Bool, version: Version = .current) {
        self.collectionId = collectionId
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.isOwner = isOwner
        self.version = version
    }
    
    // MARK: - Firestore Serialization
    func toFirestoreData() -> [String: Any] {
        return [
            "avatarData": avatarData.toFirestoreDict(),
            "createdAt": Timestamp(date: createdAt),
            "isOwner": isOwner,
            "version": version.rawValue
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> CollectionAvatar? {
        guard let collectionId = data["collectionId"] as? String,
              let avatarDataDict = data["avatarData"] as? [String: Any],
              let timestamp = data["createdAt"] as? Timestamp,
              let isOwner = data["isOwner"] as? Bool else {
            return nil
        }
        
        // Get version, defaulting to v1 if not present (for backward compatibility)
        let versionRaw = data["version"] as? Int ?? Version.v1.rawValue
        guard let version = Version(rawValue: versionRaw) else {
            print("⚠️ Unknown version \(versionRaw) in Firestore data")
            return nil
        }
        
        guard let avatarData = AvatarData.fromFirestoreDict(avatarDataDict, version: version) else {
            return nil
        }
        
        return CollectionAvatar(
            collectionId: collectionId,
            avatarData: avatarData,
            createdAt: timestamp.dateValue(),
            isOwner: isOwner,
            version: version
        )
    }
    
    // MARK: - Migration
    /// Migrates the avatar data to the latest version if needed
    func migrateToLatestVersion() -> CollectionAvatar {
        guard version != .current else { return self }
        
        // Add migration logic here when new versions are added
        switch version {
        case .v1:
            // Already at latest version
            return self
        case .v2:
            // Example of how to handle migration to a newer version
            // Add migration logic here when needed
            return self
        }
    }
    
    // MARK: - Firestore Path
    static func getPath(for collectionId: String, isOwner: Bool) -> String {
        let type = isOwner ? "owned" : "shared"
        return "collections/\(type)/\(type)/\(collectionId)"
    }
}
