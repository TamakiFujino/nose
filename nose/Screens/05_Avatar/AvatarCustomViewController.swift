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
    private var avatarUIManager: AvatarUIManager!
    // var selectedBookmarkList: BookmarkList?

    weak var delegate: AvatarCustomViewControllerDelegate?

    // MARK: - UI Components
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

    private var loadingIndicator: UIActivityIndicatorView!

    // MARK: - Initialization
    init(collectionId: String) {
        self.collectionId = collectionId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLoadingIndicator()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        preloadResources()
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Customize Avatar"
        setupLoadingView()
    }

    private func setupLoadingView() {
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

    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .fourthColor
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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

    private func setupAvatar3DView() {
        showLoading()
        
        avatar3DViewController = Avatar3DViewController()
        avatar3DViewController.cameraPosition = SIMD3<Float>(0.0, 0.0, 14.0)
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)
        
        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)
        
        if let bottomSheetView = avatarUIManager.bottomSheetView {
            view.addSubview(bottomSheetView)
            bottomSheetView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bottomSheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bottomSheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bottomSheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                bottomSheetView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.47)
            ])
        }
        
        if let additionalBottomSheetView = avatarUIManager.additionalBottomSheetView {
            view.addSubview(additionalBottomSheetView)
            additionalBottomSheetView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                additionalBottomSheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                additionalBottomSheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                additionalBottomSheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                additionalBottomSheetView.heightAnchor.constraint(equalToConstant: 100)
            ])
        }
        
        if let avatarData = currentAvatarData {
            avatar3DViewController.loadAvatarData(avatarData)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hideLoading()
        }
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
        
        for (category, modelName) in avatar3DViewController.chosenModels {
            var entry: [String: String] = ["model": modelName]
            
            if let color = avatar3DViewController.chosenColors[category] {
                entry["color"] = color.toHexString()
            }
            
            selections[category] = entry
        }
        
        return CollectionAvatar.AvatarData(selections: selections)
    }

    private func saveAvatar() {
        guard let avatarData = createAvatarData(),
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: Failed to create avatar data or user not authenticated")
            return
        }
        
        // Save to Firestore in the user's collection
        let db = Firestore.firestore()
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionId)
            .setData(["avatarData": avatarData.toFirestoreDict()], merge: true) { [weak self] error in
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
                    self?.hideLoading()
                    return
                }
                
                if let data = snapshot?.data(),
                   let avatarDict = data["avatarData"] as? [String: Any],
                   let avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarDict) {
                    self?.currentAvatarData = avatarData
                    self?.avatar3DViewController.loadAvatarData(avatarData)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.hideLoading()
                }
            }
    }

    // MARK: - Loading State
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
                    self.hideLoading()
                    self.view.isUserInteractionEnabled = true
                    self.setupNavigationBar()
                    self.setupAvatar3DView()
                    self.setupGestures()
                    self.loadSavedAvatarData()
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
}
