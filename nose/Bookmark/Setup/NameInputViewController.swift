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

        // Set up UI)
        headerLabel.text = "名前"
        headerLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headerLabel.textColor = .white
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        nameTextField.placeholder = "Enter your name"
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.isUserInteractionEnabled = true
        nameTextField.delegate = self
        nameTextField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        view.addSubview(nameTextField)
        
        myButton.setTitle("Submit", for: .normal)
        // set frame at the button of screen and also 80% width of screen
        myButton.translatesAutoresizingMaskIntoConstraints = false
        myButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        myButton.addTarget(self, action: #selector(saveName), for: .touchUpInside)
        myButton.isUserInteractionEnabled = true
        view.addSubview(myButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // set left-aligned
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // set name text field after the header label
            nameTextField.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameTextField.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            
            // set the button at the bottom of the screen
            myButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            myButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            myButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // when myButton is pressed, save the name input and move to HomeViewController
    @objc func saveName() {
        guard let name = nameTextField.text, !name.isEmpty else {
            print("Name is empty")
            return
        }
        
        // Save name to UserDefaults
        UserDefaults.standard.set(name, forKey: "name")
        
        // Move to HomeViewController
        let homeVC = HomeViewController()
        self.present(homeVC, animated: true)
    }
}

extension NameInputViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // Dismiss keyboard when return key is pressed
        return true
    }
}
