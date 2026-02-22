import UIKit
import GooglePlaces
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()
    private init() {}
    
    // MARK: - Link Generation
    
    static func generateCollectionLink(collectionId: String, userId: String) -> String {
        var components = URLComponents()
        components.scheme = "nose"
        components.host = "collection"
        components.queryItems = [
            URLQueryItem(name: "collectionId", value: collectionId),
            URLQueryItem(name: "userId", value: userId)
        ]
        return components.url?.absoluteString ?? ""
    }

    func handle(url: URL, in window: UIWindow?) -> Bool {
        Logger.log("Handle URL=\(url.absoluteString)", level: .debug, category: "DeepLink")
        
        // Simple parsing for nose://open?placeId=... or nose://collection?collectionId=...
        if url.scheme?.lowercased() == "nose" {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = comps?.queryItems {
                // Check for collection link first
                if let collectionId = queryItems.first(where: { $0.name == "collectionId" })?.value,
                   !collectionId.isEmpty,
                   let userId = queryItems.first(where: { $0.name == "userId" })?.value,
                   !userId.isEmpty {
                    Logger.log("Found collectionId=\(collectionId), userId=\(userId)", level: .debug, category: "DeepLink")
                    openCollectionInApp(collectionId: collectionId, userId: userId, in: window)
                    return true
                }
                // Check for place link
                if let placeId = queryItems.first(where: { $0.name == "placeId" })?.value, !placeId.isEmpty {
                    Logger.log("Found placeId=\(placeId)", level: .debug, category: "DeepLink")
                    openPlaceInApp(placeId: placeId, in: window)
                    return true
                }
                if let coords = queryItems.first(where: { $0.name == "placeId" })?.value,
                   coords.hasPrefix("coords:") {
                    let pair = coords.replacingOccurrences(of: "coords:", with: "")
                    let parts = pair.split(separator: ",").map(String.init)
                    if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) {
                        openCoordinateInApp(latitude: lat, longitude: lng, in: window)
                        return true
                    }
                }
                if let passThroughURL = queryItems.first(where: { $0.name == "url" })?.value,
                   let original = URL(string: passThroughURL) {
                    Logger.log("Pass-through URL=\(original.absoluteString)", level: .debug, category: "DeepLink")
                    
                    // Check if it's a shortened URL that needs resolution
                    if isShortenedURL(original) {
                        Logger.log("Detected shortened URL, resolving...", level: .info, category: "DeepLink")
                        resolveShortURL(original) { [weak self] resolvedURL in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                if let resolved = resolvedURL {
                                    Logger.log("Resolved to: \(resolved.absoluteString)", level: .info, category: "DeepLink")
                                    self.processResolvedURL(resolved, in: window)
                                } else {
                                    self.showAlert(title: "Error", message: "Could not resolve the link.", in: window)
                                }
                            }
                        }
                        return true // We are handling it async
                    }
                    
                    // Best-effort: try to extract coordinates or place id and open
                    if let pid = Self.extractPlaceIdOrCoords(from: original) {
                        processPlaceIdOrCoords(pid, in: window)
                        return true
                    }
                }
            }
        }
        
        Logger.log("No recognizable content in URL", level: .warn, category: "DeepLink")
        showAlert(title: "Cannot Open Link", message: "This link doesn't include a recognizable place.", in: window)
        return false
    }
    
    // MARK: - Share Inbox Processing
    
    func processShareInbox(in window: UIWindow?) {
        // Ensure user is authenticated before processing
        guard Auth.auth().currentUser != nil else {
            Logger.log("⏳ Deferring Share Inbox processing until Auth is ready", level: .info, category: "DeepLink")
            return
        }
        
        guard let defaults = UserDefaults(suiteName: "group.com.tamakifujino.nose"),
              let inbox = defaults.array(forKey: "ShareInbox") as? [[String: Any]],
              !inbox.isEmpty else {
            return
        }
        
        Logger.log("📥 Processing \(inbox.count) items from Share Inbox", level: .info, category: "DeepLink")
        
        // Clear inbox immediately to prevent duplicate processing
        defaults.set([], forKey: "ShareInbox")
        defaults.synchronize()
        
        var processedCount = 0
        
        for item in inbox {
            let collectionId = item["collectionId"] as? String ?? ""
            let collectionName = item["collectionName"] as? String ?? ""
            let type = item["type"] as? String ?? "url"
            let content = item["content"] as? String ?? item["url"] as? String ?? ""
            
            guard !collectionId.isEmpty, !content.isEmpty else { continue }
            
            if type == "text" {
                // Handle plain text query (Address/Name)
                Logger.log("Processing TEXT share: \(content)", level: .info, category: "DeepLink")
                searchPlaceAndAdd(query: content, collectionId: collectionId, collectionName: collectionName) { success in
                    if success { processedCount += 1 }
                }
            } else {
                // Handle URL
                if let url = URL(string: content) {
                    Logger.log("Processing URL share: \(content)", level: .info, category: "DeepLink")
                    resolveAndAddToCollection(url: url, collectionId: collectionId, collectionName: collectionName) { success in
                        if success { processedCount += 1 }
                    }
                }
            }
        }
    }
    
    private func resolveAndAddToCollection(url: URL, collectionId: String, collectionName: String, completion: @escaping (Bool) -> Void) {
        // Helper to handle the flow: Resolve URL -> Find Place -> Add to Firestore
        
        let handleResolvedURL: (URL) -> Void = { [weak self] resolvedURL in
            guard let self = self else { return }
            
            // 1. Extract ID or Coords
            if let pid = Self.extractPlaceIdOrCoords(from: resolvedURL) {
                if pid.hasPrefix("coords:") {
                     // Coords not supported for collection addition yet (need GMSPlace)
                     completion(false)
                } else {
                    self.fetchPlaceAndAdd(placeId: pid, collectionId: collectionId, collectionName: collectionName, completion: completion)
                }
            } else if let comps = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false),
                      let rawQuery = comps.queryItems?.first(where: { $0.name == "q" })?.value {
                // 2. Search by Query
                let query = rawQuery.replacingOccurrences(of: "+", with: " ")
                self.searchPlaceAndAdd(query: query, collectionId: collectionId, collectionName: collectionName, completion: completion)
            } else {
                completion(false)
            }
        }
        
        if isShortenedURL(url) {
            resolveShortURL(url) { resolved in
                if let res = resolved {
                    DispatchQueue.main.async { handleResolvedURL(res) }
                } else {
                    completion(false)
                }
            }
        } else {
            handleResolvedURL(url)
        }
    }
    
    private func fetchPlaceAndAdd(placeId: String, collectionId: String, collectionName: String, completion: @escaping (Bool) -> Void) {
        PlacesAPIManager.shared.fetchDetailPlaceDetails(placeID: placeId) { [weak self] place in
            DispatchQueue.main.async {
                if let place = place {
                    self?.addPlaceToFirestore(place: place, collectionId: collectionId, collectionName: collectionName, completion: completion)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func searchPlaceAndAdd(query: String, collectionId: String, collectionName: String, completion: @escaping (Bool) -> Void) {
        let filter = GMSAutocompleteFilter()
        filter.type = .establishment
        let placesClient = GMSPlacesClient.shared()
        
        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { [weak self] (results, error) in
            DispatchQueue.main.async {
                if let result = results?.first {
                    self?.fetchPlaceAndAdd(placeId: result.placeID, collectionId: collectionId, collectionName: collectionName, completion: completion)
                } else {
                    // Try fallback (last part of query)
                    let parts = query.split(separator: " ")
                    if parts.count > 1, let lastPart = parts.last, lastPart.count > 2 {
                        let fallbackQuery = String(lastPart)
                        placesClient.findAutocompletePredictions(fromQuery: fallbackQuery, filter: filter, sessionToken: nil) { (retryResults, retryError) in
                            DispatchQueue.main.async {
                                if let retryResult = retryResults?.first {
                                    self?.fetchPlaceAndAdd(placeId: retryResult.placeID, collectionId: collectionId, collectionName: collectionName, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }
    
    private func addPlaceToFirestore(place: GMSPlace, collectionId: String, collectionName: String, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let collectionRef = db.collection("users").document(userId).collection("collections").document(collectionId)
        
        let placeData: [String: Any] = [
            "placeId": place.placeID ?? "",
            "name": place.name ?? "",
            "formattedAddress": place.formattedAddress ?? "",
            "rating": place.rating,
            "phoneNumber": place.phoneNumber ?? "",
            "addedAt": Timestamp(date: Date()),
            "visited": false
        ]
        
        collectionRef.updateData([
            "places": FieldValue.arrayUnion([placeData])
        ]) { error in
            if let error = error {
                Logger.log("Error adding place to collection: \(error.localizedDescription)", level: .error, category: "DeepLink")
                completion(false)
            } else {
                Logger.log("Successfully added \(place.name ?? "") to \(collectionName)", level: .info, category: "DeepLink")
                // Notify collection list to refresh
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                completion(true)
            }
        }
    }
    
    private func processPlaceIdOrCoords(_ pid: String, in window: UIWindow?) {
        if pid.hasPrefix("coords:") {
            let pair = pid.replacingOccurrences(of: "coords:", with: "")
            let parts = pair.split(separator: ",").map(String.init)
            if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) {
                openCoordinateInApp(latitude: lat, longitude: lng, in: window)
            }
        } else {
            openPlaceInApp(placeId: pid, in: window)
        }
    }
    
    private func processResolvedURL(_ url: URL, in window: UIWindow?) {
        if let pid = Self.extractPlaceIdOrCoords(from: url) {
            processPlaceIdOrCoords(pid, in: window)
        } else if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let rawQuery = comps.queryItems?.first(where: { $0.name == "q" })?.value {
            // Clean up the query: replace + with space, remove postal codes if they cause issues
            let query = rawQuery.replacingOccurrences(of: "+", with: " ")
            
            // Fallback: Search for the place by name/address from the query param
            Logger.log("Searching for place by query: \(query)", level: .info, category: "DeepLink")
            searchForPlaceByName(query, in: window)
        } else {
            showAlert(title: "Cannot Open Link", message: "The resolved link doesn't include a recognizable place.", in: window)
        }
    }
    
    private func searchForPlaceByName(_ query: String, in window: UIWindow?) {
        // Use GMSPlacesClient to search for the place
        let filter = GMSAutocompleteFilter()
        filter.type = .establishment
        
        let placesClient = GMSPlacesClient.shared()
        
        // Function to handle results
        let handleResults: ([GMSAutocompletePrediction]?, Error?) -> Void = { [weak self] (results, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let result = results?.first {
                    Logger.log("Found prediction: \(result.attributedFullText.string) (ID: \(result.placeID))", level: .info, category: "DeepLink")
                    self.openPlaceInApp(placeId: result.placeID, in: window)
                } else {
                    // If full query failed, try heuristic: last component (often the name in Japanese formatting)
                    let parts = query.split(separator: " ")
                    if parts.count > 1, let lastPart = parts.last, lastPart.count > 2 {
                        let fallbackQuery = String(lastPart)
                        Logger.log("Retrying with fallback query: \(fallbackQuery)", level: .info, category: "DeepLink")
                        
                        // Avoid infinite recursion loop, just do one simple retry
                        placesClient.findAutocompletePredictions(fromQuery: fallbackQuery, filter: filter, sessionToken: nil) { (retryResults, retryError) in
                            DispatchQueue.main.async {
                                if let retryResult = retryResults?.first {
                                    Logger.log("Found prediction with fallback: \(retryResult.attributedFullText.string)", level: .info, category: "DeepLink")
                                    self.openPlaceInApp(placeId: retryResult.placeID, in: window)
                                } else {
                                    Logger.log("No places found for query or fallback", level: .warn, category: "DeepLink")
                                    self.showAlert(title: "Place Not Found", message: "Could not find a matching place.", in: window)
                                }
                            }
                        }
                    } else {
                        Logger.log("No places found for query", level: .warn, category: "DeepLink")
                        self.showAlert(title: "Place Not Found", message: "Could not find a matching place.", in: window)
                    }
                }
            }
        }
        
        // First attempt: Full query
        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil, callback: handleResults)
    }
    
    private func isShortenedURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("goo.gl") || host.contains("g.co") || host.contains("maps.app.goo.gl")
    }
    
    private func resolveShortURL(_ url: URL, completion: @escaping (URL?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                Logger.log("Error resolving URL: \(error.localizedDescription)", level: .error, category: "DeepLink")
                completion(nil)
                return
            }
            
            // Check for Location header or final URL
            if let httpResponse = response as? HTTPURLResponse,
               let location = httpResponse.allHeaderFields["Location"] as? String,
               let fullURL = URL(string: location) {
                completion(fullURL)
            } else if let url = response?.url {
                completion(url)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
    
    private func openPlaceInApp(placeId: String, in window: UIWindow?) {
        Logger.log("Open place in app: \(placeId)", level: .info, category: "DeepLink")
        
        // Fetch place details
        PlacesAPIManager.shared.fetchDetailPlaceDetails(placeID: placeId) { [weak self] place in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let place = place {
                    Logger.log("Fetched place: \(place.name ?? "Unknown")", level: .info, category: "DeepLink")
                    self.showPlaceInMap(place: place, in: window)
                } else {
                    Logger.log("Failed to fetch place details", level: .warn, category: "DeepLink")
                    self.showAlert(title: "Place Not Found", message: "Could not find details for this place.", in: window)
                }
            }
        }
    }
    
    private func showPlaceInMap(place: GMSPlace, in window: UIWindow?) {
        // Find or create HomeViewController
        guard let homeVC = findOrCreateHomeViewController(in: window) else {
            showAlert(title: "Error", message: "Could not open the map.", in: window)
            return
        }
        
        // Move map to the place
        homeVC.mapManager?.showPlaceOnMap(place)
        
        // Show place detail
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        homeVC.present(detailViewController, animated: true)
    }
    
    private func openCoordinateInApp(latitude: Double, longitude: Double, in window: UIWindow?) {
        guard let homeVC = findOrCreateHomeViewController(in: window) else {
            showAlert(title: "Error", message: "Could not open the map.", in: window)
            return
        }
        
        // Move map to coordinates first
        homeVC.mapManager?.clearMarkers()
        homeVC.mapManager?.moveToCoordinate(latitude, longitude, zoom: 15)
        
        // Try to find a place at this location using nearby search
        findPlaceAtCoordinates(latitude: latitude, longitude: longitude, in: window)
    }
    
    private func openCollectionInApp(collectionId: String, userId: String, in window: UIWindow?) {
        Logger.log("Open collection in app: collectionId=\(collectionId), userId=\(userId)", level: .info, category: "DeepLink")
        
        // Ensure user is authenticated
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Sign In Required", message: "Please sign in to add this collection.", in: window)
            return
        }
        
        // Don't allow adding your own collection
        if currentUserId == userId {
            showAlert(title: "Already Owned", message: "This is your own collection.", in: window)
            return
        }
        
        let db = Firestore.firestore()
        
        // First, check if the user already has this collection
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        
        userCollectionRef.getDocument { [weak self] userSnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error checking existing collection: \(error.localizedDescription)", level: .error, category: "DeepLink")
                self.showAlert(title: "Error", message: "Failed to check collection. Please try again.", in: window)
                return
            }
            
            // If user already has the collection, just open it
            if userSnapshot?.exists == true {
                DispatchQueue.main.async {
                    self.openCollectionView(collectionId: collectionId, userId: userId, in: window)
                }
                return
            }
            
            // Fetch the collection from the owner
            let ownerCollectionRef = FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId, db: db)
            
            ownerCollectionRef.getDocument { [weak self] ownerSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Error fetching collection: \(error.localizedDescription)", level: .error, category: "DeepLink")
                    self.showAlert(title: "Collection Not Found", message: "This collection could not be found.", in: window)
                    return
                }
                
                guard let ownerData = ownerSnapshot?.data(),
                      ownerSnapshot?.exists == true else {
                    self.showAlert(title: "Collection Not Found", message: "This collection could not be found.", in: window)
                    return
                }
                
                // Parse the collection
                guard let collection = PlaceCollection(dictionary: ownerData) else {
                    self.showAlert(title: "Error", message: "Failed to load collection data.", in: window)
                    return
                }
                
                // Check if collection is active
                guard collection.status == .active else {
                    self.showAlert(title: "Collection Unavailable", message: "This collection is no longer available.", in: window)
                    return
                }
                
                // Check if current user is a friend of the collection owner
                let friendsRef = db.collection("users")
                    .document(currentUserId)
                    .collection("friends")
                    .document(userId)
                
                friendsRef.getDocument { [weak self] friendSnapshot, friendError in
                    guard let self = self else { return }
                    
                    // If not friends, show alert with Add Friend option
                    if friendSnapshot?.exists != true {
                        DispatchQueue.main.async {
                            self.showFriendRequiredAlert(ownerUserId: userId, in: window)
                        }
                        return
                    }
                    
                    // If friends, proceed with adding the collection
                    // Get current members from owner's collection
                    let currentMembers = ownerData["members"] as? [String] ?? [userId]
                    
                    // Create shared collection for current user
                    // Note: We only create in the current user's path - we cannot update the owner's collection
                    // because the current user is not yet a member (Firestore permission rules)
                    var sharedCollectionData: [String: Any] = [
                        "id": collection.id,
                        "name": collection.name,
                        "userId": userId,
                        "sharedBy": userId,
                        "createdAt": Timestamp(date: collection.createdAt),
                        "isOwner": false,
                        "status": collection.status.rawValue,
                        "places": collection.places.map { $0.dictionary },
                        "members": currentMembers + [currentUserId]  // Add current user to members
                    ]
                    
                    // Include iconName if it exists
                    if let iconName = collection.iconName {
                        sharedCollectionData["iconName"] = iconName
                    }
                    
                    // Include iconUrl if it exists
                    if let iconUrl = collection.iconUrl {
                        sharedCollectionData["iconUrl"] = iconUrl
                    }
                    
                    // Only create the collection in the current user's path
                    // We cannot update the owner's collection because the current user is not a member yet
                    // The owner will need to update their collection separately if needed
                    userCollectionRef.setData(sharedCollectionData) { [weak self] error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            DispatchQueue.main.async {
                                Logger.log("Error adding collection: \(error.localizedDescription)", level: .error, category: "DeepLink")
                                self.showAlert(title: "Error", message: "Failed to add collection. Please try again.", in: window)
                            }
                        } else {
                            Logger.log("Successfully added collection: \(collection.name)", level: .info, category: "DeepLink")
                            
                            // Create shared collection object from the data we prepared
                            guard let sharedCollection = PlaceCollection(dictionary: sharedCollectionData) else {
                                DispatchQueue.main.async {
                                    Logger.log("Failed to create shared collection object", level: .error, category: "DeepLink")
                                    self.showAlert(title: "Error", message: "Failed to open collection. Please try again.", in: window)
                                }
                                return
                            }
                            
                            // Fetch owner's name to show in toast
                            db.collection("users").document(userId).getDocument { [weak self] ownerSnapshot, ownerError in
                                DispatchQueue.main.async {
                                    guard let self = self else { return }
                                    
                                    let ownerName: String
                                    if let ownerData = ownerSnapshot?.data(),
                                       let name = ownerData["name"] as? String {
                                        ownerName = name
                                    } else {
                                        ownerName = "the owner"
                                    }
                                    
                                    // Show toast message
                                    ToastManager.showToast(
                                        message: "You joined the collection created by \(ownerName)",
                                        type: .success
                                    )
                                    
                                    // Post notification to refresh collections
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                                    
                                    // Open the collection view directly using the collection we already have
                                    self.openCollectionViewDirectly(collection: sharedCollection, in: window)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showFriendRequiredAlert(ownerUserId: String, in window: UIWindow?) {
        // Fetch the owner's user document to get their userId (10-character ID)
        let db = Firestore.firestore()
        db.collection("users").document(ownerUserId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            let ownerUserIdString: String
            if let data = snapshot?.data(),
               let userId = data["userId"] as? String {
                ownerUserIdString = userId
            } else {
                // Fallback to ownerUserId if userId field not found
                ownerUserIdString = ownerUserId
            }
            
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Friend Required",
                    message: "To join the collection, you need to be friend with the collection owner.",
                    preferredStyle: .alert
                )
                
                // OK button
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                // Add Friend button
                alert.addAction(UIAlertAction(title: "Add Friend", style: .default) { [weak self] _ in
                    self?.navigateToAddFriend(ownerUserId: ownerUserIdString, in: window)
                })
                
                // Present the alert
                if let root = (window ?? UIApplication.shared.windows.first { $0.isKeyWindow })?.rootViewController {
                    root.present(alert, animated: true)
                }
            }
        }
    }
    
    private func navigateToAddFriend(ownerUserId: String, in window: UIWindow?) {
        // Find the current navigation controller or create one
        guard let rootVC = (window ?? UIApplication.shared.windows.first { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        // Try to find existing navigation controller
        var navController: UINavigationController?
        
        if let nav = rootVC as? UINavigationController {
            navController = nav
        } else if let tabBar = rootVC as? UITabBarController,
                  let selectedNav = tabBar.selectedViewController as? UINavigationController {
            navController = selectedNav
        } else if let presented = rootVC.presentedViewController as? UINavigationController {
            navController = presented
        }
        
        // If no navigation controller found, create one
        if navController == nil {
            // Find HomeViewController to get its navigation controller
            if let homeVC = findOrCreateHomeViewController(in: window),
               let nav = homeVC.navigationController {
                navController = nav
            }
        }
        
        // Create and push AddFriendViewController
        let addFriendVC = AddFriendViewController()
        
        // Pre-fill the search bar with the owner's userId
        addFriendVC.setSearchText(ownerUserId)
        
        if let nav = navController {
            nav.pushViewController(addFriendVC, animated: true)
        } else {
            // Fallback: present modally with navigation controller
            let nav = UINavigationController(rootViewController: addFriendVC)
            rootVC.present(nav, animated: true)
        }
    }
    
    private func openCollectionViewDirectly(collection: PlaceCollection, in window: UIWindow?) {
        DispatchQueue.main.async {
            // Find or create HomeViewController
            guard let homeVC = self.findOrCreateHomeViewController(in: window) else {
                self.showAlert(title: "Error", message: "Could not open the collection.", in: window)
                return
            }
            
            // Present CollectionPlacesViewController
            let collectionVC = CollectionPlacesViewController(collection: collection)
            if let sheet = collectionVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            homeVC.present(collectionVC, animated: true)
        }
    }
    
    private func openCollectionView(collectionId: String, userId: String, in window: UIWindow?) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Fetch the collection from current user's collections (which may be shared)
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        
        userCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error fetching collection for view: \(error.localizedDescription)", level: .error, category: "DeepLink")
                return
            }
            
            guard let data = snapshot?.data(),
                  let collection = PlaceCollection(dictionary: data) else {
                Logger.log("Failed to parse collection data", level: .error, category: "DeepLink")
                return
            }
            
            self.openCollectionViewDirectly(collection: collection, in: window)
        }
    }
    
    private func findPlaceAtCoordinates(latitude: Double, longitude: Double, in window: UIWindow?) {
        Logger.log("Finding place at coordinates: \(latitude), \(longitude)", level: .info, category: "DeepLink")
        
        // Validate coordinates
        guard abs(latitude) <= 90.0 && abs(longitude) <= 180.0 else {
            Logger.log("Invalid coordinates: \(latitude), \(longitude)", level: .warn, category: "DeepLink")
            showLocationSharedMessage(address: nil, in: window)
            return
        }
        
        // Use reverse geocoding to get an address for these coordinates
        // Make it optional - if it fails, just show the map without address
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        // Set a timeout for reverse geocoding (3 seconds)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    // Only log if it's not a common network/cancellation error
                    if let cleError = error as? CLError {
                        // Common CoreLocation errors - silently fail
                        if cleError.code != .network && cleError.code != .locationUnknown {
                            Logger.log("Reverse geocoding error: \(error.localizedDescription)", level: .debug, category: "DeepLink")
                        }
                    } else {
                        let nsError = error as NSError
                        // Check if it's a CoreLocation network error (code 2)
                        if nsError.code != 2 {
                            Logger.log("Reverse geocoding error: \(error.localizedDescription)", level: .debug, category: "DeepLink")
                        }
                    }
                    // Silently fail - map is already moved to the location
                    self.showLocationSharedMessage(address: nil, in: window)
                    return
                }
                
                if let placemark = placemarks?.first {
                    // Try to construct an address
                    var addressComponents: [String] = []
                    if let thoroughfare = placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                    if let locality = placemark.locality {
                        addressComponents.append(locality)
                    }
                    let address = addressComponents.isEmpty ? nil : addressComponents.joined(separator: ", ")
                    
                    Logger.log("Reverse geocoded address: \(address ?? "Unknown")", level: .info, category: "DeepLink")
                    self.showLocationSharedMessage(address: address, in: window)
                } else {
                    Logger.log("No placemark found for coordinates", level: .debug, category: "DeepLink")
                    self.showLocationSharedMessage(address: nil, in: window)
                }
            }
        }
    }
    
    private func showLocationSharedMessage(address: String?, in window: UIWindow?) {
        let message: String
        if let address = address {
            message = "Map moved to \(address). You can search for places nearby."
        } else {
            message = "Map moved to shared location. You can search for places nearby."
        }
        Logger.log("Showing location shared message: \(message)", level: .info, category: "DeepLink")
        // Note: We show the message but don't block the UI
        // The map has already been moved, so the user can interact with it
    }
    
    private static func extractPlaceIdOrCoords(from url: URL) -> String? {
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let q = comps.queryItems?.first(where: { $0.name == "q" })?.value,
           q.lowercased().hasPrefix("place_id:") {
            return String(q.dropFirst("place_id:".count))
        }
        let path = url.absoluteString
        if let range = path.range(of: "!1s") {
            let tail = path[range.upperBound...]
            if let end = tail.firstIndex(of: "!") {
                let pid = String(tail[..<end])
                if pid.hasPrefix("ChI") { return pid }
            }
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let latLongQuery = comps.queryItems?.first(where: { $0.name == "ll" })?.value ??
                               comps.queryItems?.first(where: { $0.name == "q" })?.value
            if let latLong = latLongQuery, latLong.contains(",") {
                let parts = latLong.split(separator: ",").map(String.init)
                if parts.count == 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lng = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return "coords:\(lat),\(lng)"
                }
            }
        }
        return nil
    }
    
    private func findOrCreateHomeViewController(in window: UIWindow?) -> HomeViewController? {
        guard let window = window ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return nil }

        if let nav = window.rootViewController as? UINavigationController,
           let homeVC = nav.viewControllers.first as? HomeViewController {
            return homeVC
        } else {
            // If no HomeVC is root, create one and set it as root
            let homeVC = HomeViewController()
            let navController = UINavigationController(rootViewController: homeVC)
            window.rootViewController = navController
            window.makeKeyAndVisible()
            return homeVC
        }
    }
    
    private func showAlert(title: String, message: String, in window: UIWindow?) {
        Logger.log("Alert: \(title) - \(message)", level: .warn, category: "DeepLink")
        let messageModal = MessageModalViewController(title: title, message: message)
        
        if let root = (window ?? UIApplication.shared.windows.first { $0.isKeyWindow })?.rootViewController {
            root.present(messageModal, animated: true)
        }
    }
}
