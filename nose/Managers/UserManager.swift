import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserManager {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Operations
    
    func saveUser(_ user: User, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(user.id).setData(user.toFirestoreData()) { error in
            completion(error)
        }
    }
    
    func getUser(id: String, completion: @escaping (User?, Error?) -> Void) {
        db.collection("users").document(id).getDocument { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot, let user = User.fromFirestore(snapshot) else {
                completion(nil, nil)
                return
            }
            
            completion(user, nil)
        }
    }
    
    func updateUserPreferences(userId: String, preferences: User.UserPreferences, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).updateData([
            "preferences": [
                "language": preferences.language,
                "theme": preferences.theme,
                "notifications": preferences.notifications
            ],
            "lastLoginAt": FieldValue.serverTimestamp()
        ]) { error in
            completion(error)
        }
    }
    
    // MARK: - Current User Operations
    
    func getCurrentUser(completion: @escaping (User?, Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil, nil)
            return
        }
        
        getUser(id: userId, completion: completion)
    }
    
    func updateCurrentUserPreferences(_ preferences: User.UserPreferences, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        updateUserPreferences(userId: userId, preferences: preferences, completion: completion)
    }
} 