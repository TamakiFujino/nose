import UIKit
import RealityKit

class AvatarCustomViewController: UIViewController {

    var avatar3DViewController: Avatar3DViewController!
    var avatarUIManager: AvatarUIManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the navigation bar title
        self.title = "Avatar"

        // Add save button to the navigation bar
        let saveButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveButtonTapped))
        // set button text color
        saveButton.tintColor = .black
        self.navigationItem.rightBarButtonItem = saveButton

        // Initialize and add the Avatar3DViewController
        avatar3DViewController = Avatar3DViewController()
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)

        // Initialize the AvatarUIManager
        avatarUIManager = AvatarUIManager(viewController: self, avatar3DViewController: avatar3DViewController)

        // Add gesture for rotation
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        // Set no item selected if there is no data saved previously
        checkForSavedData()
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

        guard didSave else {
            ToastManager.showToast(message: ToastMessages.avatarUpdateFailed, type: .error)
            return
        }

        avatar3DViewController.captureSnapshot { success in
            if success {
                ToastManager.showToast(message: ToastMessages.avatarUpdated, type: .success)
            } else {
                ToastManager.showToast(message: ToastMessages.avatarUpdateFailed, type: .error)
                ToastManager.showToast(message: "Saved, but failed to capture snapshot.", type: .error)
            }
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
}
