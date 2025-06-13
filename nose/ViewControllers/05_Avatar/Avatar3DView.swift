import UIKit
import RealityKit
import Combine

class Avatar3DView: UIViewController {

    // MARK: - Properties

    var isPreviewMode: Bool = false
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 14.0)
    var baseEntity: ModelEntity?
    var chosenModels: [String: String] = [:]
    var chosenColors: [String: UIColor] = [:]
    var selectedItem: Any?
    var cancellables = Set<AnyCancellable>()
    var currentUserId: String = "defaultUser"
    
    private var modelCache: [String: ModelEntity] = [:]
    private var activeEntities: Set<String> = []
    private var sceneUpdateQueue = DispatchQueue(label: "com.avatar.scene", qos: .userInteractive)
    private var pendingSceneUpdates: [() -> Void] = []
    private var isProcessingSceneUpdates = false

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
        }
        setupCameraPosition()
        setupBaseEntity()
        addDirectionalLight()
        if !isPreviewMode {
            loadSelectionState()
        }
        setupEnvironmentBackground()
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
        
        // Create material for base entity if not exists
        if AvatarMaterialManager.shared.getMaterial(for: "skin") == nil {
            let material = AvatarMaterialManager.shared.createMaterial(color: .white)
            AvatarMaterialManager.shared.updateMaterial(for: "skin", color: .white)
        }
        
        // Apply the material to the base entity
        if let material = AvatarMaterialManager.shared.getMaterial(for: "skin") {
            AvatarMaterialManager.shared.applyMaterial(material, to: baseEntity)
        }
        
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(baseEntity)
        arView.scene.anchors.append(anchor)
    }
    
    private func clearBaseEntityAnchors() {
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
        AvatarCategory.all.forEach { removeAvatarPart(for: $0) }
    }

    private func loadBaseModel() {
        Task {
            do {
                let entity = try await AvatarResourceManager.shared.loadModelEntity(named: "body")
                await MainActor.run {
                    self.baseEntity = entity as? ModelEntity
                    self.baseEntity?.name = "Avatar"
                    self.setupBaseEntity()
                }
            } catch {
                print("Error loading base avatar model: \(error)")
            }
        }
    }

    private func applyAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        for (category, entry) in avatarData.selections {
            if let modelName = entry["model"] {
                chosenModels[category] = modelName
                loadAvatarPart(named: modelName, category: category)
            }
            
            if let colorString = entry["color"],
               let color = AvatarColorManager.shared.fromHexString(colorString) {
                chosenColors[category] = color
                if category == "skin" {
                    changeSkinColor(to: color)
                } else {
                    changeAvatarPartColor(for: category, to: color)
                }
            }
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
        let categories = AvatarCategory.all
        
        for category in categories {
            let key = "chosen\(category.capitalized)Model"
            if let modelName = UserDefaults.standard.string(forKey: key), !modelName.isEmpty {
                chosenModels[category] = modelName
            }
        }

        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors"),
           let savedColors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(savedColorsData) as? [String: UIColor] {
            chosenColors = savedColors
        }

        loadBaseModel()
    }

    // MARK: - Color Management
    func changeSkinColor(to color: UIColor) {
        guard let baseEntity = baseEntity else { return }
        let material = AvatarMaterialManager.shared.createMaterial(color: color)
        AvatarMaterialManager.shared.updateMaterial(for: "skin", color: color)
        AvatarMaterialManager.shared.applyMaterial(material, to: baseEntity)
    }

    func changeAvatarPartColor(for category: String, to color: UIColor) {
        guard AvatarMaterialManager.shared.shouldUpdateMaterial(for: category) else { return }
        
        let material = AvatarMaterialManager.shared.createMaterial(color: color)
        AvatarMaterialManager.shared.updateMaterial(for: category, color: color)
        
        if let entity = findEntity(for: category) {
            AvatarMaterialManager.shared.applyMaterial(material, to: entity)
        }
    }

    // MARK: - Model Management
    private func findEntity(for category: String) -> ModelEntity? {
        for anchor in arView.scene.anchors {
            if let entity = anchor.children.first(where: { $0.name == category }) as? ModelEntity {
                return entity
            }
        }
        return nil
    }

    func loadAvatarPart(named modelName: String, category: String) {
        Task {
            do {
                let entity = try await AvatarResourceManager.shared.loadModelEntity(named: modelName)
                await MainActor.run {
                    self.addAvatarPart(entity, for: category)
                }
            } catch {
                print("Error loading avatar part: \(error)")
            }
        }
    }

    private func addAvatarPart(_ entity: ModelEntity, for category: String) {
        removeAvatarPart(for: category)
        
        entity.name = category
        if let color = chosenColors[category] {
            let material = AvatarMaterialManager.shared.createMaterial(color: color)
            AvatarMaterialManager.shared.applyMaterial(material, to: entity)
        }
        
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(entity)
        arView.scene.anchors.append(anchor)
        activeEntities.insert(category)
    }

    func removeAvatarPart(for category: String) {
        for anchor in arView.scene.anchors {
            if let entity = anchor.children.first(where: { $0.name == category }) {
                anchor.removeChild(entity)
                activeEntities.remove(category)
            }
        }
    }
}

extension MaterialColorParameter {
    var color: UIColor? {
        if case let .color(uiColor) = self {
            return uiColor
        }
        return nil
    }
}
