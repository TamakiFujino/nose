import UIKit
import RealityKit

class AvatarCustomViewController: UIViewController {

    var avatar3DViewController: Avatar3DViewController!
    var avatarUIManager: AvatarUIManager!
    var selectedBookmarkList: BookmarkList?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Avatar"

        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveButtonTapped))
        saveButton.tintColor = .black
        self.navigationItem.rightBarButtonItem = saveButton

        avatar3DViewController = Avatar3DViewController()
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)

        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)

        // ✅ Load outfit if available
        if let outfit = selectedBookmarkList?.associatedOutfit {
            avatar3DViewController.loadOutfitFrom(outfit)
        }

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        checkForSavedData()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
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

    private func checkForSavedData() {
        // Check if there is any saved data
        if UserDefaults.standard.object(forKey: "selectedItem") == nil {
            // No saved data, set no item selected
            avatar3DViewController.selectedItem = nil
            avatar3DViewController.updateUIForNoSelection()
        }
    }
    
    @objc func closeButtonTapped() {
        dismiss(animated: true)
    }
}
