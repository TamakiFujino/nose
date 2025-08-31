import UIKit
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import AuthenticationServices
import CryptoKit
import FirebaseFirestore

final class ViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var launchLogoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var sloganLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Map your journey\nStyle your future"
        label.textAlignment = .center
        // set font to gotham
        let font = UIFont(name: "Gotham-Bold", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .bold)
        label.font = font
        label.textColor = .white
        label.numberOfLines = 0
        label.alpha = 0 // Initially invisible
        return label
    }()
    
    private lazy var appleButton: CustomGlassButton = {
        let button = CustomGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        setupSocialButton(button: button, iconName: "applelogo", title: "Continue with Apple")
        button.addTarget(self, action: #selector(appleButtonTapped), for: .touchUpInside)
        button.alpha = 0 // Initially invisible
        return button
    }()
    
    private lazy var googleButton: CustomGlassButton = {
        let button = CustomGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        setupSocialButton(button: button, iconName: "google_logo", title: "Continue with Google")
        button.addTarget(self, action: #selector(googleButtonTapped), for: .touchUpInside)
        button.alpha = 0 // Initially invisible
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
    private var isLoginMode = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLaunchStyle()
        checkLoginState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Setup
    private func setupLaunchStyle() {
        // Start with launch screen style (white background + logo)
        view.backgroundColor = .white
        view.addSubview(launchLogoImageView)
        
        // Setup launch logo constraints
        NSLayoutConstraint.activate([
            launchLogoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            launchLogoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            launchLogoImageView.widthAnchor.constraint(equalToConstant: 221), // Match LaunchScreen size
            launchLogoImageView.heightAnchor.constraint(equalToConstant: 348), // Match LaunchScreen size
        ])
    }
    
    private func setupLoginStyle() {
        // Switch to login style (splash background + login UI)
        isLoginMode = true
        
        // Remove launch logo
        launchLogoImageView.removeFromSuperview()
        
        // Setup splash background
        let backgroundImage = UIImageView(frame: UIScreen.main.bounds)
        backgroundImage.image = UIImage(named: "splash")
        
        if backgroundImage.image == nil {
            // Set a fallback background color
            view.backgroundColor = .systemBlue
        }
        
        backgroundImage.contentMode = .scaleAspectFill
        backgroundImage.clipsToBounds = true
        view.addSubview(backgroundImage)
        view.sendSubviewToBack(backgroundImage)
        
        // Add login UI elements
        [sloganLabel, appleButton, googleButton, loadingView].forEach {
            view.addSubview($0)
        }
        
        // Setup login UI constraints
        NSLayoutConstraint.activate([
            sloganLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sloganLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sloganLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sloganLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            appleButton.heightAnchor.constraint(equalToConstant: 50),
            appleButton.bottomAnchor.constraint(equalTo: googleButton.topAnchor, constant: -16),
            
            googleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            googleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            googleButton.heightAnchor.constraint(equalToConstant: 50),
            googleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Show login UI with animation
        UIView.animate(withDuration: 0.5) {
            self.sloganLabel.alpha = 1
            self.appleButton.alpha = 1
            self.googleButton.alpha = 1
        }
    }
    
    private func checkLoginState() {
        // Check if user is already logged in
        if let currentUser = Auth.auth().currentUser {
            // User is logged in, check if they have a profile
            UserManager.shared.getUser(id: currentUser.uid) { [weak self] user, error in
                DispatchQueue.main.async {
                    if user != nil {
                        // User exists, navigate to home screen
                        let homeViewController = HomeViewController()
                        let navigationController = UINavigationController(rootViewController: homeViewController)
                        navigationController.modalPresentationStyle = .fullScreen
                        self?.present(navigationController, animated: true)
                    } else {
                        // User doesn't have a profile yet, show login UI
                        self?.setupLoginStyle()
                    }
                }
            }
        } else {
            // No user logged in, show login UI after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.setupLoginStyle()
            }
        }
    }
    
    private func setupSocialButton(button: CustomGlassButton, iconName: String, title: String) {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        if iconName == "applelogo" {
            // Use SF Symbol for Apple logo
            iconImageView.image = UIImage(systemName: "apple.logo")?.withRenderingMode(.alwaysTemplate)
        } else {
            // Use asset catalog for other icons
            iconImageView.image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
        }
        iconImageView.tintColor = .firstColor
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .firstColor
        
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconName == "applelogo" ? 24 : 20),
            iconImageView.heightAnchor.constraint(equalToConstant: iconName == "applelogo" ? 24 : 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        button.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }
    
    // MARK: - Helper Methods
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func showLoading() {
        loadingView.isHidden = false
        [appleButton, googleButton].forEach { $0.isEnabled = false }
    }
    
    private func hideLoading() {
        loadingView.isHidden = true
        [appleButton, googleButton].forEach { $0.isEnabled = true }
    }
    
    private func checkExistingUserAndNavigate() {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("No user is signed in")
            hideLoading()
            return
        }
        
        UserManager.shared.getUser(id: firebaseUser.uid) { [weak self] user, error in
            guard let self = self else { return }
            self.hideLoading()
            
            if let error = error {
                print("Error checking user: \(error.localizedDescription)")
                self.showError(message: "Failed to check user status. Please try again.")
                return
            }
            
            if user != nil {
                print("User already exists, navigating to home screen")
                let homeViewController = HomeViewController()
                let navigationController = UINavigationController(rootViewController: homeViewController)
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true)
            } else {
                print("New user, navigating to name registration")
                let nameRegistrationVC = NameRegistrationViewController()
                nameRegistrationVC.modalPresentationStyle = .fullScreen
                self.present(nameRegistrationVC, animated: true)
            }
        }
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    @objc private func googleButtonTapped() {
        showLoading()
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            hideLoading()
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
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
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase Sign In error: \(error.localizedDescription)")
                    self.hideLoading()
                    return
                }
                
                print("Successfully signed in with Google")
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
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to fetch identity token")
                hideLoading()
                return
            }
            
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase Sign In error: \(error.localizedDescription)")
                    self.hideLoading()
                    return
                }
                
                print("Successfully signed in with Apple")
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
