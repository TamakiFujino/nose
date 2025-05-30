import UIKit
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import AuthenticationServices
import CryptoKit
import FirebaseFirestore

final class ViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var sloganLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Travel Through Time,\nChange for the Future"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .black
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var appleButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container view for icon and text
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and configure the icon
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "apple.logo")?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = .firstColor
        iconImageView.contentMode = .scaleAspectFit
        
        // Create and configure the label
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Continue with Apple"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .firstColor
        
        // Add subviews to container
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        
        // Set up constraints for the container
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // Add container to button
        button.addSubview(containerView)
        
        // Center the container in the button
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }()
    
    private lazy var googleButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container view for icon and text
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create and configure the icon
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(named: "google_logo")?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = .firstColor
        iconImageView.contentMode = .scaleAspectFit
        
        // Create and configure the label
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Continue with Google"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .firstColor
        
        // Add subviews to container
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        
        // Set up constraints for the container
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 19),
            iconImageView.heightAnchor.constraint(equalToConstant: 19),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // Add container to button
        button.addSubview(containerView)
        
        // Center the container in the button
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        // Add tap action
        button.addTarget(self, action: #selector(googleButtonTapped), for: .touchUpInside)
        
        return button
    }()
    
    private lazy var loadingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.isHidden = true
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }()
    
    // MARK: - Properties
    private var currentNonce: String?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAppleSignIn()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // set background color using CustomGradient.swift
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        // Add subviews
        view.addSubview(sloganLabel)
        view.addSubview(appleButton)
        view.addSubview(googleButton)
        view.addSubview(loadingView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Slogan constraints
            sloganLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sloganLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            sloganLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sloganLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Apple button constraints
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            appleButton.heightAnchor.constraint(equalToConstant: 50),
            appleButton.bottomAnchor.constraint(equalTo: googleButton.topAnchor, constant: -16),
            
            // Google button constraints
            googleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            googleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            googleButton.heightAnchor.constraint(equalToConstant: 50),
            googleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Loading view constraints
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add tap action for Apple button
        appleButton.addTarget(self, action: #selector(appleButtonTapped), for: .touchUpInside)
    }
    
    private func setupAppleSignIn() {
        // Configure Apple Sign In button
        let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        appleButton.addTarget(self, action: #selector(appleButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Helper Methods
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func showLoading() {
        loadingView.isHidden = false
        appleButton.isEnabled = false
        googleButton.isEnabled = false
    }
    
    private func hideLoading() {
        loadingView.isHidden = true
        appleButton.isEnabled = true
        googleButton.isEnabled = true
    }
    
    private func checkExistingUserAndNavigate() {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("No user is signed in")
            hideLoading()
            return
        }
        
        // Check if user already exists in Firestore
        UserManager.shared.getUser(id: firebaseUser.uid) { [weak self] user, error in
            guard let self = self else { return }
            
            self.hideLoading()
            
            if let error = error {
                print("Error checking user: \(error.localizedDescription)")
                return
            }
            
            if let existingUser = user {
                // User already exists, navigate to home screen
                print("User already exists, navigating to home screen")
                let homeViewController = HomeViewController()
                let navigationController = UINavigationController(rootViewController: homeViewController)
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true)
            } else {
                // User doesn't exist, navigate to name registration
                print("New user, navigating to name registration")
                let nameRegistrationVC = NameRegistrationViewController()
                nameRegistrationVC.modalPresentationStyle = .fullScreen
                self.present(nameRegistrationVC, animated: true)
            }
        }
    }
    
    // MARK: - Actions
    @objc private func googleButtonTapped() {
        showLoading()
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            hideLoading()
            return
        }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Google Sign In error: \(error.localizedDescription)")
                self.hideLoading()
                return
            }
            
            guard let authentication = result?.user,
                  let idToken = authentication.idToken?.tokenString else {
                print("Failed to get Google credentials")
                self.hideLoading()
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: authentication.accessToken.tokenString
            )
            
            // Sign in to Firebase with Google credential
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase Sign In error: \(error.localizedDescription)")
                    self.hideLoading()
                    return
                }
                
                // Successfully signed in
                print("Successfully signed in with Google")
                
                // Check if user exists and navigate accordingly
                self.checkExistingUserAndNavigate()
            }
        }
    }
    
    @objc private func appleButtonTapped() {
        showLoading()
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension ViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                hideLoading()
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                hideLoading()
                return
            }
            
            // Initialize a Firebase credential
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            // Sign in with Firebase
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase Sign In error: \(error.localizedDescription)")
                    self.hideLoading()
                    return
                }
                
                // Successfully signed in
                print("Successfully signed in with Apple")
                
                // Check if user exists and navigate accordingly
                self.checkExistingUserAndNavigate()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In error: \(error.localizedDescription)")
        hideLoading()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension ViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
} 
