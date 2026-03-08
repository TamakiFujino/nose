import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import GooglePlaces
import Firebase
import UIKit

class CollectionManager {
    static let shared = CollectionManager()
    let db = Firestore.firestore()
    let storage = Storage.storage()
    private let collectionsCollection = "collections"
    
    // Cache for collection icons (persists across view controller instances)
    var cachedIcons: [String: [CollectionIcon]] = [:] // category -> icons
    var iconCacheQueue = DispatchQueue(label: "com.nose.collectionIcons.cache", qos: .utility)
    
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
            "version": PlaceCollection.currentVersion,
            "members": [userId]  // Add owner to members list by default
        ]
        
        let collectionRef = FirestorePaths.collections(userId: userId).document(UUID().uuidString)

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
                                Logger.log("Migration failed for collection \(document.documentID): \(error.localizedDescription)", level: .error, category: "CollectionMgr")
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
        
        let collectionRef = FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId)

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
        
        Logger.log("Removing place \(placeId) from collection \(collectionId)...", level: .debug, category: "CollectionMgr")
        
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId).getDocument { snapshot, error in
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  var collection = PlaceCollection(dictionary: data) else {
                Logger.log("Collection not found or invalid data", level: .error, category: "CollectionMgr")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])))
                return
            }
            
            Logger.log("Current places in collection: \(collection.places.count)", level: .debug, category: "CollectionMgr")
            collection.places.removeAll { $0.placeId == placeId }
            Logger.log("Places after removal: \(collection.places.count)", level: .debug, category: "CollectionMgr")
            
            FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId).updateData([
                "places": collection.places.map { $0.dictionary }
            ]) { error in
                if let error = error {
                    Logger.log("Error removing place: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                    completion(.failure(error))
                } else {
                    Logger.log("Successfully removed place from collection", level: .info, category: "CollectionMgr")
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
        
        Logger.log("Deleting collection \(collectionId)...", level: .debug, category: "CollectionMgr")
        Logger.log("Using path: users/\(userId)/collections/\(collectionId)", level: .debug, category: "CollectionMgr")
        
        // First, delete any shared collections
        FirestorePaths.users()
            .whereField("sharedCollections.\(collectionId).sharedBy", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    Logger.log("Error finding shared collections: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                    completion(.failure(error))
                    return
                }
                
                let group = DispatchGroup()
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    FirestorePaths.userDoc(document.documentID)
                        .collection("sharedCollections")
                        .document(collectionId)
                        .delete { error in
                            if let error = error {
                                Logger.log("Error deleting shared collection: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                            }
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
                    FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId)
                        .delete { error in
                            if let error = error {
                                Logger.log("Error deleting collection: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                                completion(.failure(error))
                            } else {
                                Logger.log("Successfully deleted collection", level: .info, category: "CollectionMgr")
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
        
        Logger.log("Marking collection '\(collection.name)' as completed...", level: .info, category: "CollectionMgr")
        
        FirestorePaths.collectionDoc(userId: userId, collectionId: collection.id)
            .updateData(["isCompleted": true]) { error in
                if let error = error {
                    Logger.log("Error completing collection: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                    completion(.failure(error))
                } else {
                    Logger.log("Successfully marked collection as completed", level: .info, category: "CollectionMgr")
                    completion(.success(()))
                }
            }
    }
    
    func shareCollection(_ collection: PlaceCollection, with friends: [User], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        Logger.log("Sharing collection '\(collection.name)' with \(friends.count) friends...", level: .debug, category: "CollectionMgr")
        Logger.log("Current user ID: \(userId)", level: .debug, category: "CollectionMgr")
        
        // Create a batch write
        let batch = db.batch()
        
        // Update owner's collection with members field
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: userId, collectionId: collection.id)
        
        // Include owner in members list
        let allMembers = [userId] + friends.map { $0.id }
        
        batch.updateData([
            "members": allMembers,
            "sharedAt": FieldValue.serverTimestamp()
        ], forDocument: ownerCollectionRef)
        
        // Create shared collection in each friend's collections
        for friend in friends {
            Logger.log("Sharing with friend ID: \(friend.id)", level: .debug, category: "CollectionMgr")
            
            let sharedCollectionRef = FirestorePaths.collectionDoc(userId: friend.id, collectionId: collection.id)
            
            var sharedCollectionData: [String: Any] = [
                "id": collection.id,
                "name": collection.name,
                "places": collection.places.map { $0.dictionary },
                "userId": userId,  // This is the owner's ID
                "createdAt": Timestamp(date: collection.createdAt),
                "isOwner": false,
                "status": collection.status.rawValue,
                "sharedBy": userId,  // This is the owner's ID
                "sharedAt": FieldValue.serverTimestamp(),
                "members": allMembers  // Include all members in shared copy
            ]
            
            // Include iconName if it exists (for backward compatibility)
            if let iconName = collection.iconName {
                sharedCollectionData["iconName"] = iconName
            }
            
            // Include iconUrl if it exists (for custom images)
            if let iconUrl = collection.iconUrl {
                sharedCollectionData["iconUrl"] = iconUrl
            }
            
            Logger.log("Creating shared collection in path: users/\(friend.id)/collections/\(collection.id)", level: .debug, category: "CollectionMgr")
            Logger.log("Shared collection data: \(sharedCollectionData)", level: .debug, category: "CollectionMgr")
            
            batch.setData(sharedCollectionData, forDocument: sharedCollectionRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                Logger.log("Error sharing collection: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                completion(.failure(error))
            } else {
                Logger.log("Successfully shared collection with \(friends.count) friends", level: .info, category: "CollectionMgr")
                completion(.success(()))
            }
        }
    }
    
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData, for collection: PlaceCollection, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        Logger.log("Updating avatar data for collection '\(collection.name)'...", level: .debug, category: "CollectionMgr")
        
        FirestorePaths.collectionDoc(userId: userId, collectionId: collection.id)
            .updateData(["avatarData": avatarData.toFirestoreDict()]) { error in
                if let error = error {
                    Logger.log("Error updating avatar data: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                    completion(.failure(error))
                } else {
                    Logger.log("Successfully updated avatar data", level: .info, category: "CollectionMgr")
                    completion(.success(()))
                }
            }
    }
}
