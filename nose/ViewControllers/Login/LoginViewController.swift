import UIKit
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import AuthenticationServices
import CryptoKit

final class LoginViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var launchLogoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "logo_dark")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var appNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "app_name")
        label.textAlignment = .center
        let font = UIFont(name: "Futura-Medium", size: 66) ?? UIFont.systemFont(ofSize: 66, weight: .medium)
        label.font = font
        label.textColor = .white
        label.alpha = 0 // Initially invisible
        return label
    }()
    
    private lazy var appleButton: CustomGlassButton = {
        let button = CustomGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        setupSocialButton(button: button, iconName: "applelogo", title: String(localized: "apple_login"))
        button.addTarget(self, action: #selector(appleButtonTapped), for: .touchUpInside)
        button.alpha = 0 // Initially invisible
        button.accessibilityIdentifier = "continue_with_apple"
        button.accessibilityLabel = String(localized: "apple_login")
        return button
    }()
    
    private lazy var googleButton: CustomGlassButton = {
        let button = CustomGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        setupSocialButton(button: button, iconName: "google_logo", title: String(localized: "google_login"))
        button.addTarget(self, action: #selector(googleButtonTapped), for: .touchUpInside)
        button.alpha = 0 // Initially invisible
        button.accessibilityIdentifier = "continue_with_google"
        button.accessibilityLabel = String(localized: "google_login")
        return button
    }()
    
    private lazy var termsAndPrivacyTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.alpha = 0 // Initially invisible
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.white,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let base = String(localized: "login_terms_base")
        let terms = String(localized: "login_terms_of_service")
        let and = String(localized: "login_terms_and")
        let privacy = String(localized: "login_privacy_policy")
        let end = String(localized: "login_terms_end")
        let full = base + terms + and + privacy + end
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributed = NSMutableAttributedString(
            string: full,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )
        let termsRange = (full as NSString).range(of: terms)
        let privacyRange = (full as NSString).range(of: privacy)
        attributed.addAttribute(.link, value: "nose://terms", range: termsRange)
        attributed.addAttribute(.link, value: "nose://privacy", range: privacyRange)
        textView.attributedText = attributed
        return textView
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
    private var loginGradientLayer: CAGradientLayer?
    weak var sceneDelegate: SceneDelegate?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLaunchStyle()
        checkLoginState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isLoginMode {
            loginGradientLayer?.frame = view.bounds
        }
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
        // Switch to login style (gradient background + logo above slogan)
        isLoginMode = true
        
        launchLogoImageView.removeFromSuperview()
        view.backgroundColor = .themeLightBlue
        
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.themeLightBlue.cgColor, UIColor.themeBlue.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
        loginGradientLayer = gradient

        let bottomStack = UIStackView(arrangedSubviews: [termsAndPrivacyTextView, appleButton, googleButton])
        bottomStack.axis = .vertical
        bottomStack.alignment = .center
        bottomStack.spacing = 8
        bottomStack.setCustomSpacing(16, after: termsAndPrivacyTextView)
        bottomStack.translatesAutoresizingMaskIntoConstraints = false

        launchLogoImageView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        launchLogoImageView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        view.addSubview(launchLogoImageView)
        view.addSubview(appNameLabel)
        view.addSubview(bottomStack)
        view.addSubview(loadingView)

        appNameLabel.font = UIFont(name: "Futura-Medium", size: 66) ?? UIFont.systemFont(ofSize: 66, weight: .medium)
        appNameLabel.adjustsFontSizeToFitWidth = false

        appleButton.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true
        appleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        googleButton.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true
        googleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        launchLogoImageView.alpha = 0

        NSLayoutConstraint.activate([
            launchLogoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            launchLogoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            appNameLabel.leadingAnchor.constraint(equalTo: launchLogoImageView.trailingAnchor, constant: -8),
            appNameLabel.centerYAnchor.constraint(equalTo: launchLogoImageView.centerYAnchor, constant: -8),
            termsAndPrivacyTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            termsAndPrivacyTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        UIView.animate(withDuration: 0.5) {
            self.launchLogoImageView.alpha = 1
            self.appNameLabel.alpha = 1
            self.termsAndPrivacyTextView.alpha = 1
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
                    guard let self = self else { return }
                    if user != nil {
                        // User exists, replace root with home screen
                        self.transitionToHome()
                    } else {
                        // User doesn't have a profile yet, show login UI
                        self.setupLoginStyle()
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
            Logger.log("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)", level: .error, category: "Login")
            return ""
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
            Logger.log("No user is signed in", level: .debug, category: "Login")
            hideLoading()
            return
        }
        
        UserManager.shared.getUser(id: firebaseUser.uid) { [weak self] user, error in
            guard let self = self else { return }
            self.hideLoading()
            
            if let error = error {
                Logger.log("Error checking user: \(error.localizedDescription)", level: .error, category: "Login")
                self.showError(message: String(localized: "login_error_check_user"))
                return
            }
            
            if user != nil {
                Logger.log("User already exists, navigating to home screen", level: .debug, category: "Login")
                self.transitionToHome()
            } else {
                Logger.log("New user, navigating to name registration", level: .debug, category: "Login")
                let nameRegistrationVC = NameRegistrationViewController()
                nameRegistrationVC.modalPresentationStyle = .fullScreen
                self.present(nameRegistrationVC, animated: true)
            }
        }
    }
    
    private func transitionToHome() {
        guard let window = view.window else { return }
        let homeViewController = HomeViewController()
        let navigationController = UINavigationController(rootViewController: homeViewController)
        
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = navigationController
        } completion: { _ in
            self.sceneDelegate?.didFinishAuthentication()
        }
    }
    
    private func showError(message: String) {
        let messageModal = MessageModalViewController(title: String(localized: "modal_error_title"), message: message)
        present(messageModal, animated: true)
    }
    
    // MARK: - Actions
    @objc private func googleButtonTapped() {
        showLoading()
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            hideLoading()
            showError(message: String(localized: "login_error_google_config"))
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Google Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
                self.hideLoading()
                // Check if user cancelled
                if let gidError = error as NSError?,
                   gidError.domain == "com.google.GIDSignIn",
                   gidError.code == -5 { // GIDSignInErrorCode.canceled
                    // User cancelled - don't show error
                    return
                }
                self.showError(message: String(format: String(localized: "login_error_google_signin_format"), error.localizedDescription))
                return
            }
            
            guard let authentication = result?.user,
                  let idToken = authentication.idToken?.tokenString else {
                Logger.log("Failed to get Google credentials", level: .error, category: "Login")
                self.hideLoading()
                self.showError(message: String(localized: "login_error_google_credentials"))
                return
            }
            
            // accessToken is non-optional GIDToken, so we can access it directly
            let accessTokenString = authentication.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessTokenString
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Firebase Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
                    self.hideLoading()
                    self.showError(message: String(format: String(localized: "login_error_firebase_auth_format"), error.localizedDescription))
                    return
                }
                
                Logger.log("Successfully signed in with Google", level: .info, category: "Login")
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
extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                Logger.log("Invalid state: A login callback was received, but no login request was sent.", level: .error, category: "Login")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                Logger.log("Unable to fetch identity token", level: .debug, category: "Login")
                hideLoading()
                return
            }
            
            let credential = OAuthProvider.credential(
                providerID: .apple,
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Firebase Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
                    self.hideLoading()
                    return
                }
                
                Logger.log("Successfully signed in with Apple", level: .info, category: "Login")
                self.checkExistingUserAndNavigate()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.log("Apple Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
        hideLoading()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: - UITextViewDelegate
extension LoginViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "nose" {
            if URL.host == "terms" {
                let termsVC = ToSViewController()
                termsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPresentedPolicyOrTerms))
                let nav = UINavigationController(rootViewController: termsVC)
                present(nav, animated: true)
            } else if URL.host == "privacy" {
                let privacyVC = PrivacyPolicyViewController()
                privacyVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPresentedPolicyOrTerms))
                let nav = UINavigationController(rootViewController: privacyVC)
                present(nav, animated: true)
            }
            return false
        }
        return true
    }
    
    @objc private func dismissPresentedPolicyOrTerms() {
        presentedViewController?.dismiss(animated: true)
    }
} 
