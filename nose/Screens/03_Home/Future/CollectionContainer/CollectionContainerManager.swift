import Foundation
import FirebaseFirestore
import FirebaseAuth

class CollectionContainerManager {
    static let shared = CollectionContainerManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func completeCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .updateData(["status": PlaceCollection.Status.completed.rawValue]) { error in
                completion(error)
            }
    }
    
    func putBackCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .updateData(["status": PlaceCollection.Status.active.rawValue]) { error in
                completion(error)
            }
    }
    
    func deleteCollection(_ collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // First, delete any shared collections
        db.collection("users")
            .whereField("sharedCollections.\(collection.id).sharedBy", isEqualTo: currentUserId)
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
                        .collection("sharedCollections")
                        .document(collection.id)
                        .delete { error in
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
                    self.db.collection("users")
                        .document(currentUserId)
                        .collection("collections")
                        .document(collection.id)
                        .delete { error in
                            completion(error)
                        }
                }
            }
    }
    
    func deletePlace(_ place: PlaceCollection.Place, from collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .updateData([
                "places": FieldValue.arrayRemove([place.toFirestoreData()])
            ]) { error in
                completion(error)
            }
    }
    
    func shareCollection(_ collection: PlaceCollection, with friends: [User], completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let sharedData = [
            "sharedWith": friends.map { $0.id },
            "sharedAt": FieldValue.serverTimestamp()
        ] as [String: Any]
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .updateData(sharedData) { error in
                completion(error)
            }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .setData(["avatarData": avatarData.toFirestoreDict()], merge: true) { error in
                completion(error)
            }
    }
}
