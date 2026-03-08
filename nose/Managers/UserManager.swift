import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserManager {
    static let shared = UserManager()
    let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Operations
    
    func saveUser(_ user: User, completion: @escaping (Error?) -> Void) {
        FirestorePaths.userDoc(user.id).setData(user.toFirestoreData()) { error in
            completion(error)
        }
    }
    
    func getUser(id: String, completion: @escaping (User?, Error?) -> Void) {
        FirestorePaths.userDoc(id).getDocument { [weak self] snapshot, error in
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
        
        FirestorePaths.userDoc(id).setData(migratedData, merge: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Fetch the updated document to create the user
            FirestorePaths.userDoc(id).getDocument { snapshot, error in
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
        FirestorePaths.userDoc(userId).updateData([
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
        
        FirestorePaths.userDoc(userId).updateData([
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
        let userRef = FirestorePaths.userDoc(userId)
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
                
                // 4. Get user's collections and mark shared copies as inactive
                let collectionsRef = userRef.collection("collections")
                collectionsRef.getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    // Find collections owned by this user that have been shared with others
                    let sharedCollections = snapshot?.documents.filter { doc in
                        let data = doc.data()
                        let isOwner = data["isOwner"] as? Bool ?? false
                        let members = data["members"] as? [String] ?? []
                        // Collection is shared if user is owner and has other members
                        return isOwner && members.contains(where: { $0 != userId })
                    } ?? []
                    
                    Logger.log("Found \(sharedCollections.count) shared collections to mark inactive in friends' databases", level: .info, category: "UserMgr")
                    
                    // Mark shared copies as inactive in friends' databases
                    let group = DispatchGroup()
                    
                    for collectionDoc in sharedCollections {
                        let data = collectionDoc.data()
                        let collectionId = collectionDoc.documentID
                        let members = data["members"] as? [String] ?? []
                        
                        // Update each friend's copy of this collection
                        for memberId in members where memberId != userId {
                            group.enter()
                            let friendCollectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collectionId)
                            
                            friendCollectionRef.updateData([
                                "status": "inactive",
                                "ownerDeleted": true,
                                "ownerDeletedAt": FieldValue.serverTimestamp()
                            ]) { error in
                                if let error = error {
                                    Logger.log("Error marking shared collection as inactive for user \(memberId): \(error.localizedDescription)", level: .error, category: "UserMgr")
                                } else {
                                    Logger.log("Marked collection \(collectionId) as inactive for user \(memberId)", level: .info, category: "UserMgr")
                                }
                                group.leave()
                            }
                        }
                    }
                    
                    // Wait for all shared collection updates to complete
                    group.notify(queue: .main) {
                        // Delete user's own collections
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
    }
    
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(.success(()))
        } catch {
            completion(.failure(error))
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
    
    // MARK: - Profile Image

    func fetchProfileImageCollectionId(userId: String, completion: @escaping (Result<String?, Error>) -> Void) {
        FirestorePaths.userDoc(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let collectionId = snapshot?.data()?["profileImageCollectionId"] as? String
            completion(.success(collectionId))
        }
    }

    func updateProfileImageCollectionId(userId: String, collectionId: String, completion: @escaping (Error?) -> Void) {
        FirestorePaths.userDoc(userId).updateData([
            "profileImageCollectionId": collectionId,
            "profileImageUpdatedAt": FieldValue.serverTimestamp()
        ], completion: completion)
    }

    // MARK: - Batch Migration
    func migrateAllUsers(completion: @escaping (Error?) -> Void) {
        FirestorePaths.users().getDocuments { [weak self] snapshot, error in
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
