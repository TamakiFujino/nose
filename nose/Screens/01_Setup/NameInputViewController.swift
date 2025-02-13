import UIKit
import FirebaseAuth

class NameInputViewController: UIViewController {
    
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
    
    private func setupHeaderLabel() {
        headerLabel.text = "名前"
        headerLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headerLabel.textColor = .white
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
    
    // Load the saved name from UserDefaults if available
    private func loadSavedName() {
        if let savedName = UserDefaults.standard.string(forKey: "name") {
            nameTextField.text = savedName
        }
    }
    
    // When myButton is pressed, save the name input and either move to HomeViewController or show a flash message
    @objc func saveName() {
        print("save button tapped")
        
        guard let name = nameTextField.text, !name.isEmpty else {
            print("Name is empty")
            return
        }
        
        // Save name to UserDefaults
        UserDefaults.standard.set(name, forKey: "name")
        
        if UserDefaults.standard.string(forKey: "name") != nil {
            // Show flash message if a name was already saved
            showFlashMessage("Name updated successfully!")
        } else {
            // Move to HomeViewController if no name was saved previously
            let homeVC = HomeViewController()
            if let navController = navigationController {
                navController.pushViewController(homeVC, animated: true)  // Use navigation if available
            } else {
                present(homeVC, animated: true)  // Otherwise, present modally
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

extension NameInputViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // Dismiss keyboard when return key is pressed
        return true
    }
}
