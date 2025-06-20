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
    
    // MARK: - Account Operations
    
    func updateUserName(userId: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !newName.isEmpty else {
            completion(.failure(NSError(domain: "UserManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"])))
            return
        }
        
        db.collection("users").document(userId).updateData([
            "name": newName,
            "lastLoginAt": FieldValue.serverTimestamp(),
            "version": User.currentVersion
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func deleteAccount(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        // 1. Mark user as deleted
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "isDeleted": true,
            "deletedAt": FieldValue.serverTimestamp(),
            "version": User.currentVersion
        ], forDocument: userRef)
        
        // 2. Delete user's friends collection
        let friendsRef = userRef.collection("friends")
        friendsRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            snapshot?.documents.forEach { document in
                batch.deleteDocument(document.reference)
            }
            
            // 3. Delete user's blocked collection
            let blockedRef = userRef.collection("blocked")
            blockedRef.getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                
                // 4. Delete user's collections
                let collectionsRef = userRef.collection("collections")
                collectionsRef.getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    snapshot?.documents.forEach { document in
                        batch.deleteDocument(document.reference)
                    }
                    
                    // Commit all changes
                    batch.commit { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            // Delete Firebase Auth account
                            Auth.auth().currentUser?.delete { error in
                                if let error = error {
                                    completion(.failure(error))
                                } else {
                                    completion(.success(()))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Friend Operations
    
    func getFriends(userId: String, completion: @escaping (Result<[User], Error>) -> Void) {
        db.collection("users").document(userId)
            .collection("friends").getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let group = DispatchGroup()
                var loadedFriends: [User] = []
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    let friendId = document.documentID
                    
                    self.getUser(id: friendId) { user, error in
                        defer { group.leave() }
                        
                        if let user = user {
                            loadedFriends.append(user)
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(loadedFriends))
                }
            }
    }
    
    func getBlockedUsers(userId: String, completion: @escaping (Result<[User], Error>) -> Void) {
        db.collection("users").document(userId)
            .collection("blocked").getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let group = DispatchGroup()
                var loadedBlockedUsers: [User] = []
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    let blockedUserId = document.documentID
                    
                    self.getUser(id: blockedUserId) { user, error in
                        defer { group.leave() }
                        
                        if let user = user {
                            loadedBlockedUsers.append(user)
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(loadedBlockedUsers))
                }
            }
    }
    
    func addFriend(currentUserId: String, friendId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // First check if the user is blocked
        db.collection("users").document(currentUserId)
            .collection("blocked").document(friendId).getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if snapshot?.exists == true {
                    completion(.failure(NSError(domain: "UserManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User is blocked"])))
                    return
                }
                
                // Check if the other user has blocked the current user
                self.db.collection("users").document(friendId)
                    .collection("blocked").document(currentUserId).getDocument { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            completion(.failure(error))
                            return
                        }
                        
                        if snapshot?.exists == true {
                            completion(.failure(NSError(domain: "UserManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                            return
                        }
                        
                        // Add friend relationship
                        self.db.collection("users").document(currentUserId)
                            .collection("friends").document(friendId).setData([
                                "addedAt": FieldValue.serverTimestamp()
                            ]) { error in
                                if let error = error {
                                    completion(.failure(error))
                                } else {
                                    completion(.success(()))
                                }
                            }
                    }
            }
    }
    
    func blockUser(currentUserId: String, blockedUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        // 1. Remove from friends list
        let userAFriendsRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(blockedUserId)
        batch.deleteDocument(userAFriendsRef)
        
        // 2. Add to blocked list
        let userABlockedRef = db.collection("users")
            .document(currentUserId)
            .collection("blocked")
            .document(blockedUserId)
        batch.setData([
            "blockedAt": FieldValue.serverTimestamp()
        ], forDocument: userABlockedRef)
        
        // 3. Remove from other user's friends list
        let userBFriendsRef = db.collection("users")
            .document(blockedUserId)
            .collection("friends")
            .document(currentUserId)
        batch.deleteDocument(userBFriendsRef)
        
        // 4. Remove shared collections
        let userBSharedCollectionsRef = db.collection("users")
            .document(blockedUserId)
            .collection("collections")
            .whereField("isOwner", isEqualTo: false)
        
        userBSharedCollectionsRef.whereField("sharedBy", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    func unblockUser(currentUserId: String, blockedUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(currentUserId)
            .collection("blocked").document(blockedUserId).delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
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
