import UIKit
import Firebase
import GoogleSignIn

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGoogleSignInButton()
        
        // Ensure Firebase restores session
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                print("User is already logged in: \(user.uid)")
                self.checkUserStatus()
            } else {
                print("No user session found, waiting for login.")
            }
        }
    }
    
    func checkUserStatus() {
        if let user = Auth.auth().currentUser {
            if user.displayName == nil || user.displayName!.isEmpty {
                showNameInputScreen()  // Show name input screen for first-time users
            } else {
                goToMainScreen()  // Proceed to main app
            }
        }
    }
    
    func showNameInputScreen() {
        let nameInputVC = NameInputViewController()
        nameInputVC.modalPresentationStyle = .fullScreen
        present(nameInputVC, animated: true)
    }
    
    func goToMainScreen() {
        print("User has a name, proceeding to main app")
        let homeViewController = HomeViewController()
        homeViewController.modalPresentationStyle = .fullScreen
        self.present(homeViewController, animated: true, completion: nil)
    }
    
    func setupGoogleSignInButton() {
        let signInButton = GIDSignInButton()
        signInButton.center = view.center
        view.addSubview(signInButton)
        
        // Add a target to the button for the tap action
        signInButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
    }
    
    @objc func googleSignInTapped(_ sender: Any) {
        print("Google Sign-In tapped")
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("No clientID found")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { result, error in
            if let error = error {
                print("Google Sign-In failed: \(error.localizedDescription)")
                return
            }
            
            guard let authentication = result?.user, let idToken = authentication.idToken else {
                print("No authentication or ID token")
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString,
                                                           accessToken: authentication.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase authentication failed: \(error.localizedDescription)")
                    return
                }
                print("Google Login Successful! ✅")
                
                // Check if the user needs to input their name
                self.checkUserStatus()
            }
        }
    }
}
