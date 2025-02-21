import UIKit
import RealityKit

class Avatar3DViewController: UIViewController {
    
    var arView: ARView!
    var baseEntity: Entity!
    var bottomEntity: Entity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        loadAvatarModel()
        setupCamera()
    }

    func setupARView() {
            arView = ARView(frame: view.bounds)
            view.addSubview(arView)
            
            // Set the background color to yellow
        arView.environment.background = .color(.secondColor)
        }

    func loadAvatarModel() {
        // Load the base avatar model
        do {
            baseEntity = try Entity.loadModel(named: "body")
            baseEntity.name = "Avatar"
            // print the origin position of baseEntity
            print("baseEntity origin: \(baseEntity.position)")
            // print the size of the baseEntity entity
            let bounds = baseEntity.visualBounds(relativeTo: nil)
            print("baseEntity size: \(bounds.extents)")
            
            // Rotate the model (Y-axis for turning left/right, X for tilting forward/back)
            baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])

            let anchor = AnchorEntity(world: [0, 0, 0]) // Place in world space
            anchor.addChild(baseEntity)
            arView.scene.anchors.append(anchor)
            
            // Load the bottom model
            loadClothingItem(named: "bottom_1")
            
        } catch {
            print("Error loading base avatar model: \(error)")
        }
    }

    func loadClothingItem(named modelName: String) {
        do {
            bottomEntity?.removeFromParent()

            let newBottom = try Entity.loadModel(named: modelName)
            newBottom.name = modelName

            // Force scale to 1.0
            newBottom.scale = SIMD3<Float>(1.0, 1.0, 1.0)

            baseEntity.addChild(newBottom) // Attach to the base avatar

            print("newBottom origin: \(newBottom.position)")
            print("newBottom size (forced scale): \(newBottom.visualBounds(relativeTo: nil).extents)")

            bottomEntity = newBottom

        } catch {
            print("Error loading clothing item: \(error)")
        }
    }

    func setupCamera() {
        // Create a camera entity
        let cameraEntity = PerspectiveCamera()
        cameraEntity.transform.translation = SIMD3<Float>(0.0, -4.0, 20.0) // Position the camera
        
        // Create a camera anchor to hold the camera entity
        let cameraAnchor = AnchorEntity()
        cameraAnchor.addChild(cameraEntity)
        
        // Add the camera anchor to the scene
        arView.scene.anchors.append(cameraAnchor)
    }
}
