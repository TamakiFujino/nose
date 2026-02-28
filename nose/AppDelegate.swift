import UIKit
import FirebaseCore
import GoogleSignIn
import MapboxMaps
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
            Logger.log("Firebase App Config:", level: .info, category: "AppDelegate")
            Logger.log("Project ID: \(options.projectID ?? "nil")", level: .debug, category: "AppDelegate")
            Logger.log("Google App ID: \(options.googleAppID)", level: .debug, category: "AppDelegate")
            Logger.log("Database URL: \(options.databaseURL ?? "nil")", level: .debug, category: "AppDelegate")
            Logger.log("Client ID: \(options.clientID)", level: .debug, category: "AppDelegate")
        }
        
        // Configure Google Sign-In
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            Logger.log("No client ID found in Firebase configuration", level: .error, category: "AppDelegate")
            return false
        }
        
        if let path = Bundle.main.path(forResource: "GoogleService-Info-Development", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let reversedClientID = plist["REVERSED_CLIENT_ID"] as? String {
            Logger.log("Google Sign-In Config:", level: .info, category: "AppDelegate")
            Logger.log("Client ID: \(clientID)", level: .debug, category: "AppDelegate")
            Logger.log("Reversed Client ID: \(reversedClientID)", level: .debug, category: "AppDelegate")
        } else {
            Logger.log("Could not find GoogleService-Info-Development.plist", level: .warn, category: "AppDelegate")
        }
        
        // Get API keys from Config.plist
        guard let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
              let mapboxAccessToken = plistDict["MapboxAccessToken"] as? String,
              let placesAPIKey = plistDict["GooglePlacesAPIKey"] as? String else {
            Logger.log("Couldn't find API keys in Config.plist", level: .error, category: "AppDelegate")
            return false
        }
        
        // Configure Mapbox - set access token as environment variable
        // Mapbox Maps SDK v11 will automatically read from environment variable
        setenv("MAPBOX_ACCESS_TOKEN", mapboxAccessToken, 1)
        
        // Configure Google Places (still using Google Places API)
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
