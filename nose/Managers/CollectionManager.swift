import Foundation
import FirebaseFirestore
import FirebaseAuth
import GooglePlaces
import Firebase

class CollectionManager {
    static let shared = CollectionManager()
    private let db = Firestore.firestore()
    private let collectionsCollection = "collections"
    
    private init() {}
    
    private func handleAuthError() -> NSError {
        return NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }
    
    // MARK: - Collection Creation and Fetching
    func createCollection(name: String, userId: String, completion: @escaping (Result<PlaceCollection, Error>) -> Void) {
        let collectionData: [String: Any] = [
            "name": name,
            "places": [],
            "userId": userId,
            "status": PlaceCollection.Status.active.rawValue,
            "createdAt": Timestamp(date: Date()),
            "isOwner": true,
            "version": PlaceCollection.currentVersion
        ]
        
        db.collection(collectionsCollection).addDocument(data: collectionData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Fetch the newly created collection
            self.fetchCollections(userId: userId) { result in
                switch result {
                case .success(let collections):
                    if let newCollection = collections.first(where: { $0.name == name }) {
                        completion(.success(newCollection))
                    } else {
                        completion(.failure(NSError(domain: "CollectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created collection"])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchCollections(userId: String, completion: @escaping (Result<[PlaceCollection], Error>) -> Void) {
        db.collection(collectionsCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: PlaceCollection.Status.active.rawValue)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                var collections: [PlaceCollection] = []
                let group = DispatchGroup()
                
                for document in documents {
                    group.enter()
                    
                    // Check if migration is needed
                    if let version = document.data()["version"] as? Int,
                       version < PlaceCollection.currentVersion {
                        // Migrate the collection
                        self.migrateCollection(document: document) { result in
                            switch result {
                            case .success(let collection):
                                collections.append(collection)
                            case .failure(let error):
                                print("Migration failed for collection \(document.documentID): \(error.localizedDescription)")
                                // Try to use the original collection if migration fails
                                var data = document.data()
                                data["id"] = document.documentID
                                if let collection = try? PlaceCollection(dictionary: data) {
                                    collections.append(collection)
                                }
                            }
                            group.leave()
                        }
                    } else {
                        // No migration needed
                        var data = document.data()
                        data["id"] = document.documentID
                        if let collection = try? PlaceCollection(dictionary: data) {
                            collections.append(collection)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(collections))
                }
            }
    }
    
    // MARK: - Migration
    private func migrateCollection(document: QueryDocumentSnapshot, completion: @escaping (Result<PlaceCollection, Error>) -> Void) {
        var data = document.data()
        data["id"] = document.documentID
        
        guard var collection = try? PlaceCollection(dictionary: data) else {
            completion(.failure(NSError(domain: "CollectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse collection"])))
            return
        }
        
        // Migrate the collection
        collection = collection.migrate()
        
        // Update the document with migrated data
        db.collection(collectionsCollection).document(collection.id).setData(collection.dictionary, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(collection))
            }
        }
    }
    
    // MARK: - Place Management
    func addPlaceToCollection(collectionId: String, place: GMSPlace, completion: @escaping (Result<Void, Error>) -> Void) {
        let placeData: [String: Any] = [
            "id": UUID().uuidString,
            "name": place.name ?? "",
            "latitude": place.coordinate.latitude,
            "longitude": place.coordinate.longitude,
            "address": place.formattedAddress ?? "",
            "placeId": place.placeID ?? "",
            "types": place.types ?? [],
            "rating": place.rating,
            "userRatingsTotal": place.userRatingsTotal,
            "priceLevel": place.priceLevel.rawValue,
            "photos": (place.photos ?? []).map { photo in
                [
                    "width": photo.maxSize.width,
                    "height": photo.maxSize.height,
                    "attributions": photo.attributions?.string ?? ""
                ]
            },
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection(collectionsCollection).document(collectionId).updateData([
            "places": FieldValue.arrayUnion([placeData]),
            "version": PlaceCollection.currentVersion
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
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
        print("📤 Current user ID: \(userId)")
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection with sharedWith field
        let ownerCollectionRef = db.collection("users")
            .document(userId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        batch.updateData([
            "sharedWith": friends.map { $0.id },
            "sharedAt": FieldValue.serverTimestamp()
        ], forDocument: ownerCollectionRef)
        
        // Create shared collection in each friend's shared_collections
        for friend in friends {
            print("📤 Sharing with friend ID: \(friend.id)")
            
            let sharedCollectionRef = db.collection("users")
                .document(friend.id)  // Use friend's ID here
                .collection("collections")
                .document("shared")
                .collection("shared")
                .document(collection.id)
            
            let sharedCollectionData: [String: Any] = [
                "id": collection.id,
                "name": collection.name,
                "places": collection.places.map { $0.dictionary },
                "userId": userId,  // This is the owner's ID
                "createdAt": Timestamp(date: collection.createdAt),
                "isOwner": false,
                "status": collection.status.rawValue,
                "sharedBy": userId,  // This is the owner's ID
                "sharedAt": FieldValue.serverTimestamp()
            ]
            
            print("📤 Creating shared collection in path: users/\(friend.id)/collections/shared/shared/\(collection.id)")
            print("📤 Shared collection data: \(sharedCollectionData)")
            
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
}
