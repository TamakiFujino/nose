//
//  AppDelegate.swift
//  nose
//
//  Created by Tamaki Fujino on 2025/01/18.
//

import UIKit
import GoogleMaps
import GooglePlaces

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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

