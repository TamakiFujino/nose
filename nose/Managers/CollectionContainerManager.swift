import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class CollectionContainerManager {
    static let shared = CollectionContainerManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func completeCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get the owner's collection to find all members
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        ownerCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(error)
                return
            }
            
            // Get current members
            let members = snapshot?.data()?["members"] as? [String] ?? [currentUserId]
            
            // Create a batch write
            let batch = self.db.batch()
            
            // Update owner's collection
            batch.updateData([
                "status": PlaceCollection.Status.completed.rawValue
            ], forDocument: ownerCollectionRef)
            
            // Update all shared copies
            for memberId in members {
                if memberId != currentUserId { // Skip owner, already updated above
                    let sharedCollectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collection.id, db: self.db)
                    
                    batch.updateData([
                        "status": PlaceCollection.Status.completed.rawValue
                    ], forDocument: sharedCollectionRef)
                }
            }
            
            // Commit all updates
            batch.commit { error in
                if let error = error {
                    Logger.log("Error completing collection: \(error.localizedDescription)", level: .error, category: "Collection")
                }
                completion(error)
            }
        }
    }
    
    func putBackCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get the owner's collection to find all members
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        ownerCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(error)
                return
            }
            
            // Get current members
            let members = snapshot?.data()?["members"] as? [String] ?? [currentUserId]
            
            // Create a batch write
            let batch = self.db.batch()
            
            // Update owner's collection
            batch.updateData([
                "status": PlaceCollection.Status.active.rawValue
            ], forDocument: ownerCollectionRef)
            
            // Update all shared copies
            for memberId in members {
                if memberId != currentUserId { // Skip owner, already updated above
                    let sharedCollectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collection.id, db: self.db)
                    
                    batch.updateData([
                        "status": PlaceCollection.Status.active.rawValue
                    ], forDocument: sharedCollectionRef)
                }
            }
            
            // Commit all updates
            batch.commit { error in
                if let error = error {
                    Logger.log("Error putting back collection: \(error.localizedDescription)", level: .error, category: "Collection")
                }
                completion(error)
            }
        }
    }
    
    func deleteCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get the owner's collection to find all members
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        ownerCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(error)
                return
            }
            
            // Get current members
            let members = snapshot?.data()?["members"] as? [String] ?? [currentUserId]
            
            // Create a batch write
            let batch = self.db.batch()
            
            // Delete all shared copies
            for memberId in members {
                let collectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collection.id, db: self.db)
                
                batch.deleteDocument(collectionRef)
            }
            
            // Commit all deletions, then attempt to remove storage thumbnail and url field for owner
            batch.commit { error in
                if let error = error {
                    Logger.log("Error deleting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                    completion(error)
                    return
                }

                // Delete Storage thumbnail (owner path)
                let path = "collection_avatars/\(currentUserId)/\(collection.id)/avatar.png"
                let ref = Storage.storage().reference(withPath: path)
                ref.delete { storageError in
                    if let storageError = storageError {
                        Logger.log("Could not delete storage avatar: \(storageError.localizedDescription)", level: .warn, category: "Collection")
                    }

                    // Also remove avatarThumbnailURL from owner's doc (ignore errors)
                    let ownerRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: self.db)
                    ownerRef.setData(["avatarThumbnailURL": FieldValue.delete()], merge: true) { _ in
                        completion(nil)
                    }
                }
            }
        }
    }
    
    func deletePlace(_ place: PlaceCollection.Place, from collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let collectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        collectionRef.updateData([
            "places": FieldValue.arrayRemove([place.toFirestoreData()])
        ]) { error in
            completion(error)
        }
    }
    
    func shareCollection(_ collection: PlaceCollection, with friends: [User], completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get current members
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        // Get current members and add new ones
        ownerCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error getting current members: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(error)
                return
            }
            
            // Get current members, defaulting to just the owner if members field doesn't exist
            let currentMembers = snapshot?.data()?["members"] as? [String] ?? [currentUserId]
            
            // Create new members list (owner + selected friends)
            let newMembers = [currentUserId] + friends.map { $0.id }
            
            // Find members to add (those not already in the collection)
            let membersToAdd = friends.filter { friend in
                !currentMembers.contains(friend.id)
            }
            
            // Find members to remove (those currently in collection but not in new selection)
            let membersToRemove = currentMembers.filter { memberId in
                memberId != currentUserId && !friends.map { $0.id }.contains(memberId)
            }
            
            // Create a batch write for all operations
            let batch = self.db.batch()
            
            // Update owner's collection with new members
            batch.updateData([
                "members": newMembers,
                "sharedAt": FieldValue.serverTimestamp()
            ], forDocument: ownerCollectionRef)
            
            // Create shared collection for new members
            for memberId in membersToAdd.map({ $0.id }) {
                let sharedCollectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collection.id, db: self.db)
                
                var sharedCollectionData: [String: Any] = [
                    "id": collection.id,
                    "name": collection.name,
                    "userId": currentUserId,
                    "sharedBy": currentUserId,
                    "createdAt": Timestamp(date: collection.createdAt),
                    "isOwner": false,
                    "status": collection.status.rawValue,
                    "places": collection.places.map { $0.dictionary },
                    "members": newMembers  // Include all members in shared copy
                ]
                
                // Include iconName if it exists
                if let iconName = collection.iconName {
                    sharedCollectionData["iconName"] = iconName
                }
                
                batch.setData(sharedCollectionData, forDocument: sharedCollectionRef)
            }
            
            // Remove shared collections for members being removed
            for memberId in membersToRemove {
                let sharedCollectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collection.id, db: self.db)
                
                batch.deleteDocument(sharedCollectionRef)
            }
            
            // Update existing shared collections with new members list
            let existingMembers = currentMembers.filter { memberId in
                memberId != currentUserId && friends.map { $0.id }.contains(memberId)
            }
            
            for memberId in existingMembers {
                let sharedCollectionRef = FirestorePaths.collectionDoc(userId: memberId, collectionId: collection.id, db: self.db)
                
                batch.updateData([
                    "members": newMembers,
                    "sharedAt": FieldValue.serverTimestamp()
                ], forDocument: sharedCollectionRef)
            }
            
            // Commit all operations in a single batch
            batch.commit { error in
                if let error = error {
                    Logger.log("Error committing batch: \(error.localizedDescription)", level: .error, category: "Collection")
                }
                completion(error)
            }
        }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let collectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        collectionRef.setData([
            "avatarData": avatarData.toFirestoreDict(),
            "isOwner": collection.isOwner
        ], merge: true) { error in
            completion(error)
        }
    }
    
    func createCollection(name: String, completion: @escaping (Result<PlaceCollection, Error>) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        let collectionId = UUID().uuidString
        let createdAt = Date()
        let collectionData: [String: Any] = [
            "id": collectionId,
            "name": name,
            "places": [],
            "userId": currentUserId,
            "createdAt": Timestamp(date: createdAt),
            "isOwner": true,
            "status": PlaceCollection.Status.active.rawValue,
            "members": [currentUserId]  // Add owner to members list by default
        ]
        
        // Create collection
        let collectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        
        collectionRef.setData(collectionData) { error in
            if let error = error {
                Logger.log("Error creating collection: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(.failure(error))
            } else {
                let collection = PlaceCollection(id: collectionId, name: name, places: [], userId: currentUserId)
                completion(.success(collection))
            }
        }
    }
}
