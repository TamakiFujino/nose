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
        db.collection("users").document(id).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot, let data = snapshot.data() else {
                completion(nil, nil)
                return
            }
            
            // Check if migration is needed
            let currentVersion = data["version"] as? Int ?? 1
            if currentVersion < User.currentVersion {
                self.migrateUser(id: id, data: data, from: currentVersion) { migratedUser, error in
                    completion(migratedUser, error)
                }
            } else {
                completion(User.fromFirestore(snapshot), nil)
            }
        }
    }
    
    private func migrateUser(id: String, data: [String: Any], from version: Int, completion: @escaping (User?, Error?) -> Void) {
        let migratedData = User.migrate(data, from: version)
        
        db.collection("users").document(id).setData(migratedData, merge: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Fetch the updated document to create the user
            self.db.collection("users").document(id).getDocument { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    completion(nil, nil)
                    return
                }
                
                let migratedUser = User.fromFirestore(snapshot)
                completion(migratedUser, nil)
            }
        }
    }
    
    func updateUserPreferences(userId: String, preferences: User.UserPreferences, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).updateData([
            "preferences": [
                "language": preferences.language,
                "theme": preferences.theme,
                "notifications": preferences.notifications
            ],
            "lastLoginAt": FieldValue.serverTimestamp(),
            "version": User.currentVersion
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
    
    // MARK: - Batch Migration
    func migrateAllUsers(completion: @escaping (Error?) -> Void) {
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(error)
                return
            }
            
            let batch = self.db.batch()
            var migrationCount = 0
            
            snapshot?.documents.forEach { document in
                let data = document.data()
                let currentVersion = data["version"] as? Int ?? 1
                
                if currentVersion < User.currentVersion {
                    let migratedData = User.migrate(data, from: currentVersion)
                    batch.setData(migratedData, forDocument: document.reference, merge: true)
                    migrationCount += 1
                }
            }
            
            if migrationCount > 0 {
                batch.commit { error in
                    completion(error)
                }
            } else {
                completion(nil)
            }
        }
    }
} 
