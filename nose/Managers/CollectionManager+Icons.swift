import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

extension CollectionManager {

    // MARK: - Collection Icons
    struct CollectionIcon {
        let name: String
        let url: String
        let category: String // "hobby", "food", "place", "sports", "symbol"
    }

    func fetchCollectionIcons(completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        Logger.log("Fetching collection icons from Firebase Storage...", level: .debug, category: "CollectionMgr")

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
                    Logger.log("Error listing icons from \(category) folder: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                    group.leave()
                    return
                }

                guard let items = result?.items, !items.isEmpty else {
                    Logger.log("No icons found in \(category) folder", level: .warn, category: "CollectionMgr")
                    group.leave()
                    return
                }

                Logger.log("Found \(items.count) items in \(category) folder", level: .info, category: "CollectionMgr")

                // Get download URLs for all items in this category
                let iconGroup = DispatchGroup()
                var categoryIcons: [CollectionIcon] = []
                let categoryQueue = DispatchQueue(label: "com.nose.collectionIcons.\(category)")

                for item in items {
                    iconGroup.enter()

                    item.downloadURL { url, error in
                        defer { iconGroup.leave() }

                        if let error = error {
                            Logger.log("Error getting download URL for \(item.name): \(error.localizedDescription)", level: .error, category: "CollectionMgr")
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
                    Logger.log("No icons found in categorized folders, checking root collection_icons folder...", level: .warn, category: "CollectionMgr")
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
                    Logger.log("Loaded \(finalIcons.count) collection icons from Storage across \(categories.count) categories", level: .info, category: "CollectionMgr")
                    completion(.success(finalIcons))
                }
            }
        }
    }

    // Backward compatibility: Fetch icons from root collection_icons folder
    private func fetchIconsFromRootFolder(completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        Logger.log("Fetching icons from root collection_icons folder (backward compatibility)...", level: .debug, category: "CollectionMgr")

        let storageRef = storage.reference().child("collection_icons")

        storageRef.listAll { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                Logger.log("Error listing collection icons from root folder: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                // Final fallback: Try Firestore
                self.fetchCollectionIconsFromFirestore(completion: completion)
                return
            }

            // Debug logging
            Logger.log("Root folder contents:", level: .debug, category: "CollectionMgr")
            Logger.log("   - Items (files): \(result?.items.count ?? 0)", level: .debug, category: "CollectionMgr")
            Logger.log("   - Prefixes (subfolders): \(result?.prefixes.count ?? 0)", level: .debug, category: "CollectionMgr")
            if let prefixes = result?.prefixes {
                Logger.log("   - Subfolder names: \(prefixes.map { $0.name })", level: .debug, category: "CollectionMgr")
            }

            guard let items = result?.items, !items.isEmpty else {
                Logger.log("No collection icons (files) found in root folder, trying Firestore...", level: .warn, category: "CollectionMgr")
                Logger.log("   (Note: If your icons are in subfolders like hobby/, food/, etc., that's expected)", level: .debug, category: "CollectionMgr")
                // Final fallback: Try Firestore
                self.fetchCollectionIconsFromFirestore(completion: completion)
                return
            }

            Logger.log("Found \(items.count) items in root collection_icons folder", level: .info, category: "CollectionMgr")

            // Get download URLs for all items
            let group = DispatchGroup()
            var icons: [CollectionIcon] = []

            for item in items {
                group.enter()

                item.downloadURL { url, error in
                    defer { group.leave() }

                    if let error = error {
                        Logger.log("Error getting download URL for \(item.name): \(error.localizedDescription)", level: .error, category: "CollectionMgr")
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
                    Logger.log("No valid icons found, trying Firestore...", level: .warn, category: "CollectionMgr")
                    self.fetchCollectionIconsFromFirestore(completion: completion)
                } else {
                    Logger.log("Loaded \(icons.count) collection icons from root folder (assigned to 'hobby' category)", level: .info, category: "CollectionMgr")
                    completion(.success(icons))
                }
            }
        }
    }

    // Fallback method: Fetch from Firestore if Storage doesn't work
    private func fetchCollectionIconsFromFirestore(completion: @escaping (Result<[CollectionIcon], Error>) -> Void) {
        Logger.log("Fetching collection icons from Firestore (fallback)...", level: .debug, category: "CollectionMgr")

        db.collection("collection_icons")
            .order(by: "name")
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.log("Error fetching collection icons from Firestore: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    Logger.log("No collection icons found in Firestore", level: .warn, category: "CollectionMgr")
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

                Logger.log("Loaded \(icons.count) collection icons from Firestore", level: .info, category: "CollectionMgr")
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
                Logger.log("Error uploading collection icon image: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                completion(.failure(error))
                return
            }

            // Get download URL
            imageRef.downloadURL { [weak self] url, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.log("Error getting download URL: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
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
                        Logger.log("Error creating collection icon document: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                        completion(.failure(error))
                    } else {
                        Logger.log("Successfully uploaded collection icon: \(name) in category: \(category)", level: .info, category: "CollectionMgr")
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
                Logger.log("Loaded \(cached.count) collection icons from cache for category: \(category)", level: .info, category: "CollectionMgr")
                DispatchQueue.main.async {
                    completion(.success(cached))
                }
                return
            }
        }

        Logger.log("Fetching collection icons from Storage for category: \(category)...", level: .debug, category: "CollectionMgr")

        let categoryRef = storage.reference().child("collection_icons/\(categoryLowercase)")

        categoryRef.listAll { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                Logger.log("Error listing icons from \(category) folder: \(error.localizedDescription)", level: .error, category: "CollectionMgr")
                completion(.failure(error))
                return
            }

            guard let items = result?.items, !items.isEmpty else {
                Logger.log("No icons found in \(category) folder", level: .warn, category: "CollectionMgr")
                completion(.success([]))
                return
            }

            Logger.log("Found \(items.count) items in \(category) folder", level: .info, category: "CollectionMgr")

            // Get download URLs for all items in this category
            let group = DispatchGroup()
            var icons: [CollectionIcon] = []
            let iconsQueue = DispatchQueue(label: "com.nose.collectionIcons.\(categoryLowercase)")

            for item in items {
                group.enter()

                item.downloadURL { url, error in
                    defer { group.leave() }

                    if let error = error {
                        Logger.log("Error getting download URL for \(item.name): \(error.localizedDescription)", level: .error, category: "CollectionMgr")
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
                    Logger.log("Loaded \(icons.count) collection icons from Storage for category: \(category)", level: .info, category: "CollectionMgr")
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
                Logger.log("Cleared icon cache for category: \(category)", level: .debug, category: "CollectionMgr")
            } else {
                self.cachedIcons.removeAll()
                Logger.log("Cleared all icon cache", level: .debug, category: "CollectionMgr")
            }
        }
    }
}
