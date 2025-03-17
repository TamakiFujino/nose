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
        // Save the chosen 3D models
        avatar3DViewController.saveChosenModelsAndColors()

        // Capture the avatar as PNG
        avatar3DViewController.captureSnapshot()
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
