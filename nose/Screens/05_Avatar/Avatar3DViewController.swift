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
    private var categoryMaterials: [String: SimpleMaterial] = [:]  // Materials for each category
    private var entityPool: [String: ModelEntity] = [:]  // Pool of reusable entities
    private var activeEntities: Set<String> = []  // Track currently active entities
    private var materialCache: [String: SimpleMaterial] = [:]  // Cache for materials
    private var animationQueue = DispatchQueue(label: "com.avatar.animation", qos: .userInteractive)
    private var pendingAnimations: [String: [AnimationBlock]] = [:]
    private var materialUpdateQueue = DispatchQueue(label: "com.avatar.material", qos: .userInteractive)
    private var lastMaterialUpdate: [String: Date] = [:]
    private let materialUpdateThrottle: TimeInterval = 0.016 // ~60 FPS
    private var sceneUpdateQueue = DispatchQueue(label: "com.avatar.scene", qos: .userInteractive)
    private var pendingSceneUpdates: [() -> Void] = []
    private var isProcessingSceneUpdates = false

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
        
        // Create material for base entity if not exists
        if categoryMaterials["skin"] == nil {
            var material = SimpleMaterial(color: .white, isMetallic: false)
            material.roughness = 0.5
            material.metallic = 0.0
            categoryMaterials["skin"] = material
        }
        
        // Apply the material to the base entity
        if let material = categoryMaterials["skin"] {
            baseEntity.model?.materials = [material]
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
        
        AvatarCategory.all.forEach { removeClothingItem(for: $0) }
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
        
        // Create new entity with optimized settings
        let entity = try await AvatarResourceManager.shared.loadModelEntity(named: modelName)
        entity.name = modelName
        
        // Optimize entity settings
        entity.generateCollisionShapes(recursive: false)
        entity.components[PhysicsBodyComponent.self] = nil
        
        // Optimize model settings
        if let model = entity.model {
            let optimizedMaterials = model.materials.map { material -> Material in
                if var simpleMaterial = material as? SimpleMaterial {
                    simpleMaterial.roughness = 0.5
                    simpleMaterial.metallic = 0.2
                    return simpleMaterial
                }
                return material
            }
            // Create a new model with optimized materials
            let optimizedModel = ModelComponent(mesh: model.mesh, materials: optimizedMaterials)
            entity.model = optimizedModel
        }
        
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
    private func getOrCreateMaterial(for category: String) -> SimpleMaterial {
        if let existingMaterial = categoryMaterials[category] {
            return existingMaterial
        }
        
        // Create new material with default settings
        var material = SimpleMaterial(color: .white, isMetallic: false)
        material.roughness = 0.5
        material.metallic = 0.0
        categoryMaterials[category] = material
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

    // MARK: - Scene Management
    private func queueSceneUpdate(_ update: @escaping () -> Void) {
        sceneUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingSceneUpdates.append(update)
            self.processSceneUpdates()
        }
    }
    
    private func processSceneUpdates() {
        guard !isProcessingSceneUpdates else { return }
        isProcessingSceneUpdates = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                let updates = self.pendingSceneUpdates
                self.pendingSceneUpdates.removeAll()
                
                for update in updates {
                    update()
                }
            }
            
            self.isProcessingSceneUpdates = false
            
            // Process any new updates that came in while we were processing
            if !self.pendingSceneUpdates.isEmpty {
                self.processSceneUpdates()
            }
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
                
                // Apply category material
                let material = getOrCreateMaterial(for: category)
                entity.model?.materials = [material]
                
                // Queue scene update
                queueSceneUpdate { [weak self] in
                    // Add to scene if not already present
                    if entity.parent == nil {
                        self?.baseEntity?.addChild(entity)
                    }
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
        guard AvatarCategory.isValid(category) else {
            print("❌ Invalid category: \(category)")
            return
        }
        if let modelName = chosenModels[category] {
            hideEntity(for: modelName)
            chosenModels.removeValue(forKey: category)
        }
    }
    
    // MARK: - Optimized Color Change
    func changeClothingItemColor(for category: String, to color: UIColor) {
        // Throttle material updates
        let now = Date()
        if let lastUpdate = lastMaterialUpdate[category],
           now.timeIntervalSince(lastUpdate) < materialUpdateThrottle {
            return
        }
        lastMaterialUpdate[category] = now
        
        // Update the category material color
        updateMaterialColor(for: category, to: color)
        
        // Update chosen colors
        chosenColors[category] = color
    }
    
    func changeSkinColor(to color: UIColor) {
        // Throttle material updates
        let now = Date()
        if let lastUpdate = lastMaterialUpdate["skin"],
           now.timeIntervalSince(lastUpdate) < materialUpdateThrottle {
            return
        }
        lastMaterialUpdate["skin"] = now
        
        // Update the skin material color
        updateMaterialColor(for: "skin", to: color)
        
        // Update chosen colors
        chosenColors["skin"] = color
    }
    
    // MARK: - Memory Management
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        cleanupInactiveEntities()
        materialCache.removeAll()
        lastMaterialUpdate.removeAll()
    }

    // MARK: - Material Management
    private func updateMaterialColor(for category: String, to color: UIColor) {
        materialUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create new material with updated color
            var newMaterial = SimpleMaterial(color: color, isMetallic: false)
            newMaterial.roughness = 0.5
            newMaterial.metallic = 0.0
            
            // Update category material
            self.categoryMaterials[category] = newMaterial
            
            // Queue scene update to apply the change
            self.queueSceneUpdate { [weak self] in
                guard let self = self else { return }
                
                if category == "skin" {
                    // Update base entity material
                    if let baseEntity = self.baseEntity {
                        baseEntity.model?.materials = [newMaterial]
                    }
                } else {
                    // Update only the entities in this category
                    if let modelName = self.chosenModels[category],
                       let entity = self.entityPool[modelName] {
                        entity.model?.materials = [newMaterial]
                    }
                }
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
