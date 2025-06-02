import UIKit
import FirebaseAuth
import FirebaseFirestore

class EditNameViewController: UIViewController {
    
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
        return textField
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
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            saveButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 24),
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
    @objc private func saveButtonTapped() {
        guard let newName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newName.isEmpty else {
            showAlert(title: "Invalid Name", message: "Please enter a valid name")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Update name in Firestore
        db.collection("users").document(currentUserId).updateData([
            "name": newName
        ]) { [weak self] error in
            if let error = error {
                print("Error updating name: \(error.localizedDescription)")
                self?.showAlert(title: "Error", message: "Failed to update name. Please try again.")
                return
            }
            
            DispatchQueue.main.async {
                self?.showAlert(title: "Success", message: "Name updated successfully") { _ in
                    self?.navigationController?.popViewController(animated: true)
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
