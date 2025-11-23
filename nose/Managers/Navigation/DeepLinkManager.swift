import UIKit
import GooglePlaces
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()
    private init() {}

    func handle(url: URL, in window: UIWindow?) -> Bool {
        Logger.log("Handle URL=\(url.absoluteString)", level: .debug, category: "DeepLink")
        
        // Simple parsing for nose://open?placeId=...
        if url.scheme?.lowercased() == "nose" {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = comps?.queryItems {
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
            guard let urlString = item["url"] as? String,
                  let url = URL(string: urlString),
                  let collectionId = item["collectionId"] as? String,
                  let collectionName = item["collectionName"] as? String else {
                continue
            }
            
            // Resolve URL and Add to Collection
            resolveAndAddToCollection(url: url, collectionId: collectionId, collectionName: collectionName) { success in
                if success {
                    processedCount += 1
                }
                if processedCount > 0 {
                    Logger.log("✅ Successfully processed share item for collection: \(collectionName)", level: .info, category: "DeepLink")
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
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let root = (window ?? UIApplication.shared.windows.first { $0.isKeyWindow })?.rootViewController {
            root.present(alert, animated: true)
        }
    }
}
