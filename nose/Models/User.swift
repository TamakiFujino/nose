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
    var deletedAt: Date?
    let version: Int
    
    // Additional user data fields
    var preferences: UserPreferences
    var friends: [String]?  // Array of friend user IDs
    var blockedUsers: [String]?  // Array of blocked user IDs
    
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
        self.userId = userId ?? Self.generateRandomUserId()
        self.name = name
        self.createdAt = Date()
        self.lastLoginAt = Date()
        self.preferences = UserPreferences()
        self.isDeleted = false
        self.deletedAt = nil
        self.version = Self.currentVersion
        self.friends = []
        self.blockedUsers = []
    }
    
    private static func generateRandomUserId() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<10).map { _ in letters.randomElement()! })
    }
    
    // Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
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
            "isDeleted": isDeleted,
            "version": version,
            "friends": friends ?? [],
            "blockedUsers": blockedUsers ?? []
        ]
        
        if let deletedAt = deletedAt {
            data["deletedAt"] = Timestamp(date: deletedAt)
        }
        
        return data
    }
    
    // Create from Firestore document
    static func fromFirestore(_ document: DocumentSnapshot) -> User? {
        guard let data = document.data() else {
            Logger.log("No data found in Firestore document", level: .error, category: "User")
            return nil
        }
        
        let id = document.documentID
        guard !id.isEmpty else {
            Logger.log("Empty document ID", level: .error, category: "User")
            return nil
        }
        
        // Track invalid fields for logging
        var invalidFields: [String] = []
        
        // Handle userId with type safety
        let userId: String
        if let stringValue = data["userId"] as? String {
            userId = stringValue
        } else if let intValue = data["userId"] as? Int {
            userId = String(intValue)
        } else {
            Logger.log("Invalid userId type, using document ID", level: .warn, category: "User")
            userId = id
            invalidFields.append("userId")
        }
        
        // Handle name with type safety
        let name: String
        if let stringValue = data["name"] as? String {
            name = stringValue
        } else if let intValue = data["name"] as? Int {
            name = String(intValue)
        } else {
            Logger.log("Invalid name type, using default name", level: .warn, category: "User")
            name = "User \(id.prefix(6))"
            invalidFields.append("name")
        }
        
        // Handle version with type safety
        let version: Int
        if let intValue = data["version"] as? Int {
            version = intValue
        } else if let stringValue = data["version"] as? String,
                  let intValue = Int(stringValue) {
            version = intValue
        } else {
            Logger.log("Invalid version type. Defaulting to 1", level: .warn, category: "User")
            version = 1
            invalidFields.append("version")
        }
        
        // Handle timestamps with type safety
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let date = data["createdAt"] as? Date {
            createdAt = date
        } else {
            Logger.log("Invalid createdAt type. Using current date", level: .warn, category: "User")
            createdAt = Date()
            invalidFields.append("createdAt")
        }
        
        let lastLoginAt: Date
        if let timestamp = data["lastLoginAt"] as? Timestamp {
            lastLoginAt = timestamp.dateValue()
        } else if let date = data["lastLoginAt"] as? Date {
            lastLoginAt = date
        } else {
            Logger.log("Invalid lastLoginAt type. Using current date", level: .warn, category: "User")
            lastLoginAt = Date()
            invalidFields.append("lastLoginAt")
        }
        
        let deletedAt: Date?
        if let timestamp = data["deletedAt"] as? Timestamp {
            deletedAt = timestamp.dateValue()
        } else if let date = data["deletedAt"] as? Date {
            deletedAt = date
        } else {
            deletedAt = nil
        }
        
        // Handle preferences with type safety
        var preferences = UserPreferences()
        if let preferencesData = data["preferences"] as? [String: Any] {
            if let language = preferencesData["language"] as? String {
                preferences.language = language
            } else if let language = preferencesData["language"] as? Int {
                preferences.language = String(language)
            } else {
                Logger.log("Invalid language type in preferences", level: .warn, category: "User")
                invalidFields.append("preferences.language")
            }
            
            if let theme = preferencesData["theme"] as? String {
                preferences.theme = theme
            } else if let theme = preferencesData["theme"] as? Int {
                preferences.theme = String(theme)
            } else {
                Logger.log("Invalid theme type in preferences", level: .warn, category: "User")
                invalidFields.append("preferences.theme")
            }
            
            if let notifications = preferencesData["notifications"] as? Bool {
                preferences.notifications = notifications
            } else if let notifications = preferencesData["notifications"] as? Int {
                preferences.notifications = notifications != 0
            } else if let notifications = preferencesData["notifications"] as? String {
                preferences.notifications = notifications.lowercased() == "true"
            } else {
                Logger.log("Invalid notifications type in preferences", level: .warn, category: "User")
                invalidFields.append("preferences.notifications")
            }
        } else {
            Logger.log("Invalid preferences structure", level: .warn, category: "User")
            invalidFields.append("preferences")
        }
        
        var user = User(id: id, name: name, userId: userId)
        user.preferences = preferences
        
        // Handle isDeleted with type safety
        if let isDeleted = data["isDeleted"] as? Bool {
            user.isDeleted = isDeleted
        } else if let isDeleted = data["isDeleted"] as? Int {
            user.isDeleted = isDeleted != 0
        } else if let isDeleted = data["isDeleted"] as? String {
            user.isDeleted = isDeleted.lowercased() == "true"
        } else {
            Logger.log("Invalid isDeleted type. Defaulting to false", level: .warn, category: "User")
            user.isDeleted = false
            invalidFields.append("isDeleted")
        }
        
        user.deletedAt = deletedAt
        
        // Handle arrays with type safety
        if let friendsArray = data["friends"] as? [String] {
            user.friends = friendsArray
        } else if let friendsArray = data["friends"] as? [Int] {
            user.friends = friendsArray.map { String($0) }
        } else if let friendsArray = data["friends"] as? [Any] {
            // Try to convert mixed array types
            user.friends = friendsArray.compactMap { value in
                if let stringValue = value as? String {
                    return stringValue
                } else if let intValue = value as? Int {
                    return String(intValue)
                }
                return nil
            }
        } else {
            Logger.log("Invalid friends array type", level: .warn, category: "User")
            user.friends = []
            invalidFields.append("friends")
        }
        
        if let blockedArray = data["blockedUsers"] as? [String] {
            user.blockedUsers = blockedArray
        } else if let blockedArray = data["blockedUsers"] as? [Int] {
            user.blockedUsers = blockedArray.map { String($0) }
        } else if let blockedArray = data["blockedUsers"] as? [Any] {
            // Try to convert mixed array types
            user.blockedUsers = blockedArray.compactMap { value in
                if let stringValue = value as? String {
                    return stringValue
                } else if let intValue = value as? Int {
                    return String(intValue)
                }
                return nil
            }
        } else {
            Logger.log("Invalid blockedUsers array type", level: .warn, category: "User")
            user.blockedUsers = []
            invalidFields.append("blockedUsers")
        }
        
        if !invalidFields.isEmpty {
            Logger.log("User \(id) has \(invalidFields.count) invalid fields: \(invalidFields.joined(separator: ", "))", level: .error, category: "User")
        }
        
        Logger.log("Successfully parsed user: \(id)", level: .info, category: "User")
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
    
    // MARK: - Friend Operations
    
    mutating func addFriend(_ friendId: String) {
        if friends == nil {
            friends = []
        }
        friends?.append(friendId)
    }
    
    mutating func removeFriend(_ friendId: String) {
        friends?.removeAll { $0 == friendId }
    }
    
    mutating func blockUser(_ userId: String) {
        if blockedUsers == nil {
            blockedUsers = []
        }
        blockedUsers?.append(userId)
        removeFriend(userId)
    }
    
    mutating func unblockUser(_ userId: String) {
        blockedUsers?.removeAll { $0 == userId }
    }
    
    func isBlocked(_ userId: String) -> Bool {
        return blockedUsers?.contains(userId) ?? false
    }
    
    func isFriend(_ userId: String) -> Bool {
        return friends?.contains(userId) ?? false
    }
    
    // MARK: - Account Operations
    
    mutating func markAsDeleted() {
        isDeleted = true
        deletedAt = Date()
    }
    
    var isActive: Bool {
        return !isDeleted
    }
} 