import UIKit
import RealityKit
import Combine

class Avatar3DViewController: UIViewController {

    // MARK: - Properties

    var baseEntity: ModelEntity?
    var chosenModels: [String: String] = [:]
    var chosenColors: [String: UIColor] = [:]
    var selectedItem: Any? // TODO: Replace `Any` with the actual type if possible
    var cancellables = Set<AnyCancellable>()
    var currentUserId: String = "defaultUser" // TODO: Replace with actual user ID

    // Expose current avatar properties
    var currentColor: String {
        UserDefaults.standard.string(forKey: "selectedColor") ?? "default"
    }
    var currentStyle: String {
        UserDefaults.standard.string(forKey: "selectedStyle") ?? "default"
    }
    var currentAccessories: [String] {
        UserDefaults.standard.stringArray(forKey: "selectedAccessories") ?? []
    }
    var skinColor: UIColor? {
        chosenColors["skin"]
    }

    // MARK: - UI Components

    private lazy var arView: ARView = {
        let view = ARView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupCameraPosition()
        setupBaseEntity()
        addDirectionalLight()
        loadSelectionState()
        setupEnvironmentBackground()
    }

    // MARK: - Setup

    private func setupARView() {
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        arView.backgroundColor = .clear
    }

    private func setupEnvironmentBackground() {
        view.backgroundColor = .secondColor
        arView.environment.background = .color(.secondColor)
    }

    // MARK: - Avatar Management

    func loadAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        UserDefaults.standard.set(avatarData.color, forKey: "selectedColor")
        UserDefaults.standard.set(avatarData.style, forKey: "selectedStyle")
        UserDefaults.standard.set(avatarData.accessories, forKey: "selectedAccessories")
        updateAvatarAppearance()
    }

    private func updateAvatarAppearance() {
        if let color = UIColor(named: currentColor) {
            baseEntity?.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
        }
        // TODO: Update style and accessories based on implementation.
    }

    func saveChosenModelsAndColors() -> Bool {
        saveChosenModelsAndColors(for: currentUserId)
    }

    func saveChosenModelsAndColors(for userId: String) -> Bool {
        for (category, modelName) in chosenModels {
            UserDefaults.standard.set(modelName, forKey: "chosenModels_\(userId)_\(category)")
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

    // MARK: - Model Loading

    func loadAvatarModel() {
        let categories = [
            "bottoms", "tops", "hair_base", "hair_front", "hair_back", "jackets", "skin",
            "eye", "eyebrow", "nose", "mouth", "socks", "shoes", "head", "neck", "eyewear"
        ]
        var savedModels = [String: String]()
        for category in categories {
            let key = "chosen\(category.capitalized)Model"
            savedModels[category] = UserDefaults.standard.string(forKey: key) ?? ""
        }
        chosenModels = savedModels

        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors"),
           let savedColors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(savedColorsData) as? [String: UIColor] {
            chosenColors = savedColors
        }

        do {
            baseEntity = try Entity.loadModel(named: "body_2") as? ModelEntity
            baseEntity?.name = "Avatar"
            if let position = baseEntity?.position {
                print("baseEntity origin: \(position)")
            }
            if let bounds = baseEntity?.visualBounds(relativeTo: nil) {
                print("baseEntity size: \(bounds.extents)")
            }
            setupBaseEntity()
            for (category, modelName) in savedModels where !modelName.isEmpty {
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
            if let previousModelName = chosenModels[category],
               let existingEntity = baseEntity?.findEntity(named: previousModelName) {
                existingEntity.removeFromParent()
            }
            let newModel = try Entity.loadModel(named: modelName) as? ModelEntity
            newModel?.name = modelName
            newModel?.scale = SIMD3<Float>(repeating: 1.0)
            if let newModel = newModel {
                baseEntity?.addChild(newModel)
            }
            if let position = newModel?.position {
                print("newModel origin: \(position)")
            }
            if let size = newModel?.visualBounds(relativeTo: nil).extents {
                print("newModel size (forced scale): \(size)")
            }
            chosenModels[category] = modelName
            if let color = chosenColors[category] {
                changeClothingItemColor(for: category, to: color)
            }
        } catch {
            print("Error loading clothing item: \(error)")
        }
    }

    func removeClothingItem(for category: String) {
        if let previousModelName = chosenModels[category],
           let existingEntity = baseEntity?.findEntity(named: previousModelName) {
            existingEntity.removeFromParent()
            chosenModels[category] = ""
        }
    }

    func setupCameraPosition(position: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 14.0)) {
        let cameraEntity = PerspectiveCamera()
        cameraEntity.transform.translation = position
        let cameraAnchor = AnchorEntity()
        cameraAnchor.addChild(cameraEntity)
        arView.scene.anchors.append(cameraAnchor)
    }

    func setupBaseEntity() {
        guard let baseEntity else { return }
        baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(baseEntity)
        arView.scene.anchors.append(anchor)
    }

    // MARK: - Color Management

    func updateColor(_ color: UIColor) {
        baseEntity?.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
        UserDefaults.standard.set(color.accessibilityName, forKey: "selectedColor")
    }

    // MARK: - Style Management

    func updateStyle(_ style: String) {
        UserDefaults.standard.set(style, forKey: "selectedStyle")
        // TODO: Update the 3D model based on the selected style
    }

    // MARK: - Accessories Management

    func updateAccessories(_ accessories: [String]) {
        UserDefaults.standard.set(accessories, forKey: "selectedAccessories")
        // TODO: Update the 3D model with the selected accessories
    }

    // MARK: - Lighting

    private func addDirectionalLight() {
        let lightAnchor = AnchorEntity(world: [0, 2.0, 0])
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.light.color = .fourthColor
        light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10.0, depthBias: 0.005)
        light.orientation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
        lightAnchor.addChild(light)
        arView.scene.anchors.append(lightAnchor)
    }

    // MARK: - Selection State

    private func loadSelectionState() {
        selectedItem = UserDefaults.standard.object(forKey: "selectedItem")
    }

    // MARK: - Clothing & Skin Color

    func changeClothingItemColor(for category: String, to color: UIColor, materialIndex: Int = 0) {
        guard let modelName = chosenModels[category],
              let entity = baseEntity?.findEntity(named: modelName) as? ModelEntity else {
            print("Model entity not found for category: \(category)")
            return
        }
        print("Changing color for category: \(category), model: \(modelName), color: \(color), material index: \(materialIndex)")
        guard let materialsCount = entity.model?.materials.count, materialIndex < materialsCount else {
            print("Material index out of bounds for category: \(category)")
            return
        }
        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
        if var materials = entity.model?.materials {
            materials[materialIndex] = material
            entity.model?.materials = materials
        }
        print("Updated materials: \(String(describing: entity.model?.materials))")
    }

    func changeSkinColor(to color: UIColor, materialIndex: Int = 0) {
        guard let baseEntity else {
            print("Base entity not found")
            return
        }
        guard let materialsCount = baseEntity.model?.materials.count, materialIndex < materialsCount else {
            print("Material index out of bounds for skin")
            return
        }
        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
        if var materials = baseEntity.model?.materials {
            materials[materialIndex] = material
            baseEntity.model?.materials = materials
        }
        print("Updated skin color: \(String(describing: baseEntity.model?.materials))")
    }
}
