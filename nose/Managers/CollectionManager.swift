import Foundation
import FirebaseFirestore
import FirebaseAuth
import GooglePlaces
import Firebase

final class CollectionManager {
    static let shared = CollectionManager()
    private let db = Firestore.firestore()
    private let storage = CollectionsStorage.shared
    
    private init() {}
    
    private func handleAuthError() -> NSError {
        return NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }
    
    // MARK: - Collection Creation and Fetching
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
        Firestore.firestore()
            .collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionId)
            .setData(collectionData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    let collection = PlaceCollection(id: collectionId, name: name, places: [], userId: currentUserId)
                    completion(.success(collection))
                }
            }
    }
    
    func fetchCollections(completion: @escaping (Result<[PlaceCollection], Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("📥 Fetching collections for user \(userId)...")
        print("📥 Using path: users/\(userId)/collections")
        
        db.collection("users").document(userId).collection("collections")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching collections: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                let collections = snapshot?.documents.compactMap { document -> PlaceCollection? in
                    var data = document.data()
                    data["id"] = document.documentID
                    print("📄 Collection document data: \(data)")
                    return PlaceCollection(dictionary: data)
                } ?? []
                
                print("✅ Fetched \(collections.count) collections")
                collections.forEach { collection in
                    print("📄 Collection '\(collection.name)' has \(collection.places.count) places")
                }
                
                completion(.success(collections))
            }
    }
    
    // MARK: - Place Management
    func addPlaceToCollection(_ place: GMSPlace, collectionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        let placeData = PlaceCollection.Place(
            placeId: place.placeID ?? "",
            name: place.name ?? "",
            formattedAddress: place.formattedAddress ?? "",
            rating: place.rating,
            phoneNumber: place.phoneNumber ?? "",
            addedAt: Date()
        )
        
        print("📝 Adding place '\(place.name ?? "Unknown")' to collection \(collectionId)...")
        print("📝 Using path: users/\(userId)/collections/\(collectionId)")
        print("📝 Place data: \(placeData.dictionary)")
        
        db.collection("users").document(userId).collection("collections").document(collectionId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error getting collection: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                print("❌ Collection document not found")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])))
                return
            }
            
            print("📄 Current collection data: \(data)")
            
            self?.db.collection("users").document(userId).collection("collections").document(collectionId).updateData([
                "places": FieldValue.arrayUnion([placeData.dictionary])
            ]) { error in
                if let error = error {
                    print("❌ Error adding place: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully added place to collection")
                    completion(.success(()))
                }
            }
        }
    }
    
    func removePlaceFromCollection(placeId: String, collectionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("🗑 Removing place \(placeId) from collection \(collectionId)...")
        
        db.collection("users").document(userId).collection("collections").document(collectionId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error getting collection: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  var collection = PlaceCollection(dictionary: data) else {
                print("❌ Collection not found or invalid data")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])))
                return
            }
            
            print("📄 Current places in collection: \(collection.places.count)")
            collection.places.removeAll { $0.placeId == placeId }
            print("📄 Places after removal: \(collection.places.count)")
            
            self.db.collection("users").document(userId).collection("collections").document(collectionId).updateData([
                "places": collection.places.map { $0.dictionary }
            ]) { error in
                if let error = error {
                    print("❌ Error removing place: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully removed place from collection")
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Collection Management
    func deleteCollection(_ collectionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("🗑 Deleting collection \(collectionId)...")
        print("🗑 Using path: users/\(userId)/collections/\(collectionId)")
        
        // First, delete any shared collections
        db.collection("users")
            .whereField("sharedCollections.\(collectionId).sharedBy", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error finding shared collections: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                let group = DispatchGroup()
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    self?.db.collection("users")
                        .document(document.documentID)
                        .collection("sharedCollections")
                        .document(collectionId)
                        .delete { error in
                            if let error = error {
                                print("❌ Error deleting shared collection: \(error.localizedDescription)")
                            }
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
                    self?.db.collection("users")
                        .document(userId)
                        .collection("collections")
                        .document(collectionId)
                        .delete { error in
                            if let error = error {
                                print("❌ Error deleting collection: \(error.localizedDescription)")
                                completion(.failure(error))
                            } else {
                                print("✅ Successfully deleted collection")
                                completion(.success(()))
                            }
                        }
                }
            }
    }
    
    func completeCollection(_ collection: PlaceCollection, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("✅ Marking collection '\(collection.name)' as completed...")
        
        db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collection.id)
            .updateData(["isCompleted": true]) { error in
                if let error = error {
                    print("❌ Error completing collection: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully marked collection as completed")
                    completion(.success(()))
                }
            }
    }
    
    func shareCollection(_ collection: PlaceCollection, with friends: [User], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("📤 Sharing collection '\(collection.name)' with \(friends.count) friends...")
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection with sharedWith field
        let ownerCollectionRef = db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collection.id)
        
        batch.updateData([
            "sharedWith": friends.map { $0.id },
            "sharedAt": FieldValue.serverTimestamp()
        ], forDocument: ownerCollectionRef)
        
        // Create shared collection in each friend's shared_collections
        for friend in friends {
            let sharedCollectionRef = db.collection("users")
                .document(friend.id)
                .collection("shared_collections")
                .document(collection.id)
            
            let sharedCollectionData: [String: Any] = [
                "id": collection.id,
                "name": collection.name,
                "places": collection.places.map { $0.dictionary },
                "userId": userId,
                "createdAt": collection.createdAt,
                "isOwner": false,
                "status": collection.status.rawValue,
                "sharedBy": userId,
                "sharedAt": FieldValue.serverTimestamp()
            ]
            
            batch.setData(sharedCollectionData, forDocument: sharedCollectionRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("❌ Error sharing collection: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Successfully shared collection with \(friends.count) friends")
                completion(.success(()))
            }
        }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("🔄 Updating avatar data for collection '\(collection.name)'...")
        
        db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collection.id)
            .setData(["avatarData": avatarData.toFirestoreDict()], merge: true) { error in
                if let error = error {
                    print("❌ Error updating avatar data: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully updated avatar data")
                    completion(.success(()))
                }
            }
    }
    
    // MARK: - Collection Operations
    
    func createCollection(_ collection: Collection, completion: @escaping (Error?) -> Void) {
        storage.createCollection(collection, completion: completion)
    }
    
    func updateCollection(_ collection: Collection, completion: @escaping (Error?) -> Void) {
        storage.updateCollection(collection, completion: completion)
    }
    
    func deleteCollection(collectionId: String, completion: @escaping (Error?) -> Void) {
        storage.deleteCollection(collectionId: collectionId, completion: completion)
    }
    
    func getCollections(completion: @escaping (Result<[Collection], Error>) -> Void) {
        storage.getCollections(completion: completion)
    }
    
    func getCollection(collectionId: String, completion: @escaping (Result<Collection, Error>) -> Void) {
        storage.getCollection(collectionId: collectionId, completion: completion)
    }
    
    // MARK: - Shared Collections Operations
    
    func shareCollection(collectionId: String, friendIds: [String], completion: @escaping (Error?) -> Void) {
        storage.shareCollection(collectionId: collectionId, friendIds: friendIds, completion: completion)
    }
    
    func getSharedCollections(completion: @escaping (Result<[Collection], Error>) -> Void) {
        storage.getSharedCollections(completion: completion)
    }
    
    func removeSharedCollection(collectionId: String, completion: @escaping (Error?) -> Void) {
        storage.removeSharedCollection(collectionId: collectionId, completion: completion)
    }
    
    // MARK: - Collection Container Operations
    
    func getCollectionContainer(completion: @escaping (Result<CollectionContainer, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "CollectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        let path = "users/\(userId)/collectionContainer"
        storage.storageManager.fetchDocument(path: path, completion: completion)
    }
    
    func updateCollectionContainer(_ container: CollectionContainer, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "CollectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }
        
        let path = "users/\(userId)/collectionContainer"
        storage.storageManager.saveDocument(container, path: path, completion: completion)
    }
}
