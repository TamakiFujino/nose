import UIKit
import RealityKit
import FirebaseFirestore
import FirebaseAuth

protocol AvatarCustomViewControllerDelegate: AnyObject {
    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData)
}

class AvatarCustomViewController: UIViewController {

    var avatar3DViewController: Avatar3DViewController!
    var avatarUIManager: AvatarUIManager!
    // var selectedBookmarkList: BookmarkList?

    weak var delegate: AvatarCustomViewControllerDelegate?
    private var currentAvatarData: CollectionAvatar.AvatarData?
    private let collectionId: String
    
    private lazy var loadingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.alpha = 0
        return view
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .fourthColor
        return indicator
    }()
    
    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Loading Avatar..."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .fourthColor
        label.textAlignment = .center
        return label
    }()

    init(collectionId: String) {
        self.collectionId = collectionId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupAvatar3DView()
        setupGestures()
        loadSavedAvatarData()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Customize Avatar"
        
        // Add loading view
        view.addSubview(loadingView)
        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(loadingLabel)
        
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
            
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor)
        ])
    }

    private func setupNavigationBar() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // Add save button
        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveButtonTapped))
        saveButton.tintColor = .black
        navigationItem.rightBarButtonItem = saveButton
        
        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .black
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setupAvatar3DView() {
        showLoading()
        
        avatar3DViewController = Avatar3DViewController()
        avatar3DViewController.cameraPosition = SIMD3<Float>(0.0, 0.0, 14.0)
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)
        
        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)
        
        // Load existing avatar data if available
        if let avatarData = currentAvatarData {
            avatar3DViewController.loadAvatarData(avatarData)
        }
        
        // Hide loading after a short delay to ensure everything is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hideLoading()
        }
    }

    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let rotationAngle = Float(translation.x / view.bounds.width) * .pi
        
        avatar3DViewController.baseEntity?.transform.rotation *= simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func saveButtonTapped() {
        let didSave = avatar3DViewController.saveChosenModelsAndColors()
        
        // Build selections dictionary
        var selections: [String: [String: String]] = [:]
        for (category, modelName) in avatar3DViewController.chosenModels {
            var entry: [String: String] = ["model": modelName]
            if let color = avatar3DViewController.chosenColors[category] {
                // Convert UIColor to hex string
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                let hexString = String(format: "#%02X%02X%02X",
                                     Int(red * 255),
                                     Int(green * 255),
                                     Int(blue * 255))
                entry["color"] = hexString
                print("Saving color for \(category): \(hexString)")
            }
            selections[category] = entry
        }
        let avatarData = CollectionAvatar.AvatarData(selections: selections)
        
        // Save to Firestore
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        let avatarDict = avatarData.toFirestoreDict()
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionId)
            .setData(["avatarData": avatarDict], merge: true) { error in
                if let error = error {
                    print("Error saving avatar data: \(error.localizedDescription)")
                    ToastManager.showToast(message: "Failed to save avatar", type: .error)
                } else {
                    print("Successfully saved avatar data: \(avatarDict)")
                    ToastManager.showToast(message: ToastMessages.avatarUpdated, type: .success)
                }
            }
        
        // Notify delegate
        delegate?.avatarCustomViewController(self, didSaveAvatar: avatarData)
        
        // Pop view controller
        navigationController?.popViewController(animated: true)
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    func setInitialAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        currentAvatarData = avatarData
    }

    private func showLoading() {
        loadingView.alpha = 1
        activityIndicator.startAnimating()
    }
    
    private func hideLoading() {
        UIView.animate(withDuration: 0.3) {
            self.loadingView.alpha = 0
        } completion: { _ in
            self.activityIndicator.stopAnimating()
        }
    }

    private func loadSavedAvatarData() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            hideLoading()
            return
        }
        
        showLoading()
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionId)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading avatar data: \(error.localizedDescription)")
                    self?.hideLoading()
                    return
                }
                
                if let data = snapshot?.data(),
                   let avatarDict = data["avatarData"] as? [String: Any],
                   let avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarDict) {
                    // Load the saved avatar data
                    self?.currentAvatarData = avatarData
                    self?.avatar3DViewController.loadAvatarData(avatarData)
                }
                
                // Hide loading after a short delay to ensure everything is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.hideLoading()
                }
            }
    }
}
