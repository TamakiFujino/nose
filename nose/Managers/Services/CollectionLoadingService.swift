import Foundation
import FirebaseAuth
import FirebaseFirestore

/// A centralized service for loading user collections from Firestore.
/// Eliminates duplicate collection loading logic across ViewControllers.
final class CollectionLoadingService {
    static let shared = CollectionLoadingService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Result Types
    
    struct LoadResult {
        let owned: [PlaceCollection]
        let shared: [PlaceCollection]
    }
    
    // MARK: - Public Methods
    
    /// Loads all collections for the current user.
    /// - Parameters:
    ///   - status: Filter by collection status (nil for all statuses)
    ///   - completion: Called with the result containing owned and shared collections
    func loadCollections(
        status: PlaceCollection.Status? = .active,
        completion: @escaping (Result<LoadResult, Error>) -> Void
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(CollectionError.notAuthenticated))
            return
        }
        
        let group = DispatchGroup()
        var ownedCollections: [PlaceCollection] = []
        var sharedCollections: [PlaceCollection] = []
        var loadError: Error?
        
        // Load owned collections
        group.enter()
        loadOwnedCollections(userId: currentUserId, status: status) { result in
            switch result {
            case .success(let collections):
                ownedCollections = collections
            case .failure(let error):
                loadError = error
            }
            group.leave()
        }
        
        // Load shared collections
        group.enter()
        loadSharedCollections(userId: currentUserId, status: status) { result in
            switch result {
            case .success(let collections):
                sharedCollections = collections
            case .failure(let error):
                if loadError == nil {
                    loadError = error
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let error = loadError {
                completion(.failure(error))
            } else {
                completion(.success(LoadResult(owned: ownedCollections, shared: sharedCollections)))
            }
        }
    }
    
    /// Loads only owned collections for the current user.
    func loadOwnedCollections(
        userId: String,
        status: PlaceCollection.Status? = nil,
        completion: @escaping (Result<[PlaceCollection], Error>) -> Void
    ) {
        var query: Query = FirestorePaths.collections(userId: userId, db: db)
            .whereField("isOwner", isEqualTo: true)
        
        if let status = status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                Logger.log("Error loading owned collections: \(error.localizedDescription)", level: .error, category: "CollectionService")
                completion(.failure(error))
                return
            }
            
            let collections = snapshot?.documents.compactMap { document -> PlaceCollection? in
                var data = document.data()
                data["id"] = document.documentID
                data["isOwner"] = true
                
                // If status is missing, treat it as active
                if data["status"] == nil {
                    data["status"] = PlaceCollection.Status.active.rawValue
                }
                
                return PlaceCollection(dictionary: data)
            } ?? []
            
            completion(.success(collections))
        }
    }
    
    /// Loads shared collections for the current user, verifying owner accounts exist.
    func loadSharedCollections(
        userId: String,
        status: PlaceCollection.Status? = nil,
        completion: @escaping (Result<[PlaceCollection], Error>) -> Void
    ) {
        var query: Query = FirestorePaths.collections(userId: userId, db: db)
            .whereField("isOwner", isEqualTo: false)
        
        if let status = status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error loading shared collections: \(error.localizedDescription)", level: .error, category: "CollectionService")
                completion(.failure(error))
                return
            }
            
            let group = DispatchGroup()
            var loadedCollections: [PlaceCollection] = []
            
            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                
                guard let ownerId = data["userId"] as? String,
                      let collectionId = data["id"] as? String else {
                    group.leave()
                    return
                }
                
                // Verify owner account exists and is not deleted
                self.verifyOwnerAndLoadCollection(
                    ownerId: ownerId,
                    collectionId: collectionId,
                    currentUserId: userId,
                    status: status
                ) { collection in
                    if let collection = collection {
                        loadedCollections.append(collection)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                completion(.success(loadedCollections))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Verifies the owner account exists and loads the original collection data.
    private func verifyOwnerAndLoadCollection(
        ownerId: String,
        collectionId: String,
        currentUserId: String,
        status: PlaceCollection.Status?,
        completion: @escaping (PlaceCollection?) -> Void
    ) {
        // Check if owner account still exists and is not deleted
        FirestorePaths.userDoc(ownerId, db: db).getDocument { [weak self] ownerSnapshot, ownerError in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let ownerError = ownerError {
                Logger.log("Error checking owner: \(ownerError.localizedDescription)", level: .error, category: "CollectionService")
                completion(nil)
                return
            }
            
            // Check if owner is deleted or doesn't exist
            let ownerData = ownerSnapshot?.data()
            let isOwnerDeleted = ownerData?["isDeleted"] as? Bool ?? false
            
            if ownerSnapshot?.exists == false || isOwnerDeleted {
                // Mark this collection as inactive in user's database
                self.markCollectionInactive(userId: currentUserId, collectionId: collectionId)
                completion(nil)
                return
            }
            
            // Owner exists, proceed to load the collection
            FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: self.db)
                .getDocument { snapshot, error in
                    if let error = error {
                        Logger.log("Error loading original collection: \(error.localizedDescription)", level: .error, category: "CollectionService")
                        completion(nil)
                        return
                    }
                    
                    guard let originalData = snapshot?.data() else {
                        completion(nil)
                        return
                    }
                    
                    var collectionData = originalData
                    collectionData["id"] = collectionId
                    collectionData["isOwner"] = false
                    
                    // If status is missing, treat it as active
                    if collectionData["status"] == nil {
                        collectionData["status"] = PlaceCollection.Status.active.rawValue
                    }
                    
                    // Filter by status if specified
                    if let status = status {
                        let collectionStatus = collectionData["status"] as? String
                        if collectionStatus != status.rawValue {
                            completion(nil)
                            return
                        }
                    }
                    
                    completion(PlaceCollection(dictionary: collectionData))
                }
        }
    }
    
    /// Marks a collection as inactive when the owner account has been deleted.
    private func markCollectionInactive(userId: String, collectionId: String) {
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId, db: db)
            .updateData([
                "status": "inactive",
                "ownerDeleted": true
            ]) { error in
                if let error = error {
                    Logger.log("Error marking collection as inactive: \(error.localizedDescription)", level: .error, category: "CollectionService")
                }
            }
    }
}

// MARK: - Errors

extension CollectionLoadingService {
    enum CollectionError: LocalizedError {
        case notAuthenticated
        case loadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User not authenticated"
            case .loadFailed(let reason):
                return "Failed to load collections: \(reason)"
            }
        }
    }
}
