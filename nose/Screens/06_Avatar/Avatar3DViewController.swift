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

    // For initial loading state
    var onInitialLoadComplete: (() -> Void)?
    private var pendingInitialLoads: Int = 0
    private var initialLoadTriggered: Bool = false // To ensure onInitialLoadComplete fires only once if count starts at 0

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

    // Helper to be called by ModelLoading extension when an initial load operation finishes
    func initialLoadDidFinish() {
        DispatchQueue.main.async { 
            if self.pendingInitialLoads > 0 {
                self.pendingInitialLoads -= 1
            }
            print("Initial load item processed. Pending: \(self.pendingInitialLoads)")
            if self.pendingInitialLoads == 0 && self.initialLoadTriggered {
                print("All initial loads complete.")
                self.onInitialLoadComplete?()
            }
        }
    }
    
    // Renamed and made additive
    func addPendingInitialLoads(_ count: Int) {
        DispatchQueue.main.async {
            if count == 0 && self.pendingInitialLoads == 0 && !self.initialLoadTriggered { 
                // If we add 0 and nothing was pending, and we haven't triggered, complete now.
                // This handles the case where viewDidLoad loads nothing, then outfit loads nothing.
                print("Adding 0 pending loads, and nothing was pending. Completing initial load.")
                self.initialLoadTriggered = true // Mark that we've processed an initial load sequence
                self.onInitialLoadComplete?()
                return
            }
            if count > 0 {
                self.initialLoadTriggered = true // Mark that we've started a load sequence
            }
            self.pendingInitialLoads += count
            print("Added \(count) pending loads. Total pending: \(self.pendingInitialLoads)")
        }
    }

    var onDismiss: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismiss?()
    }
}
