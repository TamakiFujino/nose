import UIKit
import RealityKit
import Combine

class Avatar3DViewController: UIViewController {

    var arView: ARView!
    var baseEntity: ModelEntity?
    var chosenModels: [String: String] = [:]
    var activeModelEntities: [String: ModelEntity] = [:]
    var chosenColors: [String: UIColor] = [:]
    var selectedItem: Any?
    var cancellables = Set<AnyCancellable>()
    var currentCategoryLoadingOps = [String: AnyCancellable]()
    var currentUserId: String = "defaultUser"

    // Caching loaded models to avoid reloading
    var modelCache: [String: ModelEntity] = [:]

    var skinColor: UIColor? {
        return chosenColors["skin"]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        loadAvatarModel()
        setupCameraPosition()
        addGroundPlaneWithShadow()
        addDirectionalLight()
        loadSelectionState()
        setupEnvironmentBackground()
    }

    var onDismiss: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismiss?()
    }
}
