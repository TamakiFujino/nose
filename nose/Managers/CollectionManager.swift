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

    // MARK: - Helpers
    private func userCollectionsRef(for userId: String) -> CollectionReference {
        return db.collection("users").document(userId).collection(collectionsCollection)
    }
    
    private func collectionDocRef(userId: String, collectionId: String) -> DocumentReference {
        return userCollectionsRef(for: userId).document(collectionId)
    }
    
    private func buildSharedCollectionData(collection: PlaceCollection, ownerId: String, members: [String]) -> [String: Any] {
        return [
            "id": collection.id,
            "name": collection.name,
            "places": collection.places.map { $0.dictionary },
            "userId": ownerId,
            "createdAt": Timestamp(date: collection.createdAt),
            "isOwner": false,
            "status": collection.status.rawValue,
            "sharedBy": ownerId,
            "sharedAt": FieldValue.serverTimestamp(),
            "members": members
        ]
    }
    
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
            "version": PlaceCollection.currentVersion,
            "members": [userId]  // Add owner to members list by default
        ]
        
        let collectionRef = userCollectionsRef(for: userId).document(UUID().uuidString)
        
        collectionRef.setData(collectionData) { error in
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
        userCollectionsRef(for: userId)
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
                                Logger.log("Migration failed for \(document.documentID): \(error.localizedDescription)", level: .warn, category: "Collection")
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
        document.reference.setData(collection.dictionary, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(collection))
            }
        }
    }
    
    // MARK: - Place Management
    func addPlaceToCollection(collectionId: String, place: GMSPlace, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
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
        
        let collectionRef = collectionDocRef(userId: userId, collectionId: collectionId)
        
        collectionRef.updateData([
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
        
        Logger.log("Remove place \(placeId) from \(collectionId)", level: .debug, category: "Collection")
        
        collectionDocRef(userId: userId, collectionId: collectionId).getDocument { snapshot, error in
            if let error = error {
                Logger.log("Get collection error: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  var collection = PlaceCollection(dictionary: data) else {
                Logger.log("Collection not found/invalid", level: .warn, category: "Collection")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])))
                return
            }
            
            collection.places.removeAll { $0.placeId == placeId }
            
            self.collectionDocRef(userId: userId, collectionId: collectionId).updateData([
                "places": collection.places.map { $0.dictionary }
            ]) { error in
                if let error = error {
                    Logger.log("Remove place error: \(error.localizedDescription)", level: .error, category: "Collection")
                    completion(.failure(error))
                } else {
                    Logger.log("Removed place from collection", level: .info, category: "Collection")
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
        
        Logger.log("Delete collection \(collectionId)", level: .debug, category: "Collection")
        
        // First, delete any shared collections
        db.collection("users")
            .whereField("sharedCollections.\(collectionId).sharedBy", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    Logger.log("Find shared collections error: \(error.localizedDescription)", level: .error, category: "Collection")
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
                                Logger.log("Delete shared collection error: \(error.localizedDescription)", level: .warn, category: "Collection")
                            }
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
                    self?.collectionDocRef(userId: userId, collectionId: collectionId).delete { error in
                            if let error = error {
                                Logger.log("Delete collection error: \(error.localizedDescription)", level: .error, category: "Collection")
                                completion(.failure(error))
                            } else {
                                Logger.log("Deleted collection", level: .info, category: "Collection")
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
        
        Logger.log("Complete collection: \(collection.name)", level: .debug, category: "Collection")
        
        collectionDocRef(userId: userId, collectionId: collection.id).updateData(["isCompleted": true]) { error in
                if let error = error {
                    Logger.log("Complete error: \(error.localizedDescription)", level: .error, category: "Collection")
                    completion(.failure(error))
                } else {
                    Logger.log("Completed collection", level: .info, category: "Collection")
                    completion(.success(()))
                }
            }
    }
    
    func shareCollection(_ collection: PlaceCollection, with friends: [User], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        Logger.log("Share collection '\(collection.name)' with \(friends.count)", level: .debug, category: "Collection")
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection with members field
        let ownerCollectionRef = collectionDocRef(userId: userId, collectionId: collection.id)
        
        // Include owner in members list
        let allMembers = [userId] + friends.map { $0.id }
        
        batch.updateData([
            "members": allMembers,
            "sharedAt": FieldValue.serverTimestamp()
        ], forDocument: ownerCollectionRef)
        
        // Create shared collection in each friend's collections
        for friend in friends {
            Logger.log("Share with friend: \(friend.id)", level: .debug, category: "Collection")
            
            let sharedCollectionRef = self.userCollectionsRef(for: friend.id).document(collection.id)
            let sharedCollectionData = self.buildSharedCollectionData(collection: collection, ownerId: userId, members: allMembers)
            
            Logger.log("Create shared at users/\(friend.id)/collections/\(collection.id)", level: .debug, category: "Collection")
            
            batch.setData(sharedCollectionData, forDocument: sharedCollectionRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                Logger.log("Share error: \(error.localizedDescription)", level: .error, category: "Collection")
                completion(.failure(error))
            } else {
                Logger.log("Shared with \(friends.count) friends", level: .info, category: "Collection")
                completion(.success(()))
            }
        }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        Logger.log("Update avatar data for: \(collection.name)", level: .debug, category: "Collection")
        
        collectionDocRef(userId: userId, collectionId: collection.id).updateData(["avatarData": avatarData.toFirestoreDict()]) { error in
                if let error = error {
                    Logger.log("Update avatar error: \(error.localizedDescription)", level: .error, category: "Collection")
                    completion(.failure(error))
                } else {
                    Logger.log("Updated avatar data", level: .info, category: "Collection")
                    completion(.success(()))
                }
            }
    }

    // MARK: - Async/Await wrappers
    func createCollection(name: String, userId: String) async throws -> PlaceCollection {
        try await withCheckedThrowingContinuation { continuation in
            self.createCollection(name: name, userId: userId) { result in
                switch result {
                case .success(let collection): continuation.resume(returning: collection)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchCollections(userId: String) async throws -> [PlaceCollection] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchCollections(userId: userId) { result in
                switch result {
                case .success(let collections): continuation.resume(returning: collections)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func addPlaceToCollection(collectionId: String, place: GMSPlace) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.addPlaceToCollection(collectionId: collectionId, place: place) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func removePlaceFromCollection(placeId: String, collectionId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.removePlaceFromCollection(placeId: placeId, collectionId: collectionId) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteCollection(_ collectionId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.deleteCollection(collectionId) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func completeCollection(_ collection: PlaceCollection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.completeCollection(collection) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func shareCollection(_ collection: PlaceCollection, with friends: [User]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.shareCollection(collection, with: friends) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.updateAvatarData(avatarData, for: collection) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}
