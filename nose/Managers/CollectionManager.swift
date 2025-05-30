import Foundation
import FirebaseFirestore
import FirebaseAuth
import GooglePlaces

class CollectionManager {
    static let shared = CollectionManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    private func handleAuthError() -> NSError {
        return NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }
    
    func createCollection(name: String, completion: @escaping (Result<PlaceCollection, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        let collection = PlaceCollection(
            id: UUID().uuidString,
            name: name,
            places: [],
            userId: userId
        )
        
        print("📝 Creating collection '\(name)' in Firestore...")
        print("📝 Using path: users/\(userId)/collections/\(collection.id)")
        
        db.collection("users").document(userId).collection("collections").document(collection.id).setData(collection.dictionary) { error in
            if let error = error {
                print("❌ Error creating collection: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Successfully created collection '\(name)'")
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
        
        // First, get the current collection to check existing places
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
            
            // Update the collection with the new place
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
    
    func deleteCollection(_ collectionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        print("🗑 Deleting collection \(collectionId)...")
        print("🗑 Using path: users/\(userId)/collections/\(collectionId)")
        
        db.collection("users").document(userId).collection("collections").document(collectionId).delete { error in
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