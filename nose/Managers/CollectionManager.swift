import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Firebase

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
    
    // MARK: - Collection Fetching
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
