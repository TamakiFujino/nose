import UIKit
import RealityKit

class Avatar3DViewController: UIViewController {
    
    var arView: ARView!
    var baseEntity: Entity!
    var chosenModels: [String: String] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        loadAvatarModel()
        setupCamera()
    }

    func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.backgroundColor = .clear // Ensure ARView background is transparent
        view.addSubview(arView)
        
        // Set the background color to yellow
        arView.environment.background = .color(.secondColor)
    }

    func loadAvatarModel() {
        // Load saved models for each category or use defaults if none are saved
        var savedModels = [String: String]()
        savedModels["bottoms"] = UserDefaults.standard.string(forKey: "chosenBottomModel") ?? "bottom_1"
        savedModels["tops"] = UserDefaults.standard.string(forKey: "chosenTopModel") ?? "top_1"
        savedModels["hair_base"] = UserDefaults.standard.string(forKey: "chosenHairBaseModel") ?? "hair_base_1"
        savedModels["hair_front"] = UserDefaults.standard.string(forKey: "chosenHairFrontModel") ?? "hair_front_1"
        savedModels["hair_back"] = UserDefaults.standard.string(forKey: "chosenHairBackModel") ?? "hair_back_1"
        savedModels["jackets"] = UserDefaults.standard.string(forKey: "chosenJacketModel") ?? "jacket_1"
        savedModels["skin"] = UserDefaults.standard.string(forKey: "chosenSkinModel") ?? "skin_1"
        savedModels["eye"] = UserDefaults.standard.string(forKey: "chosenEyeModel") ?? "eye_1"
        savedModels["eyebrow"] = UserDefaults.standard.string(forKey: "chosenEyebrowModel") ?? "eyebrow_1"
        savedModels["nose"] = UserDefaults.standard.string(forKey: "chosenNoseModel") ?? "nose_1"
        savedModels["socks"] = UserDefaults.standard.string(forKey: "chosenSocksModel") ?? "socks_1"
        savedModels["shoes"] = UserDefaults.standard.string(forKey: "chosenShoesModel") ?? "shoes_1"
        savedModels["head"] = UserDefaults.standard.string(forKey: "chosenHeadModel") ?? "head_1"
        savedModels["neck"] = UserDefaults.standard.string(forKey: "chosenNeckModel") ?? "neck_1"
        savedModels["hand"] = UserDefaults.standard.string(forKey: "chosenHandModel") ?? "hand_1"
        
        chosenModels = savedModels
        
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
            
            // Load the saved or default models for each category
            for (category, modelName) in savedModels {
                loadClothingItem(named: modelName, category: category)
            }
            
        } catch {
            print("Error loading base avatar model: \(error)")
        }
    }

    func loadClothingItem(named modelName: String, category: String) {
        do {
            // Remove the previous model for the category if it exists
            if let previousModelName = chosenModels[category], let existingEntity = baseEntity.findEntity(named: previousModelName) {
                existingEntity.removeFromParent()
            }
            
            let newModel = try Entity.loadModel(named: modelName)
            newModel.name = modelName

            // Force scale to 1.0
            newModel.scale = SIMD3<Float>(1.0, 1.0, 1.0)

            baseEntity.addChild(newModel) // Attach to the base avatar

            print("newModel origin: \(newModel.position)")
            print("newModel size (forced scale): \(newModel.visualBounds(relativeTo: nil).extents)")

            // Save the chosen model for the category
            chosenModels[category] = modelName
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
    
    func saveChosenModels() {
        // Save the chosen models to UserDefaults
        for (category, modelName) in chosenModels {
            UserDefaults.standard.set(modelName, forKey: "chosen\(category.capitalized)Model")
        }
        print("Chosen models saved: \(chosenModels)")
    }
}
