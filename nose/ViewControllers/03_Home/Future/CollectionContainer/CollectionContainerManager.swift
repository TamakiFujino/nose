import Foundation
import FirebaseFirestore
import FirebaseAuth

class CollectionContainerManager {
    static let shared = CollectionContainerManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func completeCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection
        let ownerCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        batch.updateData(["status": PlaceCollection.Status.completed.rawValue], forDocument: ownerCollectionRef)
        
        // Find and update all shared copies
        db.collectionGroup("shared")
            .whereField("id", isEqualTo: collection.id)
            .whereField("sharedBy", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(error)
                    return
                }
                
                // Update each shared copy
                snapshot?.documents.forEach { document in
                    batch.updateData(["status": PlaceCollection.Status.completed.rawValue], forDocument: document.reference)
                }
                
                // Commit all updates
                batch.commit { error in
                    completion(error)
                }
            }
    }
    
    func putBackCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection
        let ownerCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        batch.updateData(["status": PlaceCollection.Status.active.rawValue], forDocument: ownerCollectionRef)
        
        // Find and update all shared copies
        db.collectionGroup("shared")
            .whereField("id", isEqualTo: collection.id)
            .whereField("sharedBy", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(error)
                    return
                }
                
                // Update each shared copy
                snapshot?.documents.forEach { document in
                    batch.updateData(["status": PlaceCollection.Status.active.rawValue], forDocument: document.reference)
                }
                
                // Commit all updates
                batch.commit { error in
                    completion(error)
                }
            }
    }
    
    func deleteCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // First, find all users who have this collection shared with them
        db.collectionGroup("shared")
            .whereField("id", isEqualTo: collection.id)
            .whereField("sharedBy", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(error)
                    return
                }
                
                let group = DispatchGroup()
                
                // Delete each shared copy
                snapshot?.documents.forEach { document in
                    group.enter()
                    document.reference.delete { _ in
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // Finally delete the owner's copy
                    self.db.collection("users")
                        .document(currentUserId)
                        .collection("collections")
                        .document("owned")
                        .collection("owned")
                        .document(collection.id)
                        .delete { error in
                            completion(error)
                        }
                }
            }
    }
    
    func deletePlace(_ place: PlaceCollection.Place, from collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        collectionRef.updateData([
            "places": FieldValue.arrayRemove([place.toFirestoreData()])
        ]) { error in
            completion(error)
        }
    }
    
    func shareCollection(_ collection: PlaceCollection, with friends: [User], completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("📤 Updating collection sharing for '\(collection.name)'...")
        print("📤 Current user ID: \(currentUserId)")
        
        // Create a batch write
        let batch = db.batch()
        
        // Get current members
        let ownerCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        print("📤 Owner collection path: \(ownerCollectionRef.path)")
        
        ownerCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error getting current members: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            // Get current members
            let currentMembers = snapshot?.data()?["members"] as? [String] ?? [currentUserId]
            let newMembers = [currentUserId] + friends.map { $0.id }
            
            // Only add new members, don't remove any
            let membersToAdd = Set(newMembers).subtracting(currentMembers)
            
            print("📊 Sharing stats:")
            print("- Current members: \(currentMembers.count)")
            print("- New members: \(newMembers.count)")
            print("- Members to add: \(membersToAdd.count)")
            
            // Update owner's collection with new members field
            batch.updateData([
                "members": newMembers,
                "sharedAt": FieldValue.serverTimestamp()
            ], forDocument: ownerCollectionRef)
            
            // Add new shared collections
            for memberId in membersToAdd {
                let sharedCollectionRef = self.db.collection("users")
                    .document(memberId)
                    .collection("collections")
                    .document("shared")
                    .collection("shared")
                    .document(collection.id)
                
                print("📤 Creating shared collection for member \(memberId) at path: \(sharedCollectionRef.path)")
                
                let sharedCollectionData: [String: Any] = [
                    "id": collection.id,
                    "name": collection.name,
                    "userId": currentUserId,
                    "sharedBy": currentUserId,
                    "sharedAt": FieldValue.serverTimestamp(),
                    "isOwner": false,
                    "status": collection.status.rawValue,
                    "places": collection.places.map { $0.dictionary },
                    "members": newMembers  // Include all members in shared copy
                ]
                
                batch.setData(sharedCollectionData, forDocument: sharedCollectionRef)
            }
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("❌ Error updating collection sharing: \(error.localizedDescription)")
                    completion(error)
                } else {
                    print("✅ Successfully updated collection sharing")
                    completion(nil)
                }
            }
        }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Determine the collection type based on ownership
        let collectionType = collection.isOwner ? "owned" : "shared"
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionType)
            .collection(collectionType)
            .document(collection.id)
        
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
        
        // Create in owned subcollection
        let ownedCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collectionId)
        
        print("📝 Creating new collection in path: \(ownedCollectionRef.path)")
        
        ownedCollectionRef.setData(collectionData) { error in
            if let error = error {
                print("❌ Error creating collection: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Successfully created collection in path: \(ownedCollectionRef.path)")
                let collection = PlaceCollection(id: collectionId, name: name, places: [], userId: currentUserId)
                completion(.success(collection))
            }
        }
    }
}
