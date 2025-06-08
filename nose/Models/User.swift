import Foundation
import FirebaseFirestore

struct User: Codable {
    let id: String
    let userId: String  // Public user ID for friend search
    let name: String
    let createdAt: Date
    var lastLoginAt: Date
    
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
            ]
        ]
    }
    
    // Create from Firestore document
    static func fromFirestore(_ document: DocumentSnapshot) -> User? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let userId = data["userId"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        
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
        return user
    }
} 