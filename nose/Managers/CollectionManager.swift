import Foundation
import FirebaseFirestore
import FirebaseAuth
import GooglePlaces
import Firebase

class CollectionManager {
    static let shared = CollectionManager()
    private let db = Firestore.firestore()
    
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
            "createdAt": Timestamp(date: createdAt)
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
        
        let sharedData = [
            "sharedWith": friends.map { $0.id },
            "sharedAt": FieldValue.serverTimestamp()
        ] as [String: Any]
        
        db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collection.id)
            .updateData(sharedData) { error in
                if let error = error {
                    print("❌ Error sharing collection: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully shared collection")
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
