//
//  AppDelegate.swift
//  nose
//
//  Created by Tamaki Fujino on 2025/01/18.
//

import UIKit
import GoogleMaps
import GooglePlaces
import FirebaseCore
import Firebase
import GoogleSignIn

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()
        
        // Initialize Google sign-in
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if error != nil || user == nil {
                // Show the app's signed-out state.
            } else {
                // Show the app's signed-in state.
            }
        }
        
        do {
            try Auth.auth().useUserAccessGroup(nil) // Ensures persistence
        } catch let error {
            print("Error enabling Auth persistence: \(error.localizedDescription)")
        }
        
        // Attempt to load the API key from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let apiKey = config["GoogleMapsAPIKey"] as? String, !apiKey.isEmpty {
            
            // Provide API Key to Google Maps and Places SDK
            GMSServices.provideAPIKey(apiKey)
            GMSPlacesClient.provideAPIKey(apiKey)
            
            print("Google Maps API Key Loaded Successfully!")
            
        } else {
            print("Failed to load Google Maps API Key. Check Config.plist.")
        }
        
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return false
        }
        
        if host == "bookmark" {
            if let queryItems = components.queryItems,
               let id = queryItems.first(where: { $0.name == "id" })?.value {
                navigateToBookmarkList(withId: id)
                return true
            }
        }
        
        return false
    }

    // Navigate to the bookmark list with the given ID
    private func navigateToBookmarkList(withId id: String) {
        guard let navigationController = window?.rootViewController as? UINavigationController else {
            return
        }

        let savedBookmarksVC = SavedBookmarksViewController()
        navigationController.pushViewController(savedBookmarksVC, animated: true)

        // Delay to allow the view controller to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            savedBookmarksVC.showBookmarkList(withId: id)
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
