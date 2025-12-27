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
                    
                    print("🗑️ Found \(sharedCollections.count) shared collections to mark inactive in friends' databases")
                    
                    // Mark shared copies as inactive in friends' databases
                    let group = DispatchGroup()
                    
                    for collectionDoc in sharedCollections {
                        let data = collectionDoc.data()
                        let collectionId = collectionDoc.documentID
                        let members = data["members"] as? [String] ?? []
                        
                        // Update each friend's copy of this collection
                        for memberId in members where memberId != userId {
                            group.enter()
                            let friendCollectionRef = self.db.collection("users")
                                .document(memberId)
                                .collection("collections")
                                .document(collectionId)
                            
                            friendCollectionRef.updateData([
                                "status": "inactive",
                                "ownerDeleted": true,
                                "ownerDeletedAt": FieldValue.serverTimestamp()
                            ]) { error in
                                if let error = error {
                                    print("❌ Error marking shared collection as inactive for user \(memberId): \(error.localizedDescription)")
                                } else {
                                    print("✅ Marked collection \(collectionId) as inactive for user \(memberId)")
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
        print("🔒 Starting block operation:")
        print("  - Current user ID: \(currentUserId)")
        print("  - Blocked user ID: \(blockedUserId)")
        
        // Verify authentication
        guard let authUser = Auth.auth().currentUser else {
            print("❌ User not authenticated")
            completion(.failure(NSError(domain: "UserManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        print("🔒 Authenticated user ID: \(authUser.uid)")
        print("🔒 Auth user matches current user: \(authUser.uid == currentUserId)")
        
        // 1. Remove from current user's friends list
        let userAFriendsRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(blockedUserId)
        print("🔒 Removing friend from path: \(userAFriendsRef.path)")
        
        userAFriendsRef.delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error removing friend: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Successfully removed friend")
            
            // 2. Add to current user's blocked list
            let userABlockedRef = self.db.collection("users")
                .document(currentUserId)
                .collection("blocked")
                .document(blockedUserId)
            print("🔒 Adding to blocked list at path: \(userABlockedRef.path)")
            
            userABlockedRef.setData([
                "blockedAt": FieldValue.serverTimestamp()
            ]) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error adding to blocked list: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                print("✅ Successfully added to blocked list")
                
                // 3. Remove shared collections from blocked user's collections
                let userBCollectionsRef = self.db.collection("users")
                    .document(blockedUserId)
                    .collection("collections")
                
                print("🔒 Searching for shared collections in: \(userBCollectionsRef.path)")
                
                userBCollectionsRef.whereField("isOwner", isEqualTo: false)
                    .whereField("sharedBy", isEqualTo: currentUserId)
                    .getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ Error finding shared collections: \(error.localizedDescription)")
                            completion(.failure(error))
                            return
                        }
                        
                        print("🔒 Found \(snapshot?.documents.count ?? 0) shared collections to delete")
                        
                        // Delete each shared collection individually
                        let group = DispatchGroup()
                        var deleteErrors: [Error] = []
                        
                        snapshot?.documents.forEach { document in
                            group.enter()
                            print("🔒 Deleting shared collection: \(document.reference.path)")
                            document.reference.delete { error in
                                if let error = error {
                                    print("❌ Error deleting shared collection: \(error.localizedDescription)")
                                    deleteErrors.append(error)
                                } else {
                                    print("✅ Successfully deleted shared collection")
                                }
                                group.leave()
                            }
                        }
                        
                        group.notify(queue: .main) {
                            if !deleteErrors.isEmpty {
                                print("❌ Some shared collections failed to delete")
                                completion(.failure(deleteErrors.first!))
                                return
                            }
                            
                            // 4. Remove collections shared by blocked user from current user's collections
                            let currentUserCollectionsRef = self.db.collection("users")
                                .document(currentUserId)
                                .collection("collections")
                            
                            print("🔒 Searching for collections shared by blocked user in: \(currentUserCollectionsRef.path)")
                            
                            currentUserCollectionsRef.whereField("isOwner", isEqualTo: false)
                                .whereField("sharedBy", isEqualTo: blockedUserId)
                                .getDocuments { [weak self] snapshot, error in
                                    guard let self = self else { return }
                                    
                                    if let error = error {
                                        print("❌ Error finding collections shared by blocked user: \(error.localizedDescription)")
                                        completion(.failure(error))
                                        return
                                    }
                                    
                                    print("🔒 Found \(snapshot?.documents.count ?? 0) collections shared by blocked user to delete")
                                    
                                    // Delete each collection shared by blocked user individually
                                    let group2 = DispatchGroup()
                                    var deleteErrors2: [Error] = []
                                    
                                    snapshot?.documents.forEach { document in
                                        group2.enter()
                                        print("🔒 Deleting collection shared by blocked user: \(document.reference.path)")
                                        document.reference.delete { error in
                                            if let error = error {
                                                print("❌ Error deleting collection shared by blocked user: \(error.localizedDescription)")
                                                deleteErrors2.append(error)
                                            } else {
                                                print("✅ Successfully deleted collection shared by blocked user")
                                            }
                                            group2.leave()
                                        }
                                    }
                                    
                                    group2.notify(queue: .main) {
                                        if !deleteErrors2.isEmpty {
                                            print("❌ Some collections shared by blocked user failed to delete")
                                            completion(.failure(deleteErrors2.first!))
                                            return
                                        }
                                        
                                        // 5. Remove blocked user from collections owned by current user
                                        let currentUserOwnedCollectionsRef = self.db.collection("users")
                                            .document(currentUserId)
                                            .collection("collections")
                                        
                                        print("🔒 Searching for collections owned by current user to remove blocked user from")
                                        
                                        currentUserOwnedCollectionsRef.whereField("isOwner", isEqualTo: true)
                                            .whereField("members", arrayContains: blockedUserId)
                                            .getDocuments { [weak self] snapshot, error in
                                                guard let self = self else { return }
                                                
                                                if let error = error {
                                                    print("❌ Error finding collections owned by current user: \(error.localizedDescription)")
                                                    completion(.failure(error))
                                                    return
                                                }
                                                
                                                print("🔒 Found \(snapshot?.documents.count ?? 0) collections owned by current user to remove blocked user from")
                                                
                                                if snapshot?.documents.isEmpty == true {
                                                    // Continue to step 6 even if no collections found
                                                    self.continueWithBlockedUserCleanup(blockedUserId: blockedUserId, currentUserId: currentUserId, completion: completion)
                                                    return
                                                }
                                                
                                                // Remove blocked user from members of collections owned by current user
                                                let group3 = DispatchGroup()
                                                var updateErrors: [Error] = []
                                                
                                                snapshot?.documents.forEach { document in
                                                    group3.enter()
                                                    print("🔒 Removing blocked user from collection: \(document.reference.path)")
                                                    document.reference.updateData([
                                                        "members": FieldValue.arrayRemove([blockedUserId])
                                                    ]) { error in
                                                        if let error = error {
                                                            print("❌ Error removing blocked user from collection: \(error.localizedDescription)")
                                                            updateErrors.append(error)
                                                        } else {
                                                            print("✅ Successfully removed blocked user from collection")
                                                        }
                                                        group3.leave()
                                                    }
                                                }
                                                
                                                group3.notify(queue: .main) {
                                                    if !updateErrors.isEmpty {
                                                        print("⚠️ Some collection member removals failed, but continuing")
                                                    }
                                                    
                                                    // Continue to step 6
                                                    self.continueWithBlockedUserCleanup(blockedUserId: blockedUserId, currentUserId: currentUserId, completion: completion)
                                                }
                                            }
                                    }
                                }
                        }
                    }
            }
        }
    }
    
    private func continueWithBlockedUserCleanup(blockedUserId: String, currentUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 6. Remove current user from blocked user's friends list
        let blockedUserFriendsRef = self.db.collection("users")
            .document(blockedUserId)
            .collection("friends")
            .document(currentUserId)
        print("🔒 Removing current user from blocked user's friends list: \(blockedUserFriendsRef.path)")
        
        blockedUserFriendsRef.delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error removing current user from blocked user's friends: \(error.localizedDescription)")
                // Don't fail the entire operation for this
                print("⚠️ Continuing despite friend removal error")
            } else {
                print("✅ Successfully removed current user from blocked user's friends")
            }
            
            // 7. Remove current user from collections owned by blocked user
            let blockedUserOwnedCollectionsRef = self.db.collection("users")
                .document(blockedUserId)
                .collection("collections")
            
            print("🔒 Searching for collections owned by blocked user to remove current user from")
            
            blockedUserOwnedCollectionsRef.whereField("isOwner", isEqualTo: true)
                .whereField("members", arrayContains: currentUserId)
                .getDocuments { [weak self] snapshot, error in
                    guard self != nil else { return }
                    
                    if let error = error {
                        print("❌ Error finding collections owned by blocked user: \(error.localizedDescription)")
                        // Don't fail the entire operation for this
                        print("⚠️ Continuing despite collection search error")
                        print("✅ Successfully blocked user")
                        completion(.success(()))
                        return
                    }
                    
                    print("🔒 Found \(snapshot?.documents.count ?? 0) collections owned by blocked user to remove current user from")
                    
                    if snapshot?.documents.isEmpty == true {
                        print("✅ Successfully blocked user")
                        completion(.success(()))
                        return
                    }
                    
                    // Remove current user from members of collections owned by blocked user
                    let group3 = DispatchGroup()
                    var updateErrors: [Error] = []
                    
                    snapshot?.documents.forEach { document in
                        group3.enter()
                        print("🔒 Removing current user from collection: \(document.reference.path)")
                        document.reference.updateData([
                            "members": FieldValue.arrayRemove([currentUserId])
                        ]) { error in
                            if let error = error {
                                print("❌ Error removing current user from collection: \(error.localizedDescription)")
                                updateErrors.append(error)
                            } else {
                                print("✅ Successfully removed current user from collection")
                            }
                            group3.leave()
                        }
                    }
                    
                    group3.notify(queue: .main) {
                        if !updateErrors.isEmpty {
                            print("⚠️ Some collection member removals failed, but continuing")
                        }
                        
                        print("✅ Successfully blocked user")
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
