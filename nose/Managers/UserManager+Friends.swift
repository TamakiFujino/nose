import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Friend Operations
extension UserManager {

    func getFriends(userId: String, completion: @escaping (Result<[User], Error>) -> Void) {
        FirestorePaths.friends(userId: userId)
            .getDocuments { [weak self] snapshot, error in
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
        FirestorePaths.blocked(userId: userId)
            .getDocuments { [weak self] snapshot, error in
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
        FirestorePaths.blocked(userId: currentUserId).document(friendId)
            .getDocument { [weak self] snapshot, error in
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
                FirestorePaths.blocked(userId: friendId).document(currentUserId)
                    .getDocument { [weak self] snapshot, error in
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
                        FirestorePaths.friends(userId: currentUserId).document(friendId)
                            .setData([
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

    // MARK: - Friend Requests

    /// Send a friend request from requester to receiver. Creates docs in receiver's friendRequests and requester's sentFriendRequests.
    func sendFriendRequest(requesterId: String, receiverId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        let receiverRequestsRef = FirestorePaths.friendRequests(userId: receiverId, db: db).document(requesterId)
        let requesterSentRef = FirestorePaths.sentFriendRequests(userId: requesterId, db: db).document(receiverId)
        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: receiverRequestsRef)
        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: requesterSentRef)
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Approve a received friend request: remove request docs and add mutual friends.
    func approveFriendRequest(receiverId: String, requesterId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        let receiverRequestsRef = FirestorePaths.friendRequests(userId: receiverId, db: db).document(requesterId)
        let requesterSentRef = FirestorePaths.sentFriendRequests(userId: requesterId, db: db).document(receiverId)
        batch.deleteDocument(receiverRequestsRef)
        batch.deleteDocument(requesterSentRef)
        batch.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: FirestorePaths.friends(userId: receiverId, db: db).document(requesterId))
        batch.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: FirestorePaths.friends(userId: requesterId, db: db).document(receiverId))
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Reject a received friend request: remove both request docs only.
    func rejectFriendRequest(receiverId: String, requesterId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        let receiverRequestsRef = FirestorePaths.friendRequests(userId: receiverId, db: db).document(requesterId)
        let requesterSentRef = FirestorePaths.sentFriendRequests(userId: requesterId, db: db).document(receiverId)
        batch.deleteDocument(receiverRequestsRef)
        batch.deleteDocument(requesterSentRef)
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Cancel a sent friend request: remove both request docs.
    func cancelFriendRequest(requesterId: String, receiverId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        rejectFriendRequest(receiverId: receiverId, requesterId: requesterId, completion: completion)
    }

    func blockUser(currentUserId: String, blockedUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Logger.log("Starting block operation:", level: .debug, category: "UserMgr")
        Logger.log("  - Current user ID: \(currentUserId)", level: .debug, category: "UserMgr")
        Logger.log("  - Blocked user ID: \(blockedUserId)", level: .debug, category: "UserMgr")

        // Verify authentication
        guard let authUser = Auth.auth().currentUser else {
            Logger.log("User not authenticated", level: .error, category: "UserMgr")
            completion(.failure(NSError(domain: "UserManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }

        Logger.log("Authenticated user ID: \(authUser.uid)", level: .debug, category: "UserMgr")
        Logger.log("Auth user matches current user: \(authUser.uid == currentUserId)", level: .debug, category: "UserMgr")

        // 1. Remove from current user's friends list
        let userAFriendsRef = FirestorePaths.friends(userId: currentUserId).document(blockedUserId)
        Logger.log("Removing friend from path: \(userAFriendsRef.path)", level: .debug, category: "UserMgr")

        userAFriendsRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                Logger.log("Error removing friend: \(error.localizedDescription)", level: .error, category: "UserMgr")
                completion(.failure(error))
                return
            }

            Logger.log("Successfully removed friend", level: .info, category: "UserMgr")

            // 2. Add to current user's blocked list
            let userABlockedRef = FirestorePaths.blocked(userId: currentUserId).document(blockedUserId)
            Logger.log("Adding to blocked list at path: \(userABlockedRef.path)", level: .debug, category: "UserMgr")

            userABlockedRef.setData([
                "blockedAt": FieldValue.serverTimestamp()
            ]) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    Logger.log("Error adding to blocked list: \(error.localizedDescription)", level: .error, category: "UserMgr")
                    completion(.failure(error))
                    return
                }

                Logger.log("Successfully added to blocked list", level: .info, category: "UserMgr")

                // 3. Remove shared collections from blocked user's collections
                let userBCollectionsRef = FirestorePaths.collections(userId: blockedUserId)

                Logger.log("Searching for shared collections in: \(userBCollectionsRef.path)", level: .debug, category: "UserMgr")

                userBCollectionsRef.whereField("isOwner", isEqualTo: false)
                    .whereField("sharedBy", isEqualTo: currentUserId)
                    .getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }

                        if let error = error {
                            Logger.log("Error finding shared collections: \(error.localizedDescription)", level: .error, category: "UserMgr")
                            completion(.failure(error))
                            return
                        }

                        Logger.log("Found \(snapshot?.documents.count ?? 0) shared collections to delete", level: .info, category: "UserMgr")

                        // Delete each shared collection individually
                        let group = DispatchGroup()
                        var deleteErrors: [Error] = []

                        snapshot?.documents.forEach { document in
                            group.enter()
                            Logger.log("Deleting shared collection: \(document.reference.path)", level: .debug, category: "UserMgr")
                            document.reference.delete { error in
                                if let error = error {
                                    Logger.log("Error deleting shared collection: \(error.localizedDescription)", level: .error, category: "UserMgr")
                                    deleteErrors.append(error)
                                } else {
                                    Logger.log("Successfully deleted shared collection", level: .info, category: "UserMgr")
                                }
                                group.leave()
                            }
                        }

                        group.notify(queue: .main) {
                            if !deleteErrors.isEmpty {
                                Logger.log("Some shared collections failed to delete", level: .error, category: "UserMgr")
                                completion(.failure(deleteErrors.first!))
                                return
                            }

                            // 4. Remove collections shared by blocked user from current user's collections
                            let currentUserCollectionsRef = FirestorePaths.collections(userId: currentUserId)

                            Logger.log("Searching for collections shared by blocked user in: \(currentUserCollectionsRef.path)", level: .debug, category: "UserMgr")

                            currentUserCollectionsRef.whereField("isOwner", isEqualTo: false)
                                .whereField("sharedBy", isEqualTo: blockedUserId)
                                .getDocuments { [weak self] snapshot, error in
                                    guard let self = self else { return }

                                    if let error = error {
                                        Logger.log("Error finding collections shared by blocked user: \(error.localizedDescription)", level: .error, category: "UserMgr")
                                        completion(.failure(error))
                                        return
                                    }

                                    Logger.log("Found \(snapshot?.documents.count ?? 0) collections shared by blocked user to delete", level: .info, category: "UserMgr")

                                    // Delete each collection shared by blocked user individually
                                    let group2 = DispatchGroup()
                                    var deleteErrors2: [Error] = []

                                    snapshot?.documents.forEach { document in
                                        group2.enter()
                                        Logger.log("Deleting collection shared by blocked user: \(document.reference.path)", level: .debug, category: "UserMgr")
                                        document.reference.delete { error in
                                            if let error = error {
                                                Logger.log("Error deleting collection shared by blocked user: \(error.localizedDescription)", level: .error, category: "UserMgr")
                                                deleteErrors2.append(error)
                                            } else {
                                                Logger.log("Successfully deleted collection shared by blocked user", level: .info, category: "UserMgr")
                                            }
                                            group2.leave()
                                        }
                                    }

                                    group2.notify(queue: .main) {
                                        if !deleteErrors2.isEmpty {
                                            Logger.log("Some collections shared by blocked user failed to delete", level: .error, category: "UserMgr")
                                            completion(.failure(deleteErrors2.first!))
                                            return
                                        }

                                        // 5. Remove blocked user from collections owned by current user
                                        let currentUserOwnedCollectionsRef = FirestorePaths.collections(userId: currentUserId)

                                        Logger.log("Searching for collections owned by current user to remove blocked user from", level: .debug, category: "UserMgr")

                                        currentUserOwnedCollectionsRef.whereField("isOwner", isEqualTo: true)
                                            .whereField("members", arrayContains: blockedUserId)
                                            .getDocuments { [weak self] snapshot, error in
                                                guard let self = self else { return }

                                                if let error = error {
                                                    Logger.log("Error finding collections owned by current user: \(error.localizedDescription)", level: .error, category: "UserMgr")
                                                    completion(.failure(error))
                                                    return
                                                }

                                                Logger.log("Found \(snapshot?.documents.count ?? 0) collections owned by current user to remove blocked user from", level: .info, category: "UserMgr")

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
                                                    Logger.log("Removing blocked user from collection: \(document.reference.path)", level: .debug, category: "UserMgr")
                                                    document.reference.updateData([
                                                        "members": FieldValue.arrayRemove([blockedUserId])
                                                    ]) { error in
                                                        if let error = error {
                                                            Logger.log("Error removing blocked user from collection: \(error.localizedDescription)", level: .error, category: "UserMgr")
                                                            updateErrors.append(error)
                                                        } else {
                                                            Logger.log("Successfully removed blocked user from collection", level: .info, category: "UserMgr")
                                                        }
                                                        group3.leave()
                                                    }
                                                }

                                                group3.notify(queue: .main) {
                                                    if !updateErrors.isEmpty {
                                                        Logger.log("Some collection member removals failed, but continuing", level: .error, category: "UserMgr")
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

    // continueWithBlockedUserCleanup is internal so it can be called from blockUser in this extension file
    func continueWithBlockedUserCleanup(blockedUserId: String, currentUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 6. Remove current user from blocked user's friends list
        let blockedUserFriendsRef = FirestorePaths.friends(userId: blockedUserId).document(currentUserId)
        Logger.log("Removing current user from blocked user's friends list: \(blockedUserFriendsRef.path)", level: .debug, category: "UserMgr")

        blockedUserFriendsRef.delete { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                Logger.log("Error removing current user from blocked user's friends: \(error.localizedDescription)", level: .error, category: "UserMgr")
                // Don't fail the entire operation for this
                Logger.log("Continuing despite friend removal error", level: .error, category: "UserMgr")
            } else {
                Logger.log("Successfully removed current user from blocked user's friends", level: .info, category: "UserMgr")
            }

            // 7. Remove current user from collections owned by blocked user
            let blockedUserOwnedCollectionsRef = FirestorePaths.collections(userId: blockedUserId)

            Logger.log("Searching for collections owned by blocked user to remove current user from", level: .debug, category: "UserMgr")

            blockedUserOwnedCollectionsRef.whereField("isOwner", isEqualTo: true)
                .whereField("members", arrayContains: currentUserId)
                .getDocuments { [weak self] snapshot, error in
                    guard self != nil else { return }

                    if let error = error {
                        Logger.log("Error finding collections owned by blocked user: \(error.localizedDescription)", level: .error, category: "UserMgr")
                        // Don't fail the entire operation for this
                        Logger.log("Continuing despite collection search error", level: .error, category: "UserMgr")
                        Logger.log("Successfully blocked user", level: .info, category: "UserMgr")
                        completion(.success(()))
                        return
                    }

                    Logger.log("Found \(snapshot?.documents.count ?? 0) collections owned by blocked user to remove current user from", level: .info, category: "UserMgr")

                    if snapshot?.documents.isEmpty == true {
                        Logger.log("Successfully blocked user", level: .info, category: "UserMgr")
                        completion(.success(()))
                        return
                    }

                    // Remove current user from members of collections owned by blocked user
                    let group3 = DispatchGroup()
                    var updateErrors: [Error] = []

                    snapshot?.documents.forEach { document in
                        group3.enter()
                        Logger.log("Removing current user from collection: \(document.reference.path)", level: .debug, category: "UserMgr")
                        document.reference.updateData([
                            "members": FieldValue.arrayRemove([currentUserId])
                        ]) { error in
                            if let error = error {
                                Logger.log("Error removing current user from collection: \(error.localizedDescription)", level: .error, category: "UserMgr")
                                updateErrors.append(error)
                            } else {
                                Logger.log("Successfully removed current user from collection", level: .info, category: "UserMgr")
                            }
                            group3.leave()
                        }
                    }

                    group3.notify(queue: .main) {
                        if !updateErrors.isEmpty {
                            Logger.log("Some collection member removals failed, but continuing", level: .error, category: "UserMgr")
                        }

                        Logger.log("Successfully blocked user", level: .info, category: "UserMgr")
                        completion(.success(()))
                    }
                }
        }
    }

    func unblockUser(currentUserId: String, blockedUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        FirestorePaths.blocked(userId: currentUserId).document(blockedUserId)
            .delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}
