//
//  SceneDelegate.swift
//  nose
//
//  Created by Tamaki Fujino on 2025/01/18.
//

import UIKit
import GoogleSignIn

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var pendingDeepLinkURL: URL?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        
        // Always start with login/auth check screen
        let loginVC = ViewController()
        loginVC.sceneDelegate = self
        let nav = UINavigationController(rootViewController: loginVC)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()

        // Store any URL that launched the app to handle after auth
        if let url = connectionOptions.urlContexts.first?.url {
            pendingDeepLinkURL = url
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        
        // Handle Google Sign-In URL first
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        
        // If user is authenticated and home is showing, handle immediately
        if let nav = window?.rootViewController as? UINavigationController,
           nav.viewControllers.first is HomeViewController {
            _ = DeepLinkManager.shared.handle(url: url, in: window)
        } else {
            // Store for later (auth flow is still in progress)
            pendingDeepLinkURL = url
        }
    }
    
    func didFinishAuthentication() {
        // Called by ViewController after successful auth transition to HomeViewController
        
        // 1. Handle Deep Links
        if let url = pendingDeepLinkURL {
            pendingDeepLinkURL = nil
            // Small delay to ensure HomeViewController is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                _ = DeepLinkManager.shared.handle(url: url, in: self.window)
            }
        }
        
        // 2. Handle Share Inbox (from Extension)
        // We call this here to ensure Auth is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DeepLinkManager.shared.processShareInbox(in: self.window)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Process any pending items in the Share Inbox (from Share Extension)
        DeepLinkManager.shared.processShareInbox(in: window)
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

}
