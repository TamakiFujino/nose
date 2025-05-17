import UIKit
import RealityKit

class AvatarCustomViewController: UIViewController {

    var avatar3DViewController: Avatar3DViewController!
    var avatarUIManager: AvatarUIManager!
    var selectedBookmarkList: BookmarkList?

    private var loadingIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Avatar"
        view.backgroundColor = .white // Assuming a default background

        setupLoadingIndicator()
        showLoadingIndicator()

        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveButtonTapped))
        saveButton.tintColor = .black
        self.navigationItem.rightBarButtonItem = saveButton

        avatar3DViewController = Avatar3DViewController()
        // Set the completion handler *before* adding as child, so it's ready when loadAvatarModel is called
        avatar3DViewController.onInitialLoadComplete = { [weak self] in
            self?.hideLoadingIndicator()
            // Any other UI updates after initial load can go here
            print("Avatar initial load complete, hiding indicator.")
        }

        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)
        // Ensure Avatar3DViewController's view is behind the loading indicator if it's full screen
        view.bringSubviewToFront(loadingIndicator)

        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)

        // ✅ Load outfit if available
        if let outfit = selectedBookmarkList?.associatedOutfit {
            avatar3DViewController.loadOutfitFrom(outfit)
            // AvatarUIManager might need to sync its UI to this outfit here.
            // For now, displayInitialCategory (called below) will handle a default selection.
        }

        // Instruct AvatarUIManager to select and display an initial category thumbnail.
        // This method should exist on AvatarUIManager and contain logic to pick a sensible default.
        avatarUIManager.displayInitialCategory() 

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }

    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .gray
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func showLoadingIndicator() {
        loadingIndicator.startAnimating()
        // Optionally disable user interaction on underlying views
        // view.isUserInteractionEnabled = false 
    }

    private func hideLoadingIndicator() {
        loadingIndicator.stopAnimating()
        // Re-enable user interaction if it was disabled
        // view.isUserInteractionEnabled = true
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let rotationAngle = Float(translation.x / view.bounds.width) * .pi

        avatar3DViewController.baseEntity?.transform.rotation *= simd_quatf(angle: rotationAngle, axis: [0, 1, 0])

        // Reset the translation to avoid compounding the rotation
        gesture.setTranslation(.zero, in: view)
    }

    @objc func saveButtonTapped() {
        let didSave = avatar3DViewController.saveChosenModelsAndColors()
        ToastManager.showToast(message: ToastMessages.avatarUpdated, type: .success)

        guard var bookmark = selectedBookmarkList else {
            print("❌ No bookmark selected")
            ToastManager.showToast(message: "No bookmark selected.", type: .error)
            return
        }

        let outfit = avatar3DViewController.exportCurrentOutfitAsAvatarOutfit()
        bookmark.associatedOutfit = outfit
        BookmarksManager.shared.saveBookmarkList(bookmark)

        guard didSave else {
            ToastManager.showToast(message: ToastMessages.avatarUpdateFailed, type: .error)
            return
        }
    }
    
    @objc func closeButtonTapped() {
        dismiss(animated: true)
    }
}
