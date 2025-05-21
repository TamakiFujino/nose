import UIKit
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

final class SplashViewController: UIViewController {
    
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Add subviews
        view.addSubview(sloganLabel)
        view.addSubview(appleButton)
        view.addSubview(googleButton)
        
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
            googleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    @objc private func googleButtonTapped() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Google Sign In error: \(error.localizedDescription)")
                return
            }
            
            guard let authentication = result?.user,
                  let idToken = authentication.idToken?.tokenString else {
                print("Failed to get Google credentials")
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
                    return
                }
                
                // Successfully signed in
                print("Successfully signed in with Google")
                
                // Navigate to name registration screen
                let nameRegistrationVC = NameRegistrationViewController()
                nameRegistrationVC.modalPresentationStyle = .fullScreen
                self.present(nameRegistrationVC, animated: true)
            }
        }
    }
} 
