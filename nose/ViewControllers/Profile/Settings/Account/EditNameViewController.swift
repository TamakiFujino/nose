import UIKit
import FirebaseAuth

final class EditNameViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let buttonHeight: CGFloat = 50
        static let minNameLength = 2
        static let maxNameLength = 30
    }
    
    // MARK: - Properties
    private var currentName: String?
    
    // MARK: - UI Components
    private lazy var nameTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = String(localized: "edit_name_placeholder")
        textField.borderStyle = .none
        textField.backgroundColor = .secondColor
        textField.layer.cornerRadius = 8
        textField.layer.masksToBounds = true
        textField.autocapitalizationType = .words
        textField.returnKeyType = .done
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        // Add padding for text
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always
        textField.accessibilityIdentifier = "name_text_field"
        return textField
    }()
    
    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.text = String(format: String(localized: "edit_name_char_count"), 0, Constants.maxNameLength)
        return label
    }()
    
    private lazy var saveButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(String(localized: "button_save"), for: .normal)
        button.style = .themeBlue
        button.size = .large
        button.isPerfectlyRounded = true
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
        title = String(localized: "edit_name_title")
        navigationController?.navigationBar.tintColor = .label
        navigationItem.largeTitleDisplayMode = .never
        
        setupSubviews()
        setupConstraints()
    }
    
    private func setupSubviews() {
        [nameTextField, characterCountLabel, saveButton].forEach {
            view.addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.standardPadding),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            nameTextField.heightAnchor.constraint(equalToConstant: 56),
            
            characterCountLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 4),
            characterCountLabel.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            
            saveButton.topAnchor.constraint(equalTo: characterCountLabel.bottomAnchor, constant: Constants.standardPadding),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            saveButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight)
        ])
    }
    
    // MARK: - Data Loading
    private func loadCurrentName() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        UserManager.shared.getUser(id: currentUserId) { [weak self] user, error in
            if let error = error {
                self?.showAlert(title: String(localized: "modal_error_title"), message: String(format: String(localized: "edit_name_failed_load"), error.localizedDescription))
                return
            }
            
            if let user = user {
                DispatchQueue.main.async {
                    self?.currentName = user.name
                    self?.nameTextField.text = user.name
                    self?.updateCharacterCount(for: user.name)
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateCharacterCount(for: textField.text)
    }
    
    private func updateCharacterCount(for text: String?) {
        let count = text?.count ?? 0
        characterCountLabel.text = String(format: String(localized: "edit_name_char_count"), count, Constants.maxNameLength)
        
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
            showAlert(title: String(localized: "edit_name_invalid_title"), message: String(localized: "edit_name_enter_valid"))
            return
        }
        
        // Validate name length
        if newName.count < Constants.minNameLength {
            showAlert(title: String(localized: "edit_name_invalid_title"), message: String(format: String(localized: "edit_name_min_length_format"), Constants.minNameLength))
            return
        }
        
        if newName.count > Constants.maxNameLength {
            showAlert(title: String(localized: "edit_name_invalid_title"), message: String(format: String(localized: "edit_name_max_length_format"), Constants.maxNameLength))
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        UserManager.shared.updateUserName(userId: currentUserId, newName: newName) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.showAlert(title: String(localized: "edit_name_success_title"), message: String(localized: "edit_name_success_message")) { _ in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showAlert(title: String(localized: "modal_error_title"), message: String(format: String(localized: "edit_name_failed_update_format"), error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let messageModal = MessageModalViewController(title: title, message: message)
        if let completion = completion {
            messageModal.onDismiss = {
                completion(UIAlertAction())
            }
        }
        present(messageModal, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension EditNameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
} 
