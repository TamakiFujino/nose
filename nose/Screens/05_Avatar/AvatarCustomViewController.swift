import UIKit
import RealityKit

protocol AvatarCustomViewControllerDelegate: AnyObject {
    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData)
}

class AvatarCustomViewController: UIViewController {

    var avatar3DViewController: Avatar3DViewController!
    var avatarUIManager: AvatarUIManager!
    // var selectedBookmarkList: BookmarkList?

    weak var delegate: AvatarCustomViewControllerDelegate?
    private var currentAvatarData: CollectionAvatar.AvatarData?

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
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveButtonTapped))
        saveButton.tintColor = .black
        navigationItem.rightBarButtonItem = saveButton
        
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .black
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setupAvatar3DView() {
        avatar3DViewController = Avatar3DViewController()
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)
        
        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)
        
        // Load existing avatar data if available
        if let avatarData = currentAvatarData {
            avatar3DViewController.loadAvatarData(avatarData)
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
        ToastManager.showToast(message: ToastMessages.avatarUpdated, type: .success)
        
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
