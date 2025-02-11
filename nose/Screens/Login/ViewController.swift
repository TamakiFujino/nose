import UIKit
import Firebase
import GoogleSignIn
import AuthenticationServices

class ViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        // Add heading
        let headingLabel = UILabel()
        headingLabel.text = "自分だけの地図をつくろう"
        headingLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        headingLabel.textColor = .white
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headingLabel)
        
        // Create Google sign-in button
       let googleButton = UIButton(type: .system)
       googleButton.frame = CGRect(x: (view.bounds.width - (view.bounds.width * 0.8)) / 2, y: view.bounds.height - 70, width: view.bounds.width * 0.8, height: 45)
       googleButton.backgroundColor = .white
       googleButton.layer.cornerRadius = 20
       googleButton.setTitle("   Sign in with Google", for: .normal)
       googleButton.setTitleColor(.black, for: .normal)
       googleButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
       googleButton.setImage(UIImage(systemName: "g.circle.fill"), for: .normal) // Google icon
       googleButton.tintColor = .black
       googleButton.imageView?.contentMode = .scaleAspectFit
       googleButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
       googleButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
       view.addSubview(googleButton)
        
        
        // Set up Apple Sign-In button
        let appleButton = UIButton(type: .system)
        appleButton.frame = CGRect(x: (view.bounds.width - (view.bounds.width * 0.8)) / 2, y: view.bounds.height - 130, width: view.bounds.width * 0.8, height: 45)
        appleButton.backgroundColor = .white
        appleButton.layer.cornerRadius = 20
        appleButton.setTitle("   Sign in with Apple", for: .normal)
        appleButton.setTitleColor(.black, for: .normal)
        appleButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        appleButton.setImage(UIImage(systemName: "applelogo"), for: .normal) // Apple icon
        appleButton.tintColor = .black
        appleButton.imageView?.contentMode = .scaleAspectFit
        appleButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        // appleButton.addTarget(self, action: #selector(appleSignIn), for: .touchUpInside)
        view.addSubview(appleButton)
        
        // Layout constraints for heading and buttons
        NSLayoutConstraint.activate([
            // Heading left aligned
            headingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Google Button constraints
            googleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            googleButton.bottomAnchor.constraint(equalTo: appleButton.topAnchor, constant: -20),
            googleButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            googleButton.heightAnchor.constraint(equalToConstant: 45),
            
            // Apple Button constraints
            appleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            appleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            appleButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            appleButton.heightAnchor.constraint(equalToConstant: 45)
        ])
        
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
    
    @objc func appleSignInTapped() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = randomNonceString() else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase authentication failed: \(error.localizedDescription)")
                    return
                }
                print("Apple Login Successful! ✅")
                
                // Check if the user needs to input their name
                self.checkUserStatus()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple errored: \(error.localizedDescription)")
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    private func randomNonceString(length: Int = 32) -> String? {
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    return 0
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}
