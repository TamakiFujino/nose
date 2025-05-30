import UIKit
import RealityKit
import FirebaseFirestore
import Firebase

protocol AvatarCustomViewControllerDelegate: AnyObject {
    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData)
}

class AvatarCustomViewController: UIViewController {

    var avatar3DViewController: Avatar3DViewController!
    var avatarUIManager: AvatarUIManager!
    // var selectedBookmarkList: BookmarkList?

    weak var delegate: AvatarCustomViewControllerDelegate?
    private var currentAvatarData: CollectionAvatar.AvatarData?
    private var collectionId: String?
    private var isProfileAvatar: Bool

    init(collectionId: String? = nil) {
        self.collectionId = collectionId
        self.isProfileAvatar = collectionId == nil
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
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Customize Avatar"
    }

    private func setupNavigationBar() {
        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveButtonTapped))
        saveButton.tintColor = .black
        navigationItem.rightBarButtonItem = saveButton
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }

    private func setupAvatar3DView() {
        avatar3DViewController = Avatar3DViewController()
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)
        
        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)
        
        // Load existing avatar data if available
        if let avatarData = currentAvatarData {
            print("DEBUG: Loading saved avatar data in setup: \(avatarData.selections)")
            avatar3DViewController.loadAvatarData(avatarData)
        } else {
            print("DEBUG: No saved avatar data to load")
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Build selections dictionary
        var selections: [String: [String: String]] = [:]
        for (category, modelName) in avatar3DViewController.chosenModels {
            var entry: [String: String] = ["model": modelName]
            if let color = avatar3DViewController.chosenColors[category] {
                entry["color"] = color.toHexString()
            }
            selections[category] = entry
        }
        let avatarData = CollectionAvatar.AvatarData(selections: selections)
        
        if isProfileAvatar {
            db.collection("users").document(currentUserId)
                .setData([
                    "avatarData": avatarData.toFirestoreDict(),
                    "updatedAt": Timestamp(date: Date())
                ], merge: true) { [weak self] error in
                    if let error = error {
                        print("Error saving profile avatar: \(error.localizedDescription)")
                        return
                    }
                    // Notify delegate
                    self?.delegate?.avatarCustomViewController(self!, didSaveAvatar: avatarData)
                    // Pop view controller
                    self?.navigationController?.popViewController(animated: true)
                }
        } else if let collectionId = collectionId {
            // Save to collection avatar
            let userRef = db.collection("users").document(currentUserId)
            let collectionRef = userRef.collection("collections").document(collectionId)
            
            // First, get the current collection data to preserve other fields
            collectionRef.getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error getting collection data: \(error.localizedDescription)")
                    return
                }
                
                var data: [String: Any] = [
                    "avatarData": avatarData.toFirestoreDict(),
                    "createdAt": Timestamp(date: Date()),
                    "userId": currentUserId,  // Ensure userId is set
                    "name": snapshot?.data()?["name"] as? String ?? "Untitled Collection"  // Preserve name
                ]
                
                // If the collection exists, preserve its other fields
                if let existingData = snapshot?.data() {
                    print("DEBUG: Found existing collection data: \(existingData)")
                    for (key, value) in existingData {
                        if !["avatarData", "createdAt", "userId", "name"].contains(key) {
                            data[key] = value
                        }
                    }
                }
                
                // Save the updated data
                collectionRef.setData(data, merge: true) { error in
                    if let error = error {
                        print("Error saving collection avatar: \(error.localizedDescription)")
                        return
                    }
                    print("DEBUG: Successfully saved collection avatar")
                    // Notify delegate
                    self?.delegate?.avatarCustomViewController(self!, didSaveAvatar: avatarData)
                    // Pop view controller
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    func setInitialAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        print("DEBUG: Setting initial avatar data: \(avatarData.selections)")
        currentAvatarData = avatarData
        // Make sure to load the avatar data in the 3D view
        if let avatar3DViewController = avatar3DViewController {
            print("DEBUG: Loading avatar data in 3D view")
            avatar3DViewController.loadAvatarData(avatarData)
        } else {
            print("DEBUG: Avatar3DViewController not ready yet")
        }
    }
}

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }
}
