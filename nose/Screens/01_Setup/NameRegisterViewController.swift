import UIKit
import FirebaseAuth
import FirebaseFirestore

class NameRegisterViewController: UIViewController {

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
        nameTextField.placeholder = "Enter your name that will be used in this app"
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

    // MARK: - Save & Update name
    // When myButton is pressed, save the name input and move to HomeViewController
    @objc func saveName() {
        print("save button tapped")

        guard let name = nameTextField.text, !name.isEmpty else {
            print("Name is empty")
            // Optionally, show a message to the user that name cannot be empty
            showFlashMessage("Please enter a name.")
            return
        }

        // Generate a unique 9-digit friend ID
        let friendId = generateUniqueFriendID()

        // Save name and friend ID to Firestore
        saveUserDataToFirestore(name: name, friendId: friendId) { success in
            if success {
                // Move to HomeViewController
                let homeVC = HomeViewController()
                // Ensure HomeViewController is embedded in a UINavigationController if not already
                // This typically happens if NameRegisterViewController is part of a navigation stack.
                if let navController = self.navigationController {
                    navController.pushViewController(homeVC, animated: true)
                } else {
                    // Fallback or error handling if not in a navigation controller
                    // For example, present it modally, or wrap it in a new navigation controller
                    print("Error: NameRegisterViewController is not embedded in a UINavigationController.")
                    // As a fallback, create a new navigation controller and set it as root or present it.
                    // This part depends on the app's overall navigation structure.
                    // For now, let's assume it should be pushed, and log an error if no nav controller.
                    // One common pattern is to transition to a new root view controller for the main app flow.
                    // Example: (UIApplication.shared.windows.first?.rootViewController as? UINavigationController)?.pushViewController(homeVC, animated: true)
                    // Or, if setting a new root:
                    // let navigationController = UINavigationController(rootViewController: homeVC)
                    // UIApplication.shared.windows.first?.rootViewController = navigationController
                    // UIApplication.shared.windows.first?.makeKeyAndVisible()
                    self.showFlashMessage("Navigation error. Could not proceed.")
                }
            } else {
                self.showFlashMessage("Failed to save your details. Please try again.")
            }
        }
    }

    private func generateUniqueFriendID() -> String {
        // Generate a random 9-digit number string
        // For true uniqueness, you might need to check against the database if this ID already exists,
        // but for simplicity, we'll assume a 9-digit random number is sufficiently unique for now.
        var randomNumber = ""
        for _ in 0..<9 {
            randomNumber += String(Int.random(in: 0...9))
        }
        return randomNumber
    }

    private func saveUserDataToFirestore(name: String, friendId: String, completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            showFlashMessage("Error: Not authenticated. Please sign in again.")
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "displayName": name,
            "friendId": friendId,
            // Add any other default fields you might want to set on user creation
            // "createdAt": FieldValue.serverTimestamp() // Example
        ]

        // Using setData with merge:true to create or update the document.
        // If you only want to update if it exists and fail if not, or have more specific write needs,
        // adjust accordingly (e.g., document().updateData() or document().setData() without merge for overwrite)
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("Error saving user data to Firestore: \(error.localizedDescription)")
                completion(false)
            } else {
                print("User data (name and friendId) saved successfully to Firestore")
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

extension NameRegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // Dismiss keyboard when return key is pressed
        return true
    }
}
