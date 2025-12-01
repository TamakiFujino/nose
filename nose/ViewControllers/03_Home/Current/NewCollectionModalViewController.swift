import UIKit
import FirebaseAuth
import FirebaseFirestore

protocol NewCollectionModalViewControllerDelegate: AnyObject {
    func newCollectionModalViewController(_ controller: NewCollectionModalViewController, didCreateCollection collectionId: String)
}

class NewCollectionModalViewController: UIViewController {
    // MARK: - Properties
    weak var delegate: NewCollectionModalViewControllerDelegate?
    private var selectedIconUrl: String? = nil
    private var collectionName: String = ""
    private var containerViewCenterYConstraint: NSLayoutConstraint?
    
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "New Collection"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .fourthColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconSelectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Select an icon"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var iconButton: UIButton = {
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
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter a name"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var nameTextField: UITextField = {
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
    
    private lazy var cancelButton: UIButton = {
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
    
    private lazy var saveButton: UIButton = {
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismissal()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeKeyboardObservers()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(iconSelectionLabel)
        containerView.addSubview(iconButton)
        containerView.addSubview(nameLabel)
        containerView.addSubview(nameTextField)
        containerView.addSubview(cancelButton)
        containerView.addSubview(saveButton)
        
        // Store centerY constraint for keyboard adjustments
        let centerYConstraint = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        containerViewCenterYConstraint = centerYConstraint
        
        NSLayoutConstraint.activate([
            // Container view - centered in screen
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYConstraint,
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
    
    private func setupKeyboardDismissal() {
        // Tap outside container to dismiss modal
        let backgroundTapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundTapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(backgroundTapGesture)
        
        // Tap inside container to dismiss keyboard only
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        containerTapGesture.cancelsTouchesInView = false
        containerView.addGestureRecognizer(containerTapGesture)
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !containerView.frame.contains(location) {
            dismiss(animated: true)
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
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
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let safeAreaBottom = view.safeAreaInsets.bottom
        
        // Calculate the bottom of the text field in the view's coordinate system
        let textFieldFrame = nameTextField.convert(nameTextField.bounds, to: view)
        let textFieldBottom = textFieldFrame.maxY
        
        // Calculate available space above keyboard
        let availableSpace = view.bounds.height - keyboardHeight - safeAreaBottom
        
        // Calculate how much we need to move up
        let offset = max(0, textFieldBottom - availableSpace + 20) // 20pt padding
        
        // Update constraint with animation
        containerViewCenterYConstraint?.constant = -offset
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: UIView.AnimationOptions(rawValue: animationCurve)) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        // Reset constraint to original position
        containerViewCenterYConstraint?.constant = 0
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: UIView.AnimationOptions(rawValue: animationCurve)) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    @objc private func iconButtonTapped() {
        showImagePicker()
    }
    
    @objc private func nameTextFieldChanged() {
        collectionName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateSaveButtonState()
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        guard !collectionName.isEmpty else { return }
        
        // Create new collection in Firestore
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let collectionId = UUID().uuidString
        
        var collectionData: [String: Any] = [
            "id": collectionId,
            "name": collectionName,
            "places": [],
            "userId": currentUserId,
            "createdAt": Timestamp(date: Date()),
            "isOwner": true,
            "status": PlaceCollection.Status.active.rawValue,
            "members": [currentUserId]
        ]
        
        // Add icon if selected
        if let iconUrl = selectedIconUrl {
            collectionData["iconUrl"] = iconUrl
        }
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionId)
        
        // Show loading indicator
        saveButton.isEnabled = false
        let originalTitle = saveButton.title(for: .normal)
        saveButton.setTitle("Saving...", for: .normal)
        
        collectionRef.setData(collectionData) { [weak self] error in
            DispatchQueue.main.async {
                self?.saveButton.isEnabled = true
                self?.saveButton.setTitle(originalTitle, for: .normal)
                
                if let error = error {
                    print("❌ Error creating collection: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Error", message: "Failed to create collection. Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    return
                }
                
                print("✅ Successfully created collection: \(self?.collectionName ?? "")")
                self?.delegate?.newCollectionModalViewController(self!, didCreateCollection: collectionId)
                self?.dismiss(animated: true)
            }
        }
    }
    
    private func updateSaveButtonState() {
        let isValid = !collectionName.isEmpty
        saveButton.isEnabled = isValid
        saveButton.backgroundColor = isValid ? .fourthColor : .systemGray4
    }
    
    private func showImagePicker() {
        let imagePickerVC = ImagePickerViewController()
        imagePickerVC.delegate = self
        imagePickerVC.modalPresentationStyle = .fullScreen
        present(imagePickerVC, animated: true)
    }
    
    private func updateIconButton(with urlString: String) {
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
    }
}
 
// MARK: - ImagePickerViewControllerDelegate
extension NewCollectionModalViewController: ImagePickerViewControllerDelegate {
    func imagePickerViewController(_ controller: ImagePickerViewController, didSelectImage imageName: String, imageUrl: String) {
        selectedIconUrl = imageUrl
        updateIconButton(with: imageUrl)
    }
}

