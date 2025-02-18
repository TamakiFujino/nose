import UIKit
import FirebaseAuth
import FirebaseFirestore

class NameUpdateViewController: UIViewController {
    
    let headerLabel = UILabel()
    let nameTextField = UITextField()
    let myButton = CustomButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)

        // Set up UI
        setupHeaderLabel()
        setupNameTextField()
        setupSubmitButton()
        
        // Layout
        setupConstraints()
        
        // Load the saved name if available
        loadSavedName()
    }
    
    // MARK: - UI set up
    private func setupHeaderLabel() {
        headerLabel.text = "名前"
        headerLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headerLabel.textColor = .sixthColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
    }
    
    private func setupNameTextField() {
        nameTextField.placeholder = "Enter your name"
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.isUserInteractionEnabled = true
        nameTextField.delegate = self
        nameTextField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        view.addSubview(nameTextField)
    }
    
    private func setupSubmitButton() {
        myButton.setTitle("Submit", for: .normal)
        myButton.translatesAutoresizingMaskIntoConstraints = false
        myButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        myButton.addTarget(self, action: #selector(saveName), for: .touchUpInside)
        myButton.isUserInteractionEnabled = true
        view.addSubview(myButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header label constraints
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Name text field constraints
            nameTextField.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameTextField.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            
            // Submit button constraints
            myButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            myButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            myButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Update user name
    // Load the saved name from Firestore if available
    private func loadSavedName() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { (document, error) in
            if let document = document, document.exists {
                self.nameTextField.text = document.data()?["displayName"] as? String
            }
        }
    }
    
    // MARK: - Save & Update name
    // When myButton is pressed, save the name input and stay in the screen
    @objc func saveName() {
        print("save button tapped")
        
        guard let name = nameTextField.text, !name.isEmpty else {
            print("Name is empty")
            return
        }
        
        // Save name to Firestore
        saveNameToFirestore(name: name) { success in
            if success {
                // Show flash message if updating the name
                self.showFlashMessage("Name updated successfully!")
            } else {
                self.showFlashMessage("Failed to save name. Please try again.")
            }
        }
    }
    
    private func saveNameToFirestore(name: String, completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData(["displayName": name]) { error in
            if let error = error {
                print("Error updating name in Firestore: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Name updated successfully in Firestore")
                completion(true)
            }
        }
    }
    
    private func showFlashMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)
        
        // Duration in seconds
        let duration: Double = 1.5
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            alert.dismiss(animated: true, completion: nil)
        }
    }
}

extension NameUpdateViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // Dismiss keyboard when return key is pressed
        return true
    }
}
