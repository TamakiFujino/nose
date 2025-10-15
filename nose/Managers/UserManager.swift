import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserManager {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Operations
    
    func saveUser(_ user: User, completion: @escaping (Error?) -> Void) {
        FirestorePaths.userDoc(user.id, db: db).setData(user.toFirestoreData()) { error in
            completion(error)
        }
    }
    
    func getUser(id: String, completion: @escaping (User?, Error?) -> Void) {
        FirestorePaths.userDoc(id, db: db).getDocument { [weak self] snapshot, error in
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

    // MARK: - Async/Await wrappers
    func getUser(id: String) async throws -> User? {
        try await withCheckedThrowingContinuation { continuation in
            self.getUser(id: id) { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: user)
                }
            }
        }
    }

    func getCurrentUser() async throws -> User? {
        try await withCheckedThrowingContinuation { continuation in
            self.getCurrentUser { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: user)
                }
            }
        }
    }

    func getFriends(userId: String) async throws -> [User] {
        try await withCheckedThrowingContinuation { continuation in
            self.getFriends(userId: userId) { result in
                switch result {
                case .success(let users): continuation.resume(returning: users)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func getBlockedUsers(userId: String) async throws -> [User] {
        try await withCheckedThrowingContinuation { continuation in
            self.getBlockedUsers(userId: userId) { result in
                switch result {
                case .success(let users): continuation.resume(returning: users)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateUserName(userId: String, newName: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.updateUserName(userId: userId, newName: newName) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func migrateUser(id: String, data: [String: Any], from version: Int, completion: @escaping (User?, Error?) -> Void) {
        let migratedData = User.migrate(data, from: version)
        
        FirestorePaths.userDoc(id, db: db).setData(migratedData, merge: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Fetch the updated document to create the user
            FirestorePaths.userDoc(id, db: self.db).getDocument { snapshot, error in
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
        FirestorePaths.userDoc(userId, db: db).updateData([
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
        
        FirestorePaths.userDoc(userId, db: db).updateData([
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
        let userRef = FirestorePaths.userDoc(userId, db: db)
        batch.updateData([
            "isDeleted": true,
            "deletedAt": FieldValue.serverTimestamp(),
            "version": User.currentVersion
        ], forDocument: userRef)
        
        // 2. Delete user's friends collection
        let friendsRef = FirestorePaths.friends(userId: userId, db: db)
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
            let blockedRef = FirestorePaths.blocked(userId: userId, db: db)
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
                let collectionsRef = FirestorePaths.collections(userId: userId, db: db)
                collectionsRef.getDocuments { [weak self] snapshot, error in
                    guard self != nil else { return }
                    
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
        FirestorePaths.friends(userId: userId, db: db).getDocuments { [weak self] snapshot, error in
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
        FirestorePaths.blocked(userId: userId, db: db).getDocuments { [weak self] snapshot, error in
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
        FirestorePaths.blocked(userId: currentUserId, db: db).document(friendId).getDocument { [weak self] snapshot, error in
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
                FirestorePaths.blocked(userId: friendId, db: self.db).document(currentUserId).getDocument { [weak self] snapshot, error in
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
                        FirestorePaths.friends(userId: currentUserId, db: self.db).document(friendId).setData([
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
        Logger.log("Block user flow: current=\(currentUserId) blocked=\(blockedUserId)", level: .debug, category: "User")
        
        // Verify authentication
        guard let authUser = Auth.auth().currentUser else {
            Logger.log("User not authenticated", level: .error, category: "User")
            completion(.failure(NSError(domain: "UserManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        Logger.log("Auth user=\(authUser.uid) matches=\(authUser.uid == currentUserId)", level: .debug, category: "User")
        
        // 1. Remove from current user's friends list
        let userAFriendsRef = FirestorePaths.friends(userId: currentUserId, db: db).document(blockedUserId)
        Logger.log("Remove friend path: \(userAFriendsRef.path)", level: .debug, category: "User")
        
        userAFriendsRef.delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Remove friend error: \(error.localizedDescription)", level: .error, category: "User")
                completion(.failure(error))
                return
            }
            
            Logger.log("Removed friend", level: .info, category: "User")
            
            // 2. Add to current user's blocked list
            let userABlockedRef = FirestorePaths.blocked(userId: currentUserId, db: self.db).document(blockedUserId)
            Logger.log("Add to blocked path: \(userABlockedRef.path)", level: .debug, category: "User")
            
            userABlockedRef.setData([
                "blockedAt": FieldValue.serverTimestamp()
            ]) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Block add error: \(error.localizedDescription)", level: .error, category: "User")
                    completion(.failure(error))
                    return
                }
                
                Logger.log("Blocked user added", level: .info, category: "User")
                
                // 3. Remove shared collections from blocked user's collections
                let userBCollectionsRef = FirestorePaths.collections(userId: blockedUserId, db: self.db)
                
                Logger.log("Find shared collections in: \(userBCollectionsRef.path)", level: .debug, category: "User")
                
                userBCollectionsRef.whereField("isOwner", isEqualTo: false)
                    .whereField("sharedBy", isEqualTo: currentUserId)
                    .getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            Logger.log("Find shared collections error: \(error.localizedDescription)", level: .error, category: "User")
                            completion(.failure(error))
                            return
                        }
                        
                        Logger.log("Found \(snapshot?.documents.count ?? 0) shared collections to delete", level: .debug, category: "User")
                        
                        // Delete each shared collection individually
                        let group = DispatchGroup()
                        var deleteErrors: [Error] = []
                        
                        snapshot?.documents.forEach { document in
                            group.enter()
                            Logger.log("Delete shared collection: \(document.reference.path)", level: .debug, category: "User")
                            document.reference.delete { error in
                                if let error = error {
                                    Logger.log("Delete shared collection error: \(error.localizedDescription)", level: .warn, category: "User")
                                    deleteErrors.append(error)
                                } else {
                                    Logger.log("Deleted shared collection", level: .info, category: "User")
                                }
                                group.leave()
                            }
                        }
                        
                        group.notify(queue: .main) {
                            if !deleteErrors.isEmpty {
                                Logger.log("Some shared collections failed to delete", level: .warn, category: "User")
                                completion(.failure(deleteErrors.first!))
                                return
                            }
                            
                            // 4. Remove collections shared by blocked user from current user's collections
                            let currentUserCollectionsRef = FirestorePaths.collections(userId: currentUserId, db: self.db)
                            
                            Logger.log("Find collections shared by blocked user in: \(currentUserCollectionsRef.path)", level: .debug, category: "User")
                            
                            currentUserCollectionsRef.whereField("isOwner", isEqualTo: false)
                                .whereField("sharedBy", isEqualTo: blockedUserId)
                                .getDocuments { [weak self] snapshot, error in
                                    guard let self = self else { return }
                                    
                                    if let error = error {
                                        Logger.log("Find collections shared by blocked user error: \(error.localizedDescription)", level: .error, category: "User")
                                        completion(.failure(error))
                                        return
                                    }
                                    
                                    Logger.log("Found \(snapshot?.documents.count ?? 0) shared-by-blocked to delete", level: .debug, category: "User")
                                    
                                    // Delete each collection shared by blocked user individually
                                    let group2 = DispatchGroup()
                                    var deleteErrors2: [Error] = []
                                    
                                    snapshot?.documents.forEach { document in
                                        group2.enter()
                                        Logger.log("Delete collection shared by blocked user: \(document.reference.path)", level: .debug, category: "User")
                                        document.reference.delete { error in
                                            if let error = error {
                                                Logger.log("Delete collection shared by blocked user error: \(error.localizedDescription)", level: .warn, category: "User")
                                                deleteErrors2.append(error)
                                            } else {
                                                Logger.log("Deleted collection shared by blocked user", level: .info, category: "User")
                                            }
                                            group2.leave()
                                        }
                                    }
                                    
                                    group2.notify(queue: .main) {
                                        if !deleteErrors2.isEmpty {
                                            Logger.log("Some shared-by-blocked deletions failed", level: .warn, category: "User")
                                            completion(.failure(deleteErrors2.first!))
                                            return
                                        }
                                        
                                        // 5. Remove blocked user from collections owned by current user
                                        let currentUserOwnedCollectionsRef = FirestorePaths.collections(userId: currentUserId, db: self.db)
                                        
                                        Logger.log("Find owned collections to remove blocked user", level: .debug, category: "User")
                                        
                                        currentUserOwnedCollectionsRef.whereField("isOwner", isEqualTo: true)
                                            .whereField("members", arrayContains: blockedUserId)
                                            .getDocuments { [weak self] snapshot, error in
                                                guard let self = self else { return }
                                                
                                                if let error = error {
                                                    Logger.log("Find owned collections error: \(error.localizedDescription)", level: .error, category: "User")
                                                    completion(.failure(error))
                                                    return
                                                }
                                                
                                                Logger.log("Found \(snapshot?.documents.count ?? 0) owned collections to update", level: .debug, category: "User")
                                                
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
                                                    Logger.log("Remove blocked from collection: \(document.reference.path)", level: .debug, category: "User")
                                                    document.reference.updateData([
                                                        "members": FieldValue.arrayRemove([blockedUserId])
                                                    ]) { error in
                                                        if let error = error {
                                                            Logger.log("Remove blocked from collection error: \(error.localizedDescription)", level: .warn, category: "User")
                                                            updateErrors.append(error)
                                                        } else {
                                                            Logger.log("Removed blocked user from collection", level: .info, category: "User")
                                                        }
                                                        group3.leave()
                                                    }
                                                }
                                                
                                                group3.notify(queue: .main) {
                                                    if !updateErrors.isEmpty {
                                                        Logger.log("Some removals failed; continuing", level: .warn, category: "User")
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
        let blockedUserFriendsRef = FirestorePaths.friends(userId: blockedUserId, db: self.db).document(currentUserId)
        Logger.log("Remove current from blocked user's friends: \(blockedUserFriendsRef.path)", level: .debug, category: "User")
        
        blockedUserFriendsRef.delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Remove current from blocked user's friends error: \(error.localizedDescription)", level: .warn, category: "User")
            } else {
                Logger.log("Removed current from blocked user's friends", level: .info, category: "User")
            }
            
            // 7. Remove current user from collections owned by blocked user
            let blockedUserOwnedCollectionsRef = FirestorePaths.collections(userId: blockedUserId, db: self.db)
            
            Logger.log("Find blocked-owned collections to remove current user", level: .debug, category: "User")
            
            blockedUserOwnedCollectionsRef.whereField("isOwner", isEqualTo: true)
                .whereField("members", arrayContains: currentUserId)
                .getDocuments { [weak self] snapshot, error in
                    guard self != nil else { return }
                    
                    if let error = error {
                        Logger.log("Find blocked-owned collections error: \(error.localizedDescription)", level: .warn, category: "User")
                        Logger.log("Blocked user: success (with warnings)", level: .info, category: "User")
                        completion(.success(()))
                        return
                    }
                    
                    Logger.log("Found \(snapshot?.documents.count ?? 0) blocked-owned collections to update", level: .debug, category: "User")
                    
                    if snapshot?.documents.isEmpty == true {
                        Logger.log("Blocked user: success", level: .info, category: "User")
                        completion(.success(()))
                        return
                    }
                    
                    // Remove current user from members of collections owned by blocked user
                    let group3 = DispatchGroup()
                    var updateErrors: [Error] = []
                    
                    snapshot?.documents.forEach { document in
                        group3.enter()
                        Logger.log("Remove current from blocked-owned collection: \(document.reference.path)", level: .debug, category: "User")
                        document.reference.updateData([
                            "members": FieldValue.arrayRemove([currentUserId])
                        ]) { error in
                            if let error = error {
                                Logger.log("Remove current from blocked-owned error: \(error.localizedDescription)", level: .warn, category: "User")
                                updateErrors.append(error)
                            } else {
                                Logger.log("Removed current from blocked-owned collection", level: .info, category: "User")
                            }
                            group3.leave()
                        }
                    }
                    
                    group3.notify(queue: .main) {
                        if !updateErrors.isEmpty {
                            Logger.log("Some blocked-owned removals failed; continuing", level: .warn, category: "User")
                        }
                        
                        Logger.log("Blocked user: success", level: .info, category: "User")
                        completion(.success(()))
                    }
                }
        }
    }
    
    func unblockUser(currentUserId: String, blockedUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        FirestorePaths.blocked(userId: currentUserId, db: db).document(blockedUserId).delete { error in
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
