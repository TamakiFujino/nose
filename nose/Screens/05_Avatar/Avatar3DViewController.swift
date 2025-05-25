import UIKit
import RealityKit
import Combine

class Avatar3DViewController: UIViewController {
    
    var arView: ARView!
    var baseEntity: ModelEntity?
    var chosenModels: [String: String] = [:]
    var chosenColors: [String: UIColor] = [:]
    var selectedItem: Any? // Replace `Any` with the appropriate type for your selected item
    var cancellables: [AnyCancellable] = []
    var currentUserId: String = "defaultUser" // Replace with actual user ID
    
    var skinColor: UIColor? {
        return chosenColors["skin"]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        loadAvatarModel()
        setupCameraPosition()
        setupBaseEntity()
        addDirectionalLight()
        loadSelectionState()
        setupEnvironmentBackground()
    }
    
    func setupARView() {
        arView = ARView(frame: .zero) // ✅ Let Auto Layout handle size
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.backgroundColor = .clear
        view.addSubview(arView)
        
        // ✅ Use Auto Layout constraints
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // You can modify this to set height
        ])
    }
    
    func setupEnvironmentBackground() {
        view.backgroundColor = .secondColor
        arView.environment.background = .color(.secondColor)
    }
    
    func loadAvatarModel() {
        // Initialize chosenModels with empty strings for each category
        var savedModels = [
            "bottoms": "",
            "tops": "",
            "hair_base": "",
            "hair_front": "",
            "hair_back": "",
            "jackets": "",
            "skin": "",
            "eye": "",
            "eyebrow": "",
            "nose": "",
            "mouth": "",
            "socks": "",
            "shoes": "",
            "head": "",
            "neck": "",
            "eyewear": ""
        ]
        
        // Load saved models and colors for each category if they exist
        for (category, _) in savedModels {
            if let savedModel = UserDefaults.standard.string(forKey: "chosen\(category.capitalized)Model") {
                savedModels[category] = savedModel
            }
        }
        
        chosenModels = savedModels
        
        // Load saved colors for each category
        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors"),
           let savedColors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(savedColorsData) as? [String: UIColor] {
            chosenColors = savedColors
        }
        
        // Load the base avatar model
        do {
            baseEntity = try Entity.loadModel(named: "body_2") as? ModelEntity
            baseEntity?.name = "Avatar"
            // print the origin position of baseEntity
            print("baseEntity origin: \(String(describing: baseEntity?.position))")
            // print the size of the baseEntity entity
            if let bounds = baseEntity?.visualBounds(relativeTo: nil) {
                print("baseEntity size: \(bounds.extents)")
            }
            
            setupBaseEntity()
            
            // Load the saved or default models and apply colors for each category
            for (category, modelName) in savedModels {
                if !modelName.isEmpty {
                    loadClothingItem(named: modelName, category: category)
                }
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
            
            let newModel = try Entity.loadModel(named: modelName) as? ModelEntity
            newModel?.name = modelName
            
            // Force scale to 1.0
            newModel?.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            
            if let newModel = newModel {
                baseEntity?.addChild(newModel) // Attach to the base avatar
            }
            
            print("newModel origin: \(String(describing: newModel?.position))")
            print("newModel size (forced scale): \(String(describing: newModel?.visualBounds(relativeTo: nil).extents))")
            
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
    
    func removeClothingItem(for category: String) {
        // Remove the previous model for the category if it exists
        if let previousModelName = chosenModels[category], let existingEntity = baseEntity?.findEntity(named: previousModelName) {
            existingEntity.removeFromParent()
            chosenModels[category] = ""
        }
    }
    
    func setupCameraPosition(position: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 14.0)) {
        // Create a camera entity
        let cameraEntity = PerspectiveCamera()
        cameraEntity.transform.translation = position // Position the camera
        
        // Create a camera anchor to hold the camera entity
        let cameraAnchor = AnchorEntity()
        cameraAnchor.addChild(cameraEntity)
        
        // Add the camera anchor to the scene
        arView.scene.anchors.append(cameraAnchor)
    }
    
    func setupBaseEntity() {
        guard let baseEntity = baseEntity else { return }
        
        // Rotate the model (Y-axis for turning left/right, X for tilting forward/back)
        baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
        
        let anchor = AnchorEntity(world: [0, 0, 0]) // Place in world space
        anchor.addChild(baseEntity)
        arView.scene.anchors.append(anchor)
    }
    
    func saveChosenModelsAndColors() -> Bool {
        return saveChosenModelsAndColors(for: currentUserId)
    }
    
    func saveChosenModelsAndColors(for userId: String) -> Bool {
        for (category, modelName) in chosenModels {
            let key = "chosenModels_\(userId)_\(category)"
            UserDefaults.standard.set(modelName, forKey: key)
        }
        
        do {
            let colorsData = try NSKeyedArchiver.archivedData(withRootObject: chosenColors, requiringSecureCoding: false)
            UserDefaults.standard.set(colorsData, forKey: "chosenColors_\(userId)")
            print("✅ Saved models and colors for userId: \(userId)")
            return true
        } catch {
            print("❌ Failed to archive colors for userId \(userId): \(error)")
            return false
        }
    }
    
    func changeClothingItemColor(for category: String, to color: UIColor, materialIndex: Int = 0) {
        guard let modelName = chosenModels[category],
              let entity = baseEntity?.findEntity(named: modelName) as? ModelEntity else {
            print("Model entity not found for category: \(category)")
            return
        }
        
        // Print debug information
        print("Changing color for category: \(category), model: \(modelName), color: \(color), material index: \(materialIndex)")
        
        // Ensure the material index is within bounds
        guard materialIndex < entity.model?.materials.count ?? 0 else {
            print("Material index out of bounds for category: \(category)")
            return
        }
        
        // Create a new SimpleMaterial with the specified color and adjust properties to reduce shininess
        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0) // Increase roughness
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0) // Decrease metallic
        
        // Replace the material at the specified index
        if var materials = entity.model?.materials {
            materials[materialIndex] = material
            entity.model?.materials = materials
        }
        
        // Print final materials to verify the change
        print("Updated materials: \(String(describing: entity.model?.materials))")
    }
    
    func changeSkinColor(to color: UIColor, materialIndex: Int = 0) {
        guard let baseEntity = baseEntity else {
            print("Base entity not found")
            return
        }
        
        // Ensure the material index is within bounds
        guard materialIndex < baseEntity.model?.materials.count ?? 0 else {
            print("Material index out of bounds for skin")
            return
        }
        
        // Create a new SimpleMaterial with the specified color for the skin
        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
        
        // Replace the material at the specified index
        if var materials = baseEntity.model?.materials {
            materials[materialIndex] = material
            baseEntity.model?.materials = materials
        }
        
        // Print final materials to verify the change
        print("Updated skin color: \(String(describing: baseEntity.model?.materials))")
    }
    
    private func addDirectionalLight() {
        let lightAnchor = AnchorEntity(world: [0, 2.0, 0]) // Higher placement
        let light = DirectionalLight()
        
        light.light.intensity = 1000 // Increase brightness
        light.light.color = .fourthColor // Adjust color if needed
        light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10.0, depthBias: 0.005) // Softer shadows
        
        light.orientation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0]) // Slightly angled
        lightAnchor.addChild(light)
        
        arView.scene.anchors.append(lightAnchor)
    }
    
    private func loadSelectionState() {
        // Check if there is any saved data
        if let savedSelection = UserDefaults.standard.object(forKey: "selectedItem") {
            // Handle the case where there is saved data
            self.selectedItem = savedSelection
        } else {
            // Handle the case where there is no saved data
            self.selectedItem = nil
        }
    }
}
