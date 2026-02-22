import UIKit
import FirebaseAuth
import FirebaseFirestore

final class NameRegistrationViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let minNameLength = 2
        static let maxNameLength = 30
        static let standardPadding: CGFloat = 20
        static let standardHeight: CGFloat = 50
        static let verticalSpacing: CGFloat = 32
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
        textField.accessibilityIdentifier = "name_text_field"
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
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        setupSubviews()
        setupConstraints()
    }
    
    private func setupSubviews() {
        [titleLabel, nameTextField, characterCountLabel, continueButton, activityIndicator].forEach {
            view.addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            
            nameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Constants.verticalSpacing),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            nameTextField.heightAnchor.constraint(equalToConstant: Constants.standardHeight),
            
            characterCountLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 4),
            characterCountLabel.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            
            continueButton.topAnchor.constraint(equalTo: characterCountLabel.bottomAnchor, constant: 24),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            continueButton.heightAnchor.constraint(equalToConstant: Constants.standardHeight),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange(_ textField: UITextField) {
        let count = textField.text?.count ?? 0
        characterCountLabel.text = "\(count)/\(Constants.maxNameLength)"
        characterCountLabel.textColor = count > Constants.maxNameLength ? .systemRed :
                                      count < Constants.minNameLength ? .systemOrange : .gray
    }
    
    @objc private func continueButtonTapped() {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            showError(message: "Please enter your name")
            return
        }
        
        if name.count < Constants.minNameLength {
            showError(message: "Name must be at least \(Constants.minNameLength) characters long")
            return
        }
        
        if name.count > Constants.maxNameLength {
            showError(message: "Name must be no more than \(Constants.maxNameLength) characters long")
            return
        }
        
        guard let firebaseUser = Auth.auth().currentUser else {
            print("No user is signed in")
            showError(message: "Authentication error. Please try signing in again.")
            return
        }
        
        // Create user with current version
        let user = User(id: firebaseUser.uid, name: name)
        saveUser(user)
    }
    
    // MARK: - Helper Methods
    private func saveUser(_ user: User) {
        activityIndicator.startAnimating()
        continueButton.isEnabled = false
        
        UserManager.shared.saveUser(user) { [weak self] error in
            guard let self = self else { return }
            
            self.activityIndicator.stopAnimating()
            self.continueButton.isEnabled = true
            
            if let error = error {
                print("Error saving user data: \(error.localizedDescription)")
                self.showError(message: "Failed to save user data. Please try again.")
                return
            }
            
            print("Successfully saved user data")
            self.navigateToHomeScreen()
        }
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
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
