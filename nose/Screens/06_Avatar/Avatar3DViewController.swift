import UIKit
import RealityKit

class Avatar3DViewController: UIViewController {
    
    var arView: ARView!
    var baseEntity: Entity?
    var chosenModels: [String: String] = [:]
    var chosenColors: [String: UIColor] = [:]
    var selectedItem: Any? // Replace `Any` with the appropriate type for your selected item
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        loadAvatarModel()
        setupCamera()
        loadSelectionState()
    }

    func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.backgroundColor = .clear // Ensure ARView background is transparent
        view.addSubview(arView)
        
        // Set the background color to yellow
        arView.environment.background = .color(.secondColor)
    }

    func loadAvatarModel() {
        // Load saved models and colors for each category or use defaults if none are saved
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

        // Load saved colors for each category
        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors"),
           let savedColors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(savedColorsData) as? [String: UIColor] {
            chosenColors = savedColors
        }
        
        // Load the base avatar model
        do {
            baseEntity = try Entity.loadModel(named: "body")
            baseEntity?.name = "Avatar"
            // print the origin position of baseEntity
            print("baseEntity origin: \(baseEntity?.position)")
            // print the size of the baseEntity entity
            if let bounds = baseEntity?.visualBounds(relativeTo: nil) {
                print("baseEntity size: \(bounds.extents)")
            }
            
            // Rotate the model (Y-axis for turning left/right, X for tilting forward/back)
            baseEntity?.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])

            let anchor = AnchorEntity(world: [0, 0, 0]) // Place in world space
            if let baseEntity = baseEntity {
                anchor.addChild(baseEntity)
            }
            arView.scene.anchors.append(anchor)
            
            // Load the saved or default models and apply colors for each category
            for (category, modelName) in savedModels {
                loadClothingItem(named: modelName, category: category)
                if let color = chosenColors[category] {
                    changeClothingItemColor(for: category, to: color)
                }
            }
            
        } catch {
            print("Error loading base avatar model: \(error)")
        }
    }

    func loadClothingItem(named modelName: String, category: String) {
        do {
            // Remove the previous model for the category if it exists
            if let previousModelName = chosenModels[category], let existingEntity = baseEntity?.findEntity(named: previousModelName) {
                existingEntity.removeFromParent()
            }
            
            let newModel = try Entity.loadModel(named: modelName)
            newModel.name = modelName

            // Force scale to 1.0
            newModel.scale = SIMD3<Float>(1.0, 1.0, 1.0)

            baseEntity?.addChild(newModel) // Attach to the base avatar

            print("newModel origin: \(newModel.position)")
            print("newModel size (forced scale): \(newModel.visualBounds(relativeTo: nil).extents)")

            // Save the chosen model for the category
            chosenModels[category] = modelName

            // Apply the chosen color if it exists
            if let color = chosenColors[category] {
                changeClothingItemColor(for: category, to: color)
            }
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
    
    func saveChosenModelsAndColors() {
        // Save the chosen models to UserDefaults
        for (category, modelName) in chosenModels {
            UserDefaults.standard.set(modelName, forKey: "chosen\(category.capitalized)Model")
        }

        // Save the chosen colors to UserDefaults
        if let colorsData = try? NSKeyedArchiver.archivedData(withRootObject: chosenColors, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorsData, forKey: "chosenColors")
        }
        
        print("Chosen models and colors saved: \(chosenModels), \(chosenColors)")
    }
    
    func changeClothingItemColor(for category: String, to color: UIColor) {
        guard let modelName = chosenModels[category],
              let entity = baseEntity?.findEntity(named: modelName),
              let modelEntity = entity as? ModelEntity else {
            print("Model entity not found for category: \(category)")
            return
        }
        
        // Print debug information
        print("Changing color for category: \(category), model: \(modelName), color: \(color)")

        // Create a new SimpleMaterial with the specified color and adjust properties to reduce shininess
        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0) // Increase roughness
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0) // Decrease metallic

        // Assign the new material to the model entity
        modelEntity.model?.materials = [material]
        
        // Save the chosen color for the category
        chosenColors[category] = color
        saveChosenModelsAndColors()

        // Print final materials to verify the change
        print("Updated materials: \(modelEntity.model?.materials ?? [])")
    }
    
    private func loadSelectionState() {
        // Check if there is any saved data
        if let savedSelection = UserDefaults.standard.object(forKey: "selectedItem") {
            // Handle the case where there is saved data
            self.selectedItem = savedSelection
            // Update the UI to reflect the saved selection state
            updateUIForSelectedItem()
        } else {
            // Handle the case where there is no saved data
            self.selectedItem = nil
            // Update the UI to reflect that no item is selected
            updateUIForNoSelection()
        }
    }
    
    private func updateUIForSelectedItem() {
        // Implement the logic to update the UI for the selected item
        // For example, highlight the selected item in the 3D view
    }
    
    func updateUIForNoSelection() {
        // Implement the logic to update the UI for no selection
        // For example, clear any highlights in the 3D view
    }
}
