import UIKit
import FirebaseAuth
import FirebaseFirestore

final class NameRegistrationViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let minNameLength = 2
        static let maxNameLength = 30
    }
    
    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "What should we call you?"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .black
        return label
    }()
    
    private lazy var nameTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter your name"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return textField
    }()
    
    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.text = "0/\(Constants.maxNameLength)"
        return label
    }()
    
    private lazy var continueButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Continue", for: .normal)
        button.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkExistingUser()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(nameTextField)
        view.addSubview(characterCountLabel)
        view.addSubview(continueButton)
        view.addSubview(activityIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            
            // Text field constraints
            nameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Character count label constraints
            characterCountLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 4),
            characterCountLabel.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            
            // Continue button constraints
            continueButton.topAnchor.constraint(equalTo: characterCountLabel.bottomAnchor, constant: 24),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Activity indicator constraints
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - User Check
    private func checkExistingUser() {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("No user is signed in")
            return
        }
        
        // Show loading indicator
        activityIndicator.startAnimating()
        continueButton.isEnabled = false
        
        // Check if user already exists in Firestore
        UserManager.shared.getUser(id: firebaseUser.uid) { [weak self] user, error in
            guard let self = self else { return }
            
            // Hide loading indicator
            self.activityIndicator.stopAnimating()
            self.continueButton.isEnabled = true
            
            if let error = error {
                print("Error checking user: \(error.localizedDescription)")
                return
            }
            
            if let existingUser = user {
                // User already exists, navigate to home screen
                print("User already exists, skipping registration")
                self.navigateToHomeScreen()
            }
            // If user is nil, stay on this screen for registration
        }
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange(_ textField: UITextField) {
        let count = textField.text?.count ?? 0
        characterCountLabel.text = "\(count)/\(Constants.maxNameLength)"
        
        // Update label color based on character count
        if count > Constants.maxNameLength {
            characterCountLabel.textColor = .systemRed
        } else if count < Constants.minNameLength {
            characterCountLabel.textColor = .systemOrange
        } else {
            characterCountLabel.textColor = .gray
        }
    }
    
    @objc private func continueButtonTapped() {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            showError(message: "Please enter your name")
            return
        }
        
        // Validate name length
        if name.count < Constants.minNameLength {
            showError(message: "Name must be at least \(Constants.minNameLength) characters long")
            return
        }
        
        if name.count > Constants.maxNameLength {
            showError(message: "Name must be no more than \(Constants.maxNameLength) characters long")
            return
        }
        
        // Get current user
        guard let firebaseUser = Auth.auth().currentUser else {
            print("No user is signed in")
            return
        }
        
        // Create user object
        let user = User(
            id: firebaseUser.uid,
            name: name
        )
        
        // Show loading indicator
        activityIndicator.startAnimating()
        continueButton.isEnabled = false
        
        // Save user to Firestore
        UserManager.shared.saveUser(user) { [weak self] error in
            guard let self = self else { return }
            
            // Hide loading indicator
            self.activityIndicator.stopAnimating()
            self.continueButton.isEnabled = true
            
            if let error = error {
                print("Error saving user data: \(error.localizedDescription)")
                self.showError(message: "Failed to save user data. Please try again.")
                return
            }
            
            // Successfully saved user data
            print("Successfully saved user data")
            self.navigateToHomeScreen()
        }
    }
    
    // MARK: - Helper Methods
    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func navigateToHomeScreen() {
        let homeViewController = HomeViewController()
        let navigationController = UINavigationController(rootViewController: homeViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension NameRegistrationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        continueButtonTapped()
        return true
    }
}

