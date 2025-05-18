import UIKit
import Firebase
import GoogleSignIn
import AuthenticationServices

class ViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        // Ensure Firebase restores session
        Auth.auth().addStateDidChangeListener { _, user in
            if let user = user {
                print("User is already logged in: \(user.uid)")
                self.checkUserStatus()
            } else {
                print("No user session found, waiting for login.")
            }
        }
    }

    func setupUI() {
        view.backgroundColor = .white

        // Background gradient
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)

        // Heading
        let headingLabel = UILabel()
        headingLabel.text = NSLocalizedString("slogan_firstline", comment: "") +
                            "\n" +
                            NSLocalizedString("slogan_secondline", comment: "")
        headingLabel.font = .systemFont(ofSize: 28, weight: .bold)
        headingLabel.textColor = .fourthColor
        headingLabel.numberOfLines = 0
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headingLabel)

        // Terms & Privacy label
                let termsLabel = UILabel()
                termsLabel.numberOfLines = 0
                termsLabel.textAlignment = .center
                termsLabel.textColor = .label
                termsLabel.font = .systemFont(ofSize: 12)
                termsLabel.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(termsLabel)

                // Build attributed string with line break after "you agree to"
                let baseText = "By signing up, you agree to\nour "
                let termsText = NSMutableAttributedString(string: baseText)

                // Underline only, inherit .label color
                let underlineStyle = NSUnderlineStyle.single.rawValue
                let linkAttributes: [NSAttributedString.Key: Any] = [
                    .underlineStyle: underlineStyle,
                    .underlineColor: termsLabel.textColor!
                ]

                let tosString = NSAttributedString(string: "Terms of Service", attributes: linkAttributes)
                let andString = NSAttributedString(string: " and")
                let ppString  = NSAttributedString(string: " Privacy Policy.", attributes: linkAttributes)

                termsText.append(tosString)
                termsText.append(andString)
                termsText.append(ppString)
                termsLabel.attributedText = termsText
                termsLabel.isUserInteractionEnabled = true
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(termsTapped(_:)))
                termsLabel.addGestureRecognizer(tapGesture)
        
        // Google button
                let googleButton = makeSignInButton(
                    title: NSLocalizedString("google_login", comment: ""),
                    systemImage: "g.circle.fill",
                    action: #selector(googleSignInTapped)
                )
                view.addSubview(googleButton)

                // Apple button
                let appleButton = makeSignInButton(
                    title: NSLocalizedString("apple_login", comment: ""),
                    systemImage: "applelogo",
                    action: #selector(appleSignInTapped)
                )
                view.addSubview(appleButton)

        // Layout
                NSLayoutConstraint.activate([
                    headingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                    headingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),

                    termsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    termsLabel.bottomAnchor.constraint(equalTo: googleButton.topAnchor, constant: -20),
                    termsLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),

                    googleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    googleButton.bottomAnchor.constraint(equalTo: appleButton.topAnchor, constant: -15),
                    googleButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
                    googleButton.heightAnchor.constraint(equalToConstant: 45),

                    appleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    appleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                    appleButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
                    appleButton.heightAnchor.constraint(equalToConstant: 45)
                ])
    }
    
        private func makeSignInButton(title: String, systemImage: String, action: Selector) -> UIButton {
            let btn = UIButton(type: .system)
            btn.backgroundColor = .fourthColor
            btn.layer.cornerRadius = 8
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(.firstColor, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            btn.setImage(UIImage(systemName: systemImage), for: .normal)
            btn.tintColor = .firstColor
            btn.imageView?.contentMode = .scaleAspectFit
            btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            btn.addTarget(self, action: action, for: .touchUpInside)
            btn.translatesAutoresizingMaskIntoConstraints = false
            return btn
        }

    @objc func termsTapped(_ sender: UITapGestureRecognizer) {
        let text = (sender.view as! UILabel).text ?? ""
        let termsRange = (text as NSString).range(of: "Terms of Service")
        let privacyRange = (text as NSString).range(of: "Privacy Policy")

        if sender.didTapAttributedTextInLabel(label: sender.view as! UILabel, inRange: termsRange) {
            let tosVC = ToSViewController()
            self.navigationController?.pushViewController(tosVC, animated: true)
        } else if sender.didTapAttributedTextInLabel(label: sender.view as! UILabel, inRange: privacyRange) {
            let privacyVC = PrivacyPolicyViewController()
            self.navigationController?.pushViewController(privacyVC, animated: true)
        }
    }

    func checkUserStatus() {
        guard let user = Auth.auth().currentUser else {
            showNameInputScreen()
            return
        }

        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(user.uid)

        userDocRef.getDocument { (document, _) in
            if let document = document, document.exists {
                if let status = document.data()?["status"] as? String, status == "deleted" {
                    self.showNameInputScreen()
                } else {
                    self.goToMainScreen()
                }
            } else {
                self.showNameInputScreen()
            }
        }
    }

    func showNameInputScreen() {
        let nameregisterVC = NameRegisterViewController()
        if let navController = self.navigationController {
            navController.pushViewController(nameregisterVC, animated: true)
        } else {
            let navController = UINavigationController(rootViewController: nameregisterVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true, completion: nil)
        }
    }

    func goToMainScreen() {
        print("User has a name, proceeding to main app")
        let homeViewController = HomeViewController()
        if let navController = self.navigationController {
            navController.pushViewController(homeViewController, animated: true)
        } else {
            let navController = UINavigationController(rootViewController: homeViewController)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true, completion: nil)
        }
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

            Auth.auth().signIn(with: credential) { _, error in
                if let error = error {
                    print("Firebase authentication failed: \(error.localizedDescription)")
                    return
                }
                print("Google Login Successful! ✅")

                // Check if the user needs to input their name
                self.checkOrCreateUserProfile()
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

            Auth.auth().signIn(with: credential) { _, error in
                if let error = error {
                    print("Firebase authentication failed: \(error.localizedDescription)")
                    return
                }
                print("Apple Login Successful! ✅")

                // Check if the user needs to input their name
                self.checkOrCreateUserProfile()
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
        let charset: [Character] =
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

    private func checkOrCreateUserProfile() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in.")
            return
        }

        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(user.uid)

        userDocRef.getDocument { (document, _) in
            if let document = document, document.exists {
                if let status = document.data()?["status"] as? String, status == "deleted" {
                    self.showNameInputScreen()
                } else {
                    self.goToMainScreen()
                }
            } else {
                self.createUserProfile()
            }
        }
    }

    private func generateSingleFriendCode(length: Int = 9) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    private func generateAndCheckFriendCode(attempt: Int = 0, maxAttempts: Int = 5, completion: @escaping (String?) -> Void) {
        if attempt >= maxAttempts {
            print("Error: Could not generate a unique friendCode after \(maxAttempts) attempts.")
            completion(nil)
            return
        }

        let potentialCode = generateSingleFriendCode()
        let db = Firestore.firestore()

        db.collection("users").whereField("friendCode", isEqualTo: potentialCode).getDocuments { (querySnapshot, err) in
            if let err = err {
                print("Error checking friendCode uniqueness: \(err.localizedDescription)")
                // Decide if to retry or fail. For now, fail on DB error.
                completion(nil)
                return
            }

            if querySnapshot == nil || querySnapshot!.isEmpty {
                // No documents found with this friendCode, so it's unique
                completion(potentialCode)
            } else {
                // Collision detected, try again
                print("FriendCode collision for \(potentialCode), retrying...")
                self.generateAndCheckFriendCode(attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
            }
        }
    }

    private func createUserProfile() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in for profile creation.")
            return
        }

        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(user.uid)

        // Generate a unique friend code first
        generateAndCheckFriendCode { [weak self] friendCode in
            guard let self = self else { return }

            var userData: [String: Any] = [
                "uid": user.uid,
                "email": user.email ?? "",
                "displayName": user.displayName ?? "", // Note: Apple Sign In might provide this, Google might not immediately.
                "createdAt": FieldValue.serverTimestamp(),
                "status": "active"
            ]

            if let fc = friendCode {
                userData["friendCode"] = fc
                print("Generated unique friendCode: \(fc)")
            } else {
                print("Proceeding with user profile creation without a friendCode due to generation failure.")
                // Optionally, you could prevent profile creation or schedule a retry
            }

            userDocRef.setData(userData) { error in
                if let error = error {
                    print("Error creating user profile: \(error.localizedDescription)")
                } else {
                    print("User profile created successfully (friendCode: \(friendCode ?? "N/A")).")
                    // Regardless of friendCode success, proceed to name input if that's the flow
                    self.showNameInputScreen()
                }
            }
        }
    }
}

private extension UITapGestureRecognizer {
    func didTapAttributedTextInLabel(label: UILabel, inRange targetRange: NSRange) -> Bool {
        guard let attributedText = label.attributedText else { return false }

        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        mutableString.addAttributes([.font: label.font!], range: NSRange(location: 0, length: attributedText.length))

        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: mutableString)
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let locationOfTouchInLabel = self.location(in: label)
        let textBoundingBox = layoutManager.usedRect(for: textContainer)
        let textContainerOffset = CGPoint(
            x: (label.bounds.size.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
            y: (label.bounds.size.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y
        )
        let locationOfTouchInTextContainer = CGPoint(
            x: locationOfTouchInLabel.x - textContainerOffset.x,
            y: locationOfTouchInLabel.y - textContainerOffset.y
        )
        let indexOfCharacter = layoutManager.characterIndex(for: locationOfTouchInTextContainer, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        return NSLocationInRange(indexOfCharacter, targetRange)
    }
}
