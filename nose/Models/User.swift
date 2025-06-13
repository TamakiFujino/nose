import Foundation
import FirebaseFirestore

struct User: Codable {
    // MARK: - Constants
    static let currentVersion = 1
    
    // MARK: - Properties
    let id: String
    let userId: String  // Public user ID for friend search
    let name: String
    let createdAt: Date
    var lastLoginAt: Date
    var isDeleted: Bool
    let version: Int
    
    // Additional user data fields
    var preferences: UserPreferences
    
    struct UserPreferences: Codable {
        var language: String
        var theme: String
        var notifications: Bool
        
        init(language: String = "en", theme: String = "light", notifications: Bool = true) {
            self.language = language
            self.theme = theme
            self.notifications = notifications
        }
    }
    
    init(id: String, name: String, userId: String? = nil) {
        self.id = id
        self.userId = userId ?? String(format: "USER%06d", Int.random(in: 100000...999999))
        self.name = name
        self.createdAt = Date()
        self.lastLoginAt = Date()
        self.preferences = UserPreferences()
        self.isDeleted = false
        self.version = Self.currentVersion
    }
    
    // Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "name": name,
            "createdAt": Timestamp(date: createdAt),
            "lastLoginAt": Timestamp(date: lastLoginAt),
            "preferences": [
                "language": preferences.language,
                "theme": preferences.theme,
                "notifications": preferences.notifications
            ],
            "status": isDeleted ? "deleted" : "active",
            "version": version
        ]
    }
    
    // Create from Firestore document
    static func fromFirestore(_ document: DocumentSnapshot) -> User? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let userId = data["userId"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        let version = data["version"] as? Int ?? 1
        
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastLoginAt = (data["lastLoginAt"] as? Timestamp)?.dateValue() ?? Date()
        
        let preferencesData = data["preferences"] as? [String: Any] ?? [:]
        let preferences = UserPreferences(
            language: preferencesData["language"] as? String ?? "en",
            theme: preferencesData["theme"] as? String ?? "light",
            notifications: preferencesData["notifications"] as? Bool ?? true
        )
        
        var user = User(id: id, name: name, userId: userId)
        user.preferences = preferences
        user.isDeleted = data["status"] as? String == "deleted"
        return user
    }
    
    // MARK: - Migration
    static func migrate(_ data: [String: Any], from version: Int) -> [String: Any] {
        var migratedData = data
        
        // Example migration from version 1 to 2
        if version < 2 {
            // Add new fields or modify existing ones
            // migratedData["newField"] = defaultValue
        }
        
        // Update version
        migratedData["version"] = currentVersion
        return migratedData
    }
} 