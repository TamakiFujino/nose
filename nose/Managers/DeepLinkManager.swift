import UIKit
import GooglePlaces

@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()
    private init() {}

    func handle(url: URL, in window: UIWindow?) -> Bool {
        print("[DeepLink] handle url=\(url.absoluteString)")
        
        // Simple parsing for nose://open?placeId=...
        if url.scheme?.lowercased() == "nose" {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = comps?.queryItems,
               let placeId = queryItems.first(where: { $0.name == "placeId" })?.value,
               !placeId.isEmpty {
                print("[DeepLink] found placeId=\(placeId)")
                openPlaceInApp(placeId: placeId, in: window)
                return true
            }
        }
        
        print("[DeepLink] no recognizable content in url")
        showAlert(title: "Cannot Open Link", message: "This link doesn't include a recognizable place.", in: window)
        return false
    }
    
    private func openPlaceInApp(placeId: String, in window: UIWindow?) {
        print("[DeepLink] Opening place \(placeId) in app")
        
        // Fetch place details
        PlacesAPIManager.shared.fetchDetailPlaceDetails(placeID: placeId) { [weak self] place in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let place = place {
                    print("[DeepLink] Successfully fetched place: \(place.name ?? "Unknown")")
                    self.showPlaceInMap(place: place, in: window)
                } else {
                    print("[DeepLink] Failed to fetch place details")
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
        print("[DeepLink] alert: \(title) - \(message)")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let root = (window ?? UIApplication.shared.windows.first { $0.isKeyWindow })?.rootViewController {
            root.present(alert, animated: true)
        }
    }
}
