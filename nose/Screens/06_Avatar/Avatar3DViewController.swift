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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        loadAvatarModel()
        setupCameraPosition()
        setupBaseEntity()
        addGroundPlaneWithShadow()
        addDirectionalLight()
        loadSelectionState()
    }
    
    func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.backgroundColor = .clear // Ensure ARView background is transparent
        view.backgroundColor = .secondColor
        view.addSubview(arView)
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
            baseEntity = try Entity.loadModel(named: "body") as? ModelEntity
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
    
    func setupCameraPosition(position: SIMD3<Float> = SIMD3<Float>(0.0, -4.0, 16.0)) {
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
        
        // Save the chosen color for the category
        chosenColors[category] = color
        saveChosenModelsAndColors()
        
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
        
        // Save the chosen color for the skin
        chosenColors["skin"] = color
        saveChosenModelsAndColors()
        
        // Print final materials to verify the change
        print("Updated skin color: \(String(describing: baseEntity.model?.materials))")
    }
    
    func applyMaskToModel(named modelName: String, isMasked: Bool, category: String) {
        guard let entity = baseEntity?.findEntity(named: modelName) as? ModelEntity else {
            print("Entity not found for model: \(modelName)")
            return
        }
        
        // Apply the mask by making the entity invisible or visible based on isMasked
        if isMasked {
            // Apply transparency (invisible)
            var material = SimpleMaterial()
            material.baseColor = .color(.clear) // Full transparency
            entity.model?.materials = [material]
        } else {
            // Restore original material (visible)
            if let savedModelName = chosenModels[category], let originalMaterial = entity.model?.materials.first {
                entity.model?.materials = [originalMaterial]
            }
        }
        
        // Save the mask state
        chosenModels[category] = modelName
        saveChosenModelsAndColors()
    }
    
    private func addGroundPlaneWithShadow() {
        // Create a plane entity to represent the ground
        let planeMesh = MeshResource.generatePlane(width: 1.0, depth: 1.0)
        var material = SimpleMaterial()
        material.baseColor = .color(.clear)
        
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
        planeEntity.position = SIMD3<Float>(0, -0.5, 0) // Position the plane below the avatar
        
        // Create an anchor for the ground plane
        let groundAnchor = AnchorEntity(world: [0, 0, 0])
        groundAnchor.addChild(planeEntity)
        
        // Add the ground anchor to the scene
        arView.scene.anchors.append(groundAnchor)
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
    
    @objc func captureSnapshot() {
        // Snapshot the ARView content to an image
        arView.snapshot(saveToHDR: false) { image in
            guard let image = image else {
                print("❌ Failed to capture snapshot.")
                return
            }
            
            // Save the image to a specific directory
            self.saveImage(image: image, toDirectory: "capturedAvatars")
        }
    }
    
    func saveImage(image: UIImage, toDirectory directory: String) {
        guard let data = image.pngData() else {
            print("❌ Failed to convert image to PNG data.")
            return
        }
        
        let fileManager = FileManager.default
        do {
            // Get the URL for the specified directory in the user's documents directory
            let documentsURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let directoryURL = documentsURL.appendingPathComponent(directory)
            
            // Create the directory if it doesn't exist
            if (!fileManager.fileExists(atPath: directoryURL.path)) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Create a unique filename for the image
            let filename = "avatar_\(UUID().uuidString).png"
            let fileURL = directoryURL.appendingPathComponent(filename)
            
            // Write the image data to the file
            try data.write(to: fileURL)
            print("✅ Image saved successfully to \(fileURL.path)")
        } catch {
            print("❌ Error saving image: \(error)")
        }
    }
}
