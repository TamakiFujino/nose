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
        // First, check if this VC is part of a navigation stack and can be popped.
        // This is the most likely scenario given the console output and nav bar items.
        if let navController = self.navigationController {
            // If self is the root of this navigationController, popViewController might not be what you want
            // unless this whole navigationController is meant to be removed by a different mechanism.
            // However, a "close" button usually means popping if not dismissing a modal.
            if navController.viewControllers.count > 1 && navController.topViewController == self {
                 print("Popping AvatarCustomViewController from navigation stack.")
                navController.popViewController(animated: true)
                return // Successfully popped
            } else if navController.viewControllers.count == 1 && navController.topViewController == self {
                // This is the root of its own navigation controller. 
                // If this nav controller itself was presented modally, previous attempts to dismiss presentingVC would have worked.
                // If it wasn't modal, then how is it meant to be closed? 
                // This indicates a more complex setup or a different expectation for "close".
                print("AvatarCustomViewController is the root of its navigation controller. Standard pop is not applicable. Check presentation method.")
                // Fall-through to see if it was modally presented without a nav controller for some reason.
            }
        }

        // Fallback to modal dismiss attempt (though the console message indicated this wasn't the case)
        // This will try to dismiss if self was presented modally without a nav controller.
        let presentingVC = self.presentingViewController
        if let vc = presentingVC {
            print("Attempting to dismiss modally presented AvatarCustomViewController (without NavController).")
            vc.dismiss(animated: true, completion: nil)
        } else {
            print("Close button tapped: No presentingViewController and not popped from a nav stack. Action unclear.")
            // If it reaches here, the view controller is not modal and not in a deeper navigation stack.
            // The app's specific navigation structure needs to be understood to define "close".
        }
    }
}
