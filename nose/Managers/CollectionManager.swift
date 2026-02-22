import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import GooglePlaces
import Firebase
import UIKit

class CollectionManager {
    static let shared = CollectionManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let collectionsCollection = "collections"
    
    // Cache for collection icons (persists across view controller instances)
    private var cachedIcons: [String: [CollectionIcon]] = [:] // category -> icons
    private var iconCacheQueue = DispatchQueue(label: "com.nose.collectionIcons.cache", qos: .utility)
    
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
        
        let collectionRef = db.collection("users")
            .document(userId)
            .collection("collections")
            .document(UUID().uuidString)
        
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
        
        let collectionRef = db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collectionId)
        
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
        
        // Update owner's collection with members field
        let ownerCollectionRef = db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collection.id)
        
        // Include owner in members list
        let allMembers = [userId] + friends.map { $0.id }
        
        batch.updateData([
            "members": allMembers,
            "sharedAt": FieldValue.serverTimestamp()
        ], forDocument: ownerCollectionRef)
        
        // Create shared collection in each friend's collections
        for friend in friends {
            print("📤 Sharing with friend ID: \(friend.id)")
            
            let sharedCollectionRef = db.collection("users")
                .document(friend.id)
                .collection("collections")
                .document(collection.id)
            
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
            
            print("📤 Creating shared collection in path: users/\(friend.id)/collections/\(collection.id)")
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
            .updateData(["avatarData": avatarData.toFirestoreDict()]) { error in
                if let error = error {
                    print("❌ Error updating avatar data: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Successfully updated avatar data")
                    completion(.success(()))
                }
            }
    }
    
    // MARK: - Collection Icons
    struct CollectionIcon {
        let name: String
        let url: String
        let category: String // "hobby", "food", "place", "sports", "symbol"
    }
    
    func fetchCollectionIcons(completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        print("🔄 Fetching collection icons from Firebase Storage...")
        
        let categories = ["hobby", "food", "place", "sports", "symbol"]
        let group = DispatchGroup()
        let iconsQueue = DispatchQueue(label: "com.nose.collectionIcons", attributes: .concurrent)
        var allIcons: [CollectionIcon] = []
        
        // First, try to fetch from categorized folders
        for category in categories {
            group.enter()
            
            let categoryRef = storage.reference().child("collection_icons/\(category)")
            
            categoryRef.listAll { result, error in
                if let error = error {
                    print("⚠️ Error listing icons from \(category) folder: \(error.localizedDescription)")
                    group.leave()
                    return
                }
                
                guard let items = result?.items, !items.isEmpty else {
                    print("⚠️ No icons found in \(category) folder")
                    group.leave()
                    return
                }
                
                print("📁 Found \(items.count) items in \(category) folder")
                
                // Get download URLs for all items in this category
                let iconGroup = DispatchGroup()
                var categoryIcons: [CollectionIcon] = []
                let categoryQueue = DispatchQueue(label: "com.nose.collectionIcons.\(category)")
                
                for item in items {
                    iconGroup.enter()
                    
                    item.downloadURL { url, error in
                        defer { iconGroup.leave() }
                        
                        if let error = error {
                            print("⚠️ Error getting download URL for \(item.name): \(error.localizedDescription)")
                            return
                        }
                        
                        guard let downloadURL = url else {
                            return
                        }
                        
                        // Extract name from file name (remove extension)
                        let name = item.name.replacingOccurrences(of: ".jpg", with: "")
                            .replacingOccurrences(of: ".png", with: "")
                            .replacingOccurrences(of: ".jpeg", with: "")
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized
                        
                        let icon = CollectionIcon(name: name, url: downloadURL.absoluteString, category: category)
                        
                        // Thread-safe append to categoryIcons
                        categoryQueue.async {
                            categoryIcons.append(icon)
                        }
                    }
                }
                
                iconGroup.notify(queue: categoryQueue) {
                    // All icons for this category are now in categoryIcons
                    // Append all icons from this category to allIcons (thread-safe)
                    iconsQueue.async(flags: .barrier) {
                        allIcons.append(contentsOf: categoryIcons)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            iconsQueue.sync {
                // If no icons found in categorized folders, try root collection_icons folder (backward compatibility)
                if allIcons.isEmpty {
                    print("⚠️ No icons found in categorized folders, checking root collection_icons folder...")
                    self.fetchIconsFromRootFolder(completion: completion)
                } else {
                    // Sort by category, then by name
                    allIcons.sort { icon1, icon2 in
                        if icon1.category == icon2.category {
                            return icon1.name < icon2.name
                        }
                        return icon1.category < icon2.category
                    }
                    
                    let finalIcons = allIcons
                    print("✅ Loaded \(finalIcons.count) collection icons from Storage across \(categories.count) categories")
                    completion(.success(finalIcons))
                }
            }
        }
    }
    
    // Backward compatibility: Fetch icons from root collection_icons folder
    private func fetchIconsFromRootFolder(completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        print("🔄 Fetching icons from root collection_icons folder (backward compatibility)...")
        
        let storageRef = storage.reference().child("collection_icons")
        
        storageRef.listAll { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error listing collection icons from root folder: \(error.localizedDescription)")
                // Final fallback: Try Firestore
                self.fetchCollectionIconsFromFirestore(completion: completion)
                return
            }
            
            // Debug logging
            print("📊 Root folder contents:")
            print("   - Items (files): \(result?.items.count ?? 0)")
            print("   - Prefixes (subfolders): \(result?.prefixes.count ?? 0)")
            if let prefixes = result?.prefixes {
                print("   - Subfolder names: \(prefixes.map { $0.name })")
            }
            
            guard let items = result?.items, !items.isEmpty else {
                print("⚠️ No collection icons (files) found in root folder, trying Firestore...")
                print("   (Note: If your icons are in subfolders like hobby/, food/, etc., that's expected)")
                // Final fallback: Try Firestore
                self.fetchCollectionIconsFromFirestore(completion: completion)
                return
            }
            
            print("📁 Found \(items.count) items in root collection_icons folder")
            
            // Get download URLs for all items
            let group = DispatchGroup()
            var icons: [CollectionIcon] = []
            
            for item in items {
                group.enter()
                
                item.downloadURL { url, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("⚠️ Error getting download URL for \(item.name): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let downloadURL = url else {
                        return
                    }
                    
                    // Extract name from file name (remove extension)
                    let name = item.name.replacingOccurrences(of: ".jpg", with: "")
                        .replacingOccurrences(of: ".png", with: "")
                        .replacingOccurrences(of: ".jpeg", with: "")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    
                    // Assign to "hobby" category by default for backward compatibility
                    let icon = CollectionIcon(name: name, url: downloadURL.absoluteString, category: "hobby")
                    icons.append(icon)
                }
            }
            
            group.notify(queue: .main) {
                // Sort by name
                icons.sort { $0.name < $1.name }
                
                if icons.isEmpty {
                    print("⚠️ No valid icons found, trying Firestore...")
                    self.fetchCollectionIconsFromFirestore(completion: completion)
                } else {
                    print("✅ Loaded \(icons.count) collection icons from root folder (assigned to 'hobby' category)")
                    completion(.success(icons))
                }
            }
        }
    }
    
    // Fallback method: Fetch from Firestore if Storage doesn't work
    private func fetchCollectionIconsFromFirestore(completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        print("🔄 Fetching collection icons from Firestore (fallback)...")
        
        db.collection("collection_icons")
            .order(by: "name")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching collection icons from Firestore: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No collection icons found in Firestore")
                    completion(.success([]))
                    return
                }
                
                let icons = documents.compactMap { doc -> CollectionIcon? in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let url = data["url"] as? String else {
                        return nil
                    }
                    // Firestore fallback uses "hobby" as default category
                    let category = data["category"] as? String ?? "hobby"
                    return CollectionIcon(name: name, url: url, category: category)
                }
                
                print("✅ Loaded \(icons.count) collection icons from Firestore")
                completion(.success(icons))
            }
    }
    
    // MARK: - Upload Collection Icon (Helper method for admin/manual setup)
    /// Uploads an image to Firebase Storage and creates a Firestore document for it
    /// This is a helper method that can be called manually or through admin tools
    func uploadCollectionIcon(image: UIImage, name: String, category: String = "hobby", completion: @escaping (Result<Void, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "CollectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        // Upload to Firebase Storage in categorized folder
        let storageRef = storage.reference()
        let imageName = "\(name.replacingOccurrences(of: " ", with: "_")).jpg"
        let imageRef = storageRef.child("collection_icons/\(category)/\(imageName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error uploading collection icon image: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Get download URL
            imageRef.downloadURL { [weak self] url, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "CollectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                // Create Firestore document with category
                self.db.collection("collection_icons").addDocument(data: [
                    "name": name,
                    "url": downloadURL.absoluteString,
                    "category": category
                ]) { error in
                    if let error = error {
                        print("❌ Error creating collection icon document: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("✅ Successfully uploaded collection icon: \(name) in category: \(category)")
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch Icons by Category (Storage-based with caching)
    func fetchCollectionIcons(for category: String, completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        let categoryLowercase = category.lowercased()
        
        // Check cache first
        iconCacheQueue.sync {
            if let cached = cachedIcons[categoryLowercase] {
                print("✅ Loaded \(cached.count) collection icons from cache for category: \(category)")
                DispatchQueue.main.async {
                    completion(.success(cached))
                }
                return
            }
        }
        
        print("🔄 Fetching collection icons from Storage for category: \(category)...")
        
        let categoryRef = storage.reference().child("collection_icons/\(categoryLowercase)")
        
        categoryRef.listAll { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ Error listing icons from \(category) folder: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let items = result?.items, !items.isEmpty else {
                print("⚠️ No icons found in \(category) folder")
                completion(.success([]))
                return
            }
            
            print("📁 Found \(items.count) items in \(category) folder")
            
            // Get download URLs for all items in this category
            let group = DispatchGroup()
            var icons: [CollectionIcon] = []
            let iconsQueue = DispatchQueue(label: "com.nose.collectionIcons.\(categoryLowercase)")
            
            for item in items {
                group.enter()
                
                item.downloadURL { url, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("⚠️ Error getting download URL for \(item.name): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let downloadURL = url else {
                        return
                    }
                    
                    // Extract name from file name (remove extension)
                    let name = item.name.replacingOccurrences(of: ".jpg", with: "")
                        .replacingOccurrences(of: ".png", with: "")
                        .replacingOccurrences(of: ".jpeg", with: "")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    
                    let icon = CollectionIcon(name: name, url: downloadURL.absoluteString, category: categoryLowercase)
                    
                    // Thread-safe append (serial queue ensures order)
                    iconsQueue.async {
                        icons.append(icon)
                    }
                }
            }
            
            group.notify(queue: iconsQueue) {
                // Sort by name (now on the serial queue, all appends are done)
                icons.sort { $0.name < $1.name }
                
                // Cache the icons
                self.iconCacheQueue.async {
                    self.cachedIcons[categoryLowercase] = icons
                }
                
                DispatchQueue.main.async {
                    print("✅ Loaded \(icons.count) collection icons from Storage for category: \(category)")
                    completion(.success(icons))
                }
            }
        }
    }
    
    // MARK: - Clear Icon Cache (optional - for refreshing)
    func clearIconCache(for category: String? = nil) {
        iconCacheQueue.async { [weak self] in
            guard let self = self else { return }
            if let category = category {
                self.cachedIcons.removeValue(forKey: category.lowercased())
                print("🗑️ Cleared icon cache for category: \(category)")
            } else {
                self.cachedIcons.removeAll()
                print("🗑️ Cleared all icon cache")
            }
        }
    }
}
