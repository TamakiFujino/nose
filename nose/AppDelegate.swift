import UIKit
import FirebaseCore
import GoogleSignIn
import GoogleMaps
import GooglePlaces
import Firebase

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?  // Only used for iOS 12 or lower

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        if let options = FirebaseApp.app()?.options {
            print("✅ Firebase App Config:")
            print("Project ID: \(options.projectID ?? "nil")")
            print("Google App ID: \(options.googleAppID)")
            print("Database URL: \(options.databaseURL ?? "nil")")
        }
        
        // Get API keys from Config.plist
        guard let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
              let mapsAPIKey = plistDict["GoogleMapsAPIKey"] as? String,
              let placesAPIKey = plistDict["GooglePlacesAPIKey"] as? String else {
            fatalError("Couldn't find API keys in Config.plist")
        }
        
        // Configure Google Maps and Places
        GMSServices.provideAPIKey(mapsAPIKey)
        GMSPlacesClient.provideAPIKey(placesAPIKey)
        
        // Bridge Unity notification fallback (when UnityBridgeShim posts from UnityFramework)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NoseUnityResponseNotification"),
            object: nil,
            queue: .main
        ) { notification in
            if let json = notification.userInfo?["json"] as? String {
                UnityResponseHandler.handleUnityResponseStatic(json)
            }
        }

        return true
    }
    
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) { return true }
        return DeepLinkManager.shared.handle(url: url, in: window)
    }

    // MARK: UISceneSession Lifecycle (used for iOS 13+)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Called when the user discards a scene session.
    }
}
