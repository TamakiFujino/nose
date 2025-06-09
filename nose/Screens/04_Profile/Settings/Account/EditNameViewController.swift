import UIKit
import FirebaseAuth
import FirebaseFirestore

class EditNameViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let minNameLength = 2
        static let maxNameLength = 30
    }
    
    // MARK: - Properties
    private var currentName: String?
    
    // MARK: - UI Components
    private lazy var nameTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter your name"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .words
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
    
    private lazy var saveButton: UIButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Save", for: .normal)
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentName()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .firstColor
        
        title = "Edit Name"
        
        view.addSubview(nameTextField)
        view.addSubview(characterCountLabel)
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            characterCountLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 4),
            characterCountLabel.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            
            saveButton.topAnchor.constraint(equalTo: characterCountLabel.bottomAnchor, constant: 24),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func loadCurrentName() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error loading user data: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("No document found for current user")
                return
            }
            
            if let user = User.fromFirestore(snapshot) {
                DispatchQueue.main.async {
                    self?.currentName = user.name
                    self?.nameTextField.text = user.name
                }
            }
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
    
    @objc private func saveButtonTapped() {
        guard let newName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newName.isEmpty else {
            showAlert(title: "Invalid Name", message: "Please enter a valid name")
            return
        }
        
        // Validate name length
        if newName.count < Constants.minNameLength {
            showAlert(title: "Invalid Name", message: "Name must be at least \(Constants.minNameLength) characters long")
            return
        }
        
        if newName.count > Constants.maxNameLength {
            showAlert(title: "Invalid Name", message: "Name must be no more than \(Constants.maxNameLength) characters long")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Update name in Firestore
        db.collection("users").document(currentUserId).updateData([
            "name": newName
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error updating name: \(error.localizedDescription)")
                    self.showAlert(title: "Error", message: "Failed to update name. Please try again.")
                    return
                }
                
                // Only navigate back after successful save
                self.showAlert(title: "Success", message: "Name updated successfully") { _ in
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: completion))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension EditNameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
} 
