import UIKit
import RealityKit
import FirebaseFirestore
import FirebaseAuth

protocol AvatarCustomViewControllerDelegate: AnyObject {
    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData)
}

class AvatarCustomViewController: UIViewController {
    // MARK: - Properties
    private let collectionId: String
    private var currentAvatarData: CollectionAvatar.AvatarData?
    private var avatar3DViewController: Avatar3DViewController!
    private var customizationCoordinator: AvatarCustomizationCoordinator!
    private let isOwner: Bool

    weak var delegate: AvatarCustomViewControllerDelegate?

    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Customize Avatar"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    // MARK: - Initialization
    init(collectionId: String, isOwner: Bool) {
        self.collectionId = collectionId
        self.isOwner = isOwner
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        preloadResources()
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Customize Avatar"
        setupTitleLabel()
    }

    private func setupTitleLabel() {
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupAvatar3DView() {
        avatar3DViewController = Avatar3DViewController()
        avatar3DViewController.cameraPosition = SIMD3<Float>(0.0, 0.0, 14.0)
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)
        
        setupCustomizationCoordinator()
        
        if let partSelectorView = customizationCoordinator.partSelectorView {
            view.addSubview(partSelectorView)
            partSelectorView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                partSelectorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                partSelectorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                partSelectorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                partSelectorView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.47)
            ])
        }
        
        if let colorPickerView = customizationCoordinator.colorPickerView {
            view.addSubview(colorPickerView)
            colorPickerView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                colorPickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                colorPickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                colorPickerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                colorPickerView.heightAnchor.constraint(equalToConstant: 80)
            ])
        }
        
        if let avatarData = currentAvatarData {
            avatar3DViewController.loadAvatarData(avatarData)
        }
    }

    private func setupCustomizationCoordinator() {
        customizationCoordinator = AvatarCustomizationCoordinator(viewController: self, avatar3DViewController: avatar3DViewController)
    }

    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }

    // MARK: - Actions
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let rotationAngle = Float(translation.x / view.bounds.width) * .pi
        avatar3DViewController.baseEntity?.transform.rotation *= simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func saveButtonTapped() {
        saveAvatar()
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    // MARK: - Data Management
    private func createAvatarData() -> CollectionAvatar.AvatarData? {
        var selections: [String: [String: String]] = [:]
        
        // Add skin color if it exists
        if let skinColor = avatar3DViewController.chosenColors["skin"] {
            selections["skin"] = ["color": skinColor.toHexString()]
        }
        
        // Add other models and their colors
        for (category, modelName) in avatar3DViewController.chosenModels {
            var entry: [String: String] = ["model": modelName]
            
            if let color = avatar3DViewController.chosenColors[category] {
                entry["color"] = color.toHexString()
            }
            
            selections[category] = entry
        }
        
        // Create avatar data
        let avatarData = CollectionAvatar.AvatarData(
            selections: selections,
            customizations: [:],
            lastCustomizedAt: nil,
            customizationVersion: 1
        )
        
        return avatarData
    }

    private func saveAvatar() {
        guard let avatarData = createAvatarData(),
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: Failed to create avatar data or user not authenticated")
            return
        }
        
        // Determine the collection type based on ownership
        let collectionType = isOwner ? "owned" : "shared"
        
        // Create a new CollectionAvatar with current version
        let avatar = CollectionAvatar(
            collectionId: collectionId,
            avatarData: avatarData,
            createdAt: Date(),
            isOwner: isOwner,
            version: .current
        )
        
        // Save to Firestore in the user's collection
        let db = Firestore.firestore()
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionType)
            .collection(collectionType)
            .document(collectionId)
            .setData(avatar.toFirestoreData(), merge: true) { [weak self] error in
                if let error = error {
                    print("Error saving avatar: \(error.localizedDescription)")
                    return
                }
                
                // Notify delegate about the save
                self?.delegate?.avatarCustomViewController(self!, didSaveAvatar: avatarData)
                
                // Dismiss the view controller
                self?.dismiss(animated: true)
            }
    }

    private func loadSavedAvatarData() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user ID found")
            return
        }
        
        // Determine the collection type based on ownership
        let collectionType = isOwner ? "owned" : "shared"
        print("📂 Loading avatar data for collection type: \(collectionType)")
        
        let db = Firestore.firestore()
        let docRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionType)
            .collection(collectionType)
            .document(collectionId)
        
        print("🔍 Fetching document at path: \(docRef.path)")
        
        docRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading collection: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("ℹ️ No data found for collection")
                return
            }
            
            print("📄 Document data: \(data)")
            
            guard let avatarDict = data["avatarData"] as? [String: Any] else {
                print("❌ No avatar data found in document")
                return
            }
            
            guard let avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarDict, version: .v1) else {
                print("❌ Failed to parse avatar data from dictionary")
                return
            }
            
            print("✅ Successfully loaded avatar data: \(avatarData)")
            
            DispatchQueue.main.async {
                self?.currentAvatarData = avatarData
                self?.avatar3DViewController.loadAvatarData(avatarData)
            }
        }
    }

    // MARK: - Loading State
    private func showLoading() {
        LoadingView.shared.showOverlayLoading(on: view, message: "Loading Avatar...")
    }
    
    private func hideLoading() {
        LoadingView.shared.hideOverlayLoading()
    }

    // MARK: - Public Interface
    func setInitialAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        currentAvatarData = avatarData
    }

    private func preloadResources() {
        showLoading()
        view.isUserInteractionEnabled = false
        
        Task {
            do {
                print("🔄 Starting to preload resources...")
                try await AvatarResourceManager.shared.preloadAllResources()
                print("✅ Resources preloaded successfully")
                
                await MainActor.run {
                    self.setupNavigationBar()
                    self.setupAvatar3DView()
                    self.setupGestures()
                    
                    // Ensure 3D view is ready before loading avatar data
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.loadSavedAvatarData()
                        
                        // Hide loading after everything is set up
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.hideLoading()
                            self.view.isUserInteractionEnabled = true
                        }
                    }
                }
            } catch {
                print("❌ Error preloading resources: \(error)")
                await MainActor.run {
                    self.hideLoading()
                    self.view.isUserInteractionEnabled = true
                    // Show error alert
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to load avatar resources. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func setupNavigationBar() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .plain,
            target: self,
            action: #selector(saveButtonTapped)
        )
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        [navigationItem.rightBarButtonItem, navigationItem.leftBarButtonItem].forEach {
            $0?.tintColor = .black
        }
    }
}
