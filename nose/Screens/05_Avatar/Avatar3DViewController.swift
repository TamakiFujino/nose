import UIKit
import RealityKit
import Combine

private var modelCache: [String: ModelEntity] = [:]

class Avatar3DViewController: UIViewController {

    // MARK: - Properties

    var isPreviewMode: Bool = false
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 14.0)
    var baseEntity: ModelEntity?
    var chosenModels: [String: String] = [:]
    var chosenColors: [String: UIColor] = [:]
    var selectedItem: Any?
    var cancellables = Set<AnyCancellable>()
    var currentUserId: String = "defaultUser"

    // MARK: - Computed Properties

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
        view.backgroundColor = .clear
        return view
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        if !isPreviewMode {
            loadAvatarModel()
            loadSelectionState()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .secondColor
        setupARView()
        setupCameraPosition()
        setupBaseEntity()
        addDirectionalLight()
        setupEnvironmentBackground()
    }

    private func setupARView() {
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEnvironmentBackground() {
        arView.environment.background = .color(.secondColor)
    }

    private func setupCameraPosition() {
        let cameraEntity = PerspectiveCamera()
        cameraEntity.transform.translation = cameraPosition
        let cameraAnchor = AnchorEntity()
        cameraAnchor.addChild(cameraEntity)
        arView.scene.anchors.append(cameraAnchor)
    }

    private func setupBaseEntity() {
        guard let baseEntity else { return }
        clearBaseEntityAnchors()
        baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(baseEntity)
        arView.scene.anchors.append(anchor)
    }
    
    private func clearBaseEntityAnchors() {
        // Only keep anchors that do NOT contain the baseEntity ("Avatar")
        let anchorsToRemove = arView.scene.anchors.filter { anchor in
            anchor.children.contains(where: { $0.name == "Avatar" })
        }
        for anchor in anchorsToRemove {
            arView.scene.anchors.remove(anchor)
        }
    }
    
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
    

    // MARK: - Avatar Management

    func loadAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        isPreviewMode = true
        clearAvatarState()
        
        if baseEntity == nil {
            loadBaseModel()
        }

        applyAvatarData(avatarData)
    }

    private func clearAvatarState() {
        chosenModels.removeAll()
        chosenColors.removeAll()
        
        let categories = ["bottoms", "tops", "hair_base", "hair_front", "hair_back", "jackets", "skin",
                         "eye", "eyebrow", "nose", "mouth", "socks", "shoes", "head", "neck", "eyewear"]
        categories.forEach { removeClothingItem(for: $0) }
    }

    private func loadBaseModel() {
        do {
            baseEntity = try Entity.loadModel(named: "body_2") as? ModelEntity
            baseEntity?.name = "Avatar"
            setupBaseEntity()
        } catch {
            print("Error loading base avatar model: \(error)")
        }
    }

    private func applyAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        for (category, entry) in avatarData.selections {
            if let modelName = entry["model"] {
                chosenModels[category] = modelName
                loadClothingItem(named: modelName, category: category)
            }
            
            if let colorString = entry["color"], let color = UIColor(hex: colorString) {
                chosenColors[category] = color
                if category == "skin" {
                    changeSkinColor(to: color)
                } else {
                    changeClothingItemColor(for: category, to: color)
                }
            }
        }
    }

    func loadClothingItem(named modelName: String, category: String) {
        // Remove previous model if present
        if let previousModelName = chosenModels[category],
           let existingEntity = baseEntity?.findEntity(named: previousModelName) {
            existingEntity.removeFromParent()
        }

        // Try to get from cache
        let modelEntity: ModelEntity
        if let cached = modelCache[modelName] {
            modelEntity = cached.clone(recursive: true)
        } else {
            guard let loaded = try? Entity.loadModel(named: modelName) as? ModelEntity else {
                print("Failed to load model: \(modelName)")
                return
            }
            modelCache[modelName] = loaded
            modelEntity = loaded.clone(recursive: true)
        }

        modelEntity.name = modelName
        modelEntity.scale = SIMD3<Float>(repeating: 1.0)
        baseEntity?.addChild(modelEntity)
        chosenModels[category] = modelName

        // Apply color if already chosen
        if let color = chosenColors[category] {
            changeClothingItemColor(for: category, to: color)
        }
    }

    func removeClothingItem(for category: String) {
        if let previousModelName = chosenModels[category],
           let existingEntity = baseEntity?.findEntity(named: previousModelName) {
            existingEntity.removeFromParent()
            chosenModels[category] = ""
        }
    }

    // MARK: - Color Management

    func changeClothingItemColor(for category: String, to color: UIColor, materialIndex: Int = 0) {
        guard let modelName = chosenModels[category],
              let entity = baseEntity?.findEntity(named: modelName) as? ModelEntity,
              let materialsCount = entity.model?.materials.count,
              materialIndex < materialsCount else {
            return
        }

        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 0.5)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.1)

        if var materials = entity.model?.materials {
            materials[materialIndex] = material
            entity.model?.materials = materials
        }
        
        chosenColors[category] = color
    }

    func changeSkinColor(to color: UIColor, materialIndex: Int = 0) {
        guard let baseEntity,
              let materialsCount = baseEntity.model?.materials.count,
              materialIndex < materialsCount else {
            return
        }

        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 0.5)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.1)

        if var materials = baseEntity.model?.materials {
            materials[materialIndex] = material
            baseEntity.model?.materials = materials
        }
    }

    // MARK: - State Management

    private func loadSelectionState() {
        selectedItem = UserDefaults.standard.object(forKey: "selectedItem")
    }

    func saveChosenModelsAndColors() -> Bool {
        return saveChosenModelsAndColors(for: currentUserId)
    }

    func saveChosenModelsAndColors(for userId: String) -> Bool {
        for (category, modelName) in chosenModels {
            UserDefaults.standard.set(modelName, forKey: "chosenModels_\(userId)_\(category)")
        }
        
        do {
            let colorsData = try NSKeyedArchiver.archivedData(withRootObject: chosenColors, requiringSecureCoding: false)
            UserDefaults.standard.set(colorsData, forKey: "chosenColors_\(userId)")
            return true
        } catch {
            print("Failed to archive colors for userId \(userId): \(error)")
            return false
        }
    }

    // MARK: - Avatar Management
    private func loadAvatarModel() {
        let categories = [
            "bottoms", "tops", "hair_base", "hair_front", "hair_back", "jackets", "skin",
            "eye", "eyebrow", "nose", "mouth", "socks", "shoes", "head", "neck", "eyewear"
        ]
        
        // Load chosen models from UserDefaults
        for category in categories {
            let key = "chosen\(category.capitalized)Model"
            if let modelName = UserDefaults.standard.string(forKey: key), !modelName.isEmpty {
                chosenModels[category] = modelName
            }
        }

        // Load chosen colors from UserDefaults
        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors"),
           let savedColors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(savedColorsData) as? [String: UIColor] {
            chosenColors = savedColors
        }

        // Load base entity model asynchronously
        Entity.loadModelAsync(named: "body_2")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error loading base avatar model: \(error)")
                }
            }, receiveValue: { [weak self] entity in
                guard let self = self else { return }
                self.baseEntity = entity as? ModelEntity
                self.baseEntity?.name = "Avatar"
                self.setupBaseEntity()
                
                for (category, modelName) in self.chosenModels where !modelName.isEmpty {
                    self.loadClothingItem(named: modelName, category: category)
                    if let color = self.chosenColors[category] {
                        self.changeClothingItemColor(for: category, to: color)
                    }
                }
            })
            .store(in: &cancellables)
    }
}
