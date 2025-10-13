import UIKit
import GooglePlaces

@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()
    private init() {}

    func handle(url: URL, in window: UIWindow?) -> Bool {
        Logger.log("Handle URL=\(url.absoluteString)", level: .debug, category: "DeepLink")
        
        // Simple parsing for nose://open?placeId=...
        if url.scheme?.lowercased() == "nose" {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = comps?.queryItems,
               let placeId = queryItems.first(where: { $0.name == "placeId" })?.value,
               !placeId.isEmpty {
                Logger.log("Found placeId=\(placeId)", level: .debug, category: "DeepLink")
                openPlaceInApp(placeId: placeId, in: window)
                return true
            }
        }
        
        Logger.log("No recognizable content in URL", level: .warn, category: "DeepLink")
        showAlert(title: "Cannot Open Link", message: "This link doesn't include a recognizable place.", in: window)
        return false
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
