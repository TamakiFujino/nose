import UIKit
import RealityKit
import Combine

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
    
        // Debounce for color changes (applies to all items)
        private var colorChangeDebounceWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    
    private var modelCache: [String: ModelEntity] = [:]
    private var baseMaterial: SimpleMaterial?
    private var entityPool: [String: ModelEntity] = [:]  // Pool of reusable entities
    private var activeEntities: Set<String> = []  // Track currently active entities
    private var materialCache: [String: SimpleMaterial] = [:]  // Cache for materials
    private var animationQueue = DispatchQueue(label: "com.avatar.animation", qos: .userInteractive)
    private var pendingAnimations: [String: [AnimationBlock]] = [:]

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
            setupARView()
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
        
        // Create and store the base material for reuse
        if baseMaterial == nil {
            if let materials = baseEntity.model?.materials,
               let firstMaterial = materials.first as? SimpleMaterial {
                baseMaterial = firstMaterial
            } else {
                // Create a default material if none exists
                baseMaterial = SimpleMaterial(color: .white, isMetallic: false)
            }
        }
        
        // Apply the base material to the base entity
        if let baseMaterial = baseMaterial {
            baseEntity.model?.materials = [baseMaterial]
        }
        
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
        
        let categories = ["bottoms", "tops", "hairbase", "hairfront", "hairside", "hairback", "jackets", "skin",
                         "eye", "eyebrow", "nose", "mouth", "socks", "shoes", "head", "neck", "eyewear"]
        categories.forEach { removeClothingItem(for: $0) }
    }

    private func loadBaseModel() {
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
            })
            .store(in: &cancellables)
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

    /// Efficiently change the color of a clothing item or base model, always using a single SimpleMaterial.
    private func changeItemColor(for entity: ModelEntity, to color: UIColor, categoryKey: String? = nil) {
        // Debounce rapid color changes for live preview
        let entityId = ObjectIdentifier(entity)
        colorChangeDebounceWorkItems[entityId]?.cancel()
        let workItem = DispatchWorkItem { [weak entity, weak self] in
            guard let entity = entity else { return }
            
            // Always use the base material
            if let baseMaterial = self?.baseMaterial {
                var newMaterial = baseMaterial
                newMaterial.baseColor = .color(color)
                entity.model?.materials = [newMaterial]
            }
            
            if let categoryKey = categoryKey, let self = self {
                self.chosenColors[categoryKey] = color
            }
        }
        colorChangeDebounceWorkItems[entityId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: workItem) // ~33 FPS
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
            "bottoms", "tops", "hairbase", "hairfront", "hairfront", "hairback", "jackets", "skin",
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

    // MARK: - Entity Management
    private func getOrCreateEntity(for modelName: String) async throws -> ModelEntity {
        // Check if entity exists in pool
        if let existingEntity = entityPool[modelName] {
            existingEntity.isEnabled = true
            activeEntities.insert(modelName)
            return existingEntity
        }
        
        // Create new entity
        let entity = try await AvatarResourceManager.shared.loadModelEntity(named: modelName)
        entity.name = modelName
        entityPool[modelName] = entity
        activeEntities.insert(modelName)
        return entity
    }
    
    private func hideEntity(for modelName: String) {
        if let entity = entityPool[modelName] {
            entity.isEnabled = false
            activeEntities.remove(modelName)
        }
    }
    
    private func cleanupInactiveEntities() {
        // Keep only the most recently used entities
        let maxPoolSize = 20  // Adjust based on your needs
        if entityPool.count > maxPoolSize {
            let inactiveEntities = entityPool.keys.filter { !activeEntities.contains($0) }
            for entityName in inactiveEntities.prefix(entityPool.count - maxPoolSize) {
                entityPool.removeValue(forKey: entityName)
            }
        }
    }

    // MARK: - Material Management
    private func getOrCreateMaterial(for color: UIColor, category: String) -> SimpleMaterial {
        let colorKey = color.toHexString() ?? "default"
        let materialKey = "\(category)_\(colorKey)"
        
        if let cachedMaterial = materialCache[materialKey] {
            return cachedMaterial
        }
        
        // Create material with optimized settings
        var material = SimpleMaterial(color: color, isMetallic: false)
        material.roughness = 0.5  // Reduce material complexity
        materialCache[materialKey] = material
        return material
    }

    // MARK: - Animation Management
    typealias AnimationBlock = () -> Void
    
    private func queueAnimation(for entityName: String, block: @escaping AnimationBlock) {
        animationQueue.async { [weak self] in
            guard let self = self else { return }
            var animations = self.pendingAnimations[entityName] ?? []
            animations.append(block)
            self.pendingAnimations[entityName] = animations
            
            // Process animations immediately for color changes
            if entityName == "skin" || entityName.contains("color") {
                self.processAnimations(for: entityName)
            }
            // Process other animations in batches
            else if animations.count >= 3 {
                self.processAnimations(for: entityName)
            }
        }
    }
    
    private func processAnimations(for entityName: String) {
        guard let animations = pendingAnimations[entityName] else { return }
        
        // Process animations on main thread with optimized batching
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Batch process animations
            autoreleasepool {
                for animation in animations {
                    animation()
                }
            }
            
            self.pendingAnimations[entityName] = []
        }
    }

    // MARK: - Optimized Clothing Item Management
    func loadClothingItem(named modelName: String, category: String) {
        Task {
            do {
                // Hide existing item in the same category
                if let existingModel = chosenModels[category] {
                    hideEntity(for: existingModel)
                }
                
                // Get or create new entity with optimized loading
                let entity = try await getOrCreateEntity(for: modelName)
                
                // Optimize entity settings
                entity.generateCollisionShapes(recursive: false)  // Disable collision generation
                entity.components[PhysicsBodyComponent.self] = nil  // Remove physics if not needed
                
                // Apply current color if exists
                if let color = chosenColors[category] {
                    let material = getOrCreateMaterial(for: color, category: category)
                    entity.model?.materials = [material]
                }
                
                // Add to scene if not already present
                if entity.parent == nil {
                    baseEntity?.addChild(entity)
                }
                
                // Update chosen models
                chosenModels[category] = modelName
                
                // Clean up inactive entities periodically
                cleanupInactiveEntities()
            } catch {
                print("Failed to load clothing item: \(error)")
            }
        }
    }
    
    func removeClothingItem(for category: String) {
        if let modelName = chosenModels[category] {
            hideEntity(for: modelName)
            chosenModels.removeValue(forKey: category)
        }
    }
    
    // MARK: - Optimized Color Change
    func changeClothingItemColor(for category: String, to color: UIColor) {
        guard let entity = entityPool[chosenModels[category] ?? ""] else { return }
        
        // Use optimized material application
        let material = getOrCreateMaterial(for: color, category: category)
        
        // Batch material updates
        queueAnimation(for: category) { [weak self] in
            entity.model?.materials = [material]
            self?.chosenColors[category] = color
        }
    }
    
    func changeSkinColor(to color: UIColor) {
        guard let baseEntity = baseEntity else { return }
        
        // Use optimized material application
        let material = getOrCreateMaterial(for: color, category: "skin")
        
        // Batch material updates
        queueAnimation(for: "skin") { [weak self] in
            baseEntity.model?.materials = [material]
            self?.chosenColors["skin"] = color
        }
    }
    
    // MARK: - Memory Management
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        cleanupInactiveEntities()
        materialCache.removeAll()
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
