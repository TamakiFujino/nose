import Foundation
import FirebaseFirestore
import FirebaseAuth

class CollectionContainerManager {
    static let shared = CollectionContainerManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func completeCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        collectionRef.updateData(["status": PlaceCollection.Status.completed.rawValue]) { error in
            completion(error)
        }
    }
    
    func putBackCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        collectionRef.updateData(["status": PlaceCollection.Status.active.rawValue]) { error in
            completion(error)
        }
    }
    
    func deleteCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // First, delete any shared collections
        db.collection("users")
            .whereField("collections.shared.shared.\(collection.id).sharedBy", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(error)
                    return
                }
                
                let group = DispatchGroup()
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    self.db.collection("users")
                        .document(document.documentID)
                        .collection("collections")
                        .document("shared")
                        .collection("shared")
                        .document(collection.id)
                        .delete { _ in
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
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
        
        print("📤 Sharing collection '\(collection.name)' with \(friends.count) friends...")
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection with sharedWith field
        let ownerCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        batch.updateData([
            "sharedWith": friends.map { $0.id },
            "sharedAt": FieldValue.serverTimestamp()
        ], forDocument: ownerCollectionRef)
        
        // Create shared collection reference in each friend's collections/shared subcollection
        for friend in friends {
            let sharedCollectionRef = db.collection("users")
                .document(friend.id)
                .collection("collections")
                .document("shared")
                .collection("shared")
                .document(collection.id)
            
            let sharedCollectionData: [String: Any] = [
                "id": collection.id,
                "name": collection.name,
                "userId": currentUserId,
                "sharedBy": currentUserId,
                "sharedAt": FieldValue.serverTimestamp(),
                "isOwner": false,
                "status": collection.status.rawValue
            ]
            
            batch.setData(sharedCollectionData, forDocument: sharedCollectionRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("❌ Error sharing collection: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ Successfully shared collection with \(friends.count) friends")
                completion(nil)
            }
        }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        collectionRef.setData(["avatarData": avatarData.toFirestoreDict()], merge: true) { error in
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
            "status": PlaceCollection.Status.active.rawValue
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
