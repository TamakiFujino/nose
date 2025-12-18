import UIKit
import FirebaseAuth
import FirebaseFirestore

/// Base class for collection modal view controllers (create/edit)
class CollectionModalViewController: UIViewController {
    // MARK: - Properties
    var selectedIconUrl: String?
    var selectedIconName: String?
    var collectionName: String = ""
    
    // MARK: - UI Components (protected for subclass access)
    let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .fourthColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let iconSelectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Select an icon"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var iconButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemGray5
        button.layer.cornerRadius = 50 // Circular button (100x100 / 2)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .systemGray2
        button.imageView?.contentMode = .scaleAspectFit
        // Make the plus icon larger
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        button.setPreferredSymbolConfiguration(config, forImageIn: .normal)
        button.addTarget(self, action: #selector(iconButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter a name"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Collection Name"
        textField.font = .systemFont(ofSize: 16)
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.systemGray5 // Match icon button color
        textField.layer.cornerRadius = 8
        textField.autocapitalizationType = .words
        textField.addTarget(self, action: #selector(nameTextFieldChanged), for: .editingChanged)
        // Add padding for text
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemGray, for: .normal)
        button.backgroundColor = UIColor.systemGray5
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGray4 // Start disabled
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Configuration
    /// Whether to allow background tap to dismiss. Default is false.
    var allowsBackgroundDismiss: Bool = false
    
    // MARK: - Keyboard Handling
    private var containerViewCenterYConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismissal()
        setupKeyboardObservers()
        configureInitialState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(iconSelectionLabel)
        containerView.addSubview(iconButton)
        containerView.addSubview(nameLabel)
        containerView.addSubview(nameTextField)
        containerView.addSubview(cancelButton)
        containerView.addSubview(saveButton)
        
        // Store centerY constraint for keyboard adjustment
        containerViewCenterYConstraint = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        
        NSLayoutConstraint.activate([
            // Container view - centered in screen
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerViewCenterYConstraint!,
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Icon selection label
            iconSelectionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            iconSelectionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Icon button
            iconButton.topAnchor.constraint(equalTo: iconSelectionLabel.bottomAnchor, constant: 16),
            iconButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconButton.widthAnchor.constraint(equalToConstant: 100),
            iconButton.heightAnchor.constraint(equalToConstant: 100),
            
            // Name label
            nameLabel.topAnchor.constraint(equalTo: iconButton.bottomAnchor, constant: 32),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            
            // Name text field
            nameTextField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            nameTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 32),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: -8),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Save button
            saveButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: 8),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    func setupKeyboardDismissal() {
        // Tap inside container to dismiss keyboard
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        containerTapGesture.cancelsTouchesInView = false
        containerView.addGestureRecognizer(containerTapGesture)
        
        // Background tap to dismiss (if enabled)
        if allowsBackgroundDismiss {
            let backgroundTapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
            backgroundTapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(backgroundTapGesture)
        }
    }
    
    func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        let keyboardHeight = keyboardFrame.cgRectValue.height
        let textFieldFrame = nameTextField.convert(nameTextField.bounds, to: view)
        let textFieldBottom = textFieldFrame.maxY
        let visibleAreaBottom = view.bounds.height - keyboardHeight
        let offset = textFieldBottom - visibleAreaBottom + 20 // 20pt padding
        
        if offset > 0 {
            // Move container up to keep text field visible
            containerViewCenterYConstraint?.constant = -offset
            
            UIView.animate(withDuration: animationDuration, delay: 0, options: UIView.AnimationOptions(rawValue: animationCurve)) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        // Reset container position
        containerViewCenterYConstraint?.constant = 0
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: UIView.AnimationOptions(rawValue: animationCurve)) {
            self.view.layoutIfNeeded()
        }
    }
    
    /// Override this method to configure initial state (e.g., load existing data)
    func configureInitialState() {
        // Subclasses should override
    }
    
    // MARK: - Actions
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !containerView.frame.contains(location) {
            dismiss(animated: true)
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func iconButtonTapped() {
        showImagePicker()
    }
    
    @objc func nameTextFieldChanged() {
        collectionName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateSaveButtonState()
    }
    
    @objc func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc func saveButtonTapped() {
        // Subclasses should override
        fatalError("Subclasses must override saveButtonTapped()")
    }
    
    // MARK: - Helper Methods
    func updateSaveButtonState() {
        let isValid = !collectionName.isEmpty
        saveButton.isEnabled = isValid
        saveButton.backgroundColor = isValid ? .fourthColor : .systemGray4
    }
    
    func showImagePicker() {
        let imagePickerVC = ImagePickerViewController()
        imagePickerVC.delegate = self
        imagePickerVC.modalPresentationStyle = .fullScreen
        present(imagePickerVC, animated: true)
    }
    
    func updateIconButton(with urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Use cached image if available for smoother UX
        if let cachedImage = ImagePickerCell.imageCache.object(forKey: urlString as NSString) {
            iconButton.setImage(cachedImage.withRenderingMode(.alwaysOriginal), for: .normal)
        } else {
            iconButton.setImage(UIImage(systemName: "photo"), for: .normal)
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data,
                      let image = UIImage(data: data) else { return }
                ImagePickerCell.imageCache.setObject(image, forKey: urlString as NSString)
                DispatchQueue.main.async {
                    self?.iconButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
                }
            }.resume()
        }
        
        iconButton.backgroundColor = .clear
        iconButton.tintColor = .clear
        iconButton.imageView?.contentMode = .scaleAspectFill
        iconButton.clipsToBounds = true
        iconButton.layer.cornerRadius = 50
    }
    
    func resetIconButton() {
        iconButton.setImage(UIImage(systemName: "plus"), for: .normal)
        iconButton.tintColor = .systemGray2
        iconButton.backgroundColor = UIColor.systemGray5
    }
}

// MARK: - ImagePickerViewControllerDelegate
extension CollectionModalViewController: ImagePickerViewControllerDelegate {
    func imagePickerViewController(_ controller: ImagePickerViewController, didSelectImage imageName: String, imageUrl: String) {
        selectedIconUrl = imageUrl.isEmpty ? nil : imageUrl
        selectedIconName = imageName.isEmpty ? nil : imageName
        
        if let iconUrl = selectedIconUrl, !iconUrl.isEmpty {
            updateIconButton(with: iconUrl)
        } else {
            resetIconButton()
        }
    }
}
