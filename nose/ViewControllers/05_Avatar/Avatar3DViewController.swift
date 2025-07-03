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
            print("🎯 Avatar3DViewController - viewDidLoad started")
            setupARView()
            setupCameraPosition()
            addDirectionalLight()
            setupEnvironmentBackground()
            
            if !isPreviewMode {
                print("🎯 Loading avatar model in normal mode")
                loadAvatarModel()
            } else {
                print("🎯 Preview mode - base entity will be loaded when needed")
            }
            
            if !isPreviewMode {
                loadSelectionState()
            }
            
            print("🎯 Avatar3DViewController - viewDidLoad completed")
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
        print("🎯 setupBaseEntity called")
        print("   - baseEntity is nil: \(baseEntity == nil)")
        
        guard let baseEntity else { 
            print("❌ Base entity is nil, cannot setup")
            return 
        }
        
        print("✅ Base entity found, setting up...")
        clearBaseEntityAnchors()
        baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
        
        // Create material for base entity if not exists
        if categoryMaterials["skin"] == nil {
            var material = SimpleMaterial(color: .white, isMetallic: false)
            material.roughness = 0.5
            material.metallic = 0.0
            categoryMaterials["skin"] = material
            print("✅ Created skin material")
        }
        
        // Apply the material to the base entity
        if let material = categoryMaterials["skin"] {
            baseEntity.model?.materials = [material]
            print("✅ Applied skin material to base entity")
        }
        
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(baseEntity)
        arView.scene.anchors.append(anchor)
        print("✅ Base entity added to scene with anchor")
        print("   - Scene anchors count: \(arView.scene.anchors.count)")
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
        print("🎯 loadAvatarData called with preview mode")
        isPreviewMode = true
        clearAvatarState()
        
        if baseEntity == nil {
            print("🎯 Base entity is nil, loading base model first")
            loadBaseModel()
            // Apply avatar data after base model is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.applyAvatarData(avatarData)
            }
        } else {
            print("🎯 Base entity already exists, applying avatar data directly")
            applyAvatarData(avatarData)
        }
    }

    private func clearAvatarState() {
        chosenModels.removeAll()
        chosenColors.removeAll()
        
        AvatarCategory.all.forEach { removeAvatarPart(for: $0) }
    }

    private func loadBaseModel() {
        print("🎯 loadBaseModel called")
        
        // Try to load from bundle first
        if let bundleURL = Bundle.main.url(forResource: "body", withExtension: "usdz") {
            print("✅ Found body.usdz in bundle at: \(bundleURL.path)")
            
            Task { @MainActor in
                do {
                    let entity = try await ModelEntity(contentsOf: bundleURL)
                    print("✅ Entity loaded from bundle: \(entity)")
                    self.baseEntity = entity
                    print("   - Cast to ModelEntity successful: \(self.baseEntity != nil)")
                    
                    if let baseEntity = self.baseEntity {
                        baseEntity.name = "Avatar"
                        print("✅ Base entity name set to 'Avatar'")
                        self.setupBaseEntity()
                    } else {
                        print("❌ Failed to cast entity to ModelEntity")
                    }
                } catch {
                    print("❌ Error loading base avatar model from bundle: \(error)")
                    // Fallback to async method
                    self.loadBaseModelAsync()
                }
            }
        } else {
            print("❌ body.usdz not found in bundle, trying async method")
            loadBaseModelAsync()
        }
    }
    
    private func loadBaseModelAsync() {
        print("🎯 loadBaseModelAsync called")
        
        // Try to load from bundle using the modern API
        if let bundleURL = Bundle.main.url(forResource: "body", withExtension: "usdz") {
            print("✅ Found body.usdz in bundle at: \(bundleURL.path)")
            
            Task { @MainActor in
                do {
                    let entity = try await ModelEntity.loadModel(contentsOf: bundleURL)
                    print("✅ Entity loaded from bundle using loadModel: \(entity)")
                    self.baseEntity = entity
                    print("   - Cast to ModelEntity successful: \(self.baseEntity != nil)")
                    
                    if let baseEntity = self.baseEntity {
                        baseEntity.name = "Avatar"
                        print("✅ Base entity name set to 'Avatar'")
                        self.setupBaseEntity()
                    } else {
                        print("❌ Failed to cast entity to ModelEntity")
                    }
                } catch {
                    print("❌ Error loading base avatar model from bundle: \(error)")
                    // Final fallback to the old API
                    self.loadBaseModelLegacy()
                }
            }
        } else {
            print("❌ body.usdz not found in bundle")
            loadBaseModelLegacy()
        }
    }
    
    private func loadBaseModelLegacy() {
        print("🎯 loadBaseModelLegacy called - using Entity.loadModelAsync")
        Entity.loadModelAsync(named: "body")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Error loading base avatar model: \(error)")
                } else {
                    print("✅ Base model loading completed successfully")
                }
            }, receiveValue: { [weak self] entity in
                guard let self = self else { 
                    print("❌ Self is nil in loadBaseModel completion")
                    return 
                }
                
                print("✅ Entity loaded: \(entity)")
                self.baseEntity = entity as? ModelEntity
                print("   - Cast to ModelEntity successful: \(self.baseEntity != nil)")
                
                if let baseEntity = self.baseEntity {
                    baseEntity.name = "Avatar"
                    print("✅ Base entity name set to 'Avatar'")
                    self.setupBaseEntity()
                } else {
                    print("❌ Failed to cast entity to ModelEntity")
                }
            })
            .store(in: &cancellables)
    }

    private func applyAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        for (category, entry) in avatarData.selections {
            if let modelName = entry["model"] {
                chosenModels[category] = modelName
                loadAvatarPart(named: modelName, category: category)
            }
            
            if let colorString = entry["color"], let color = UIColor(hex: colorString) {
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
        print("🎯 loadAvatarModel called")
        let categories = AvatarCategory.all
        
        // Load chosen models from UserDefaults
        for category in categories {
            let key = "chosen\(category.capitalized)Model"
            if let modelName = UserDefaults.standard.string(forKey: key), !modelName.isEmpty {
                chosenModels[category] = modelName
                print("   - Loaded model for \(category): \(modelName)")
            }
        }

        // Load chosen colors from UserDefaults
        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors"),
           let savedColors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(savedColorsData) as? [String: UIColor] {
            chosenColors = savedColors
            print("   - Loaded \(savedColors.count) colors from UserDefaults")
        }

        print("🎯 Loading base entity model 'body'...")
        
        // Try to load from bundle first
        if let bundleURL = Bundle.main.url(forResource: "body", withExtension: "usdz") {
            print("✅ Found body.usdz in bundle at: \(bundleURL.path)")
            
            Task { @MainActor in
                do {
                    let entity = try await ModelEntity(contentsOf: bundleURL)
                    print("✅ Base entity loaded from bundle: \(entity)")
                    self.baseEntity = entity
                    print("   - Cast to ModelEntity successful: \(self.baseEntity != nil)")
                    
                    if let baseEntity = self.baseEntity {
                        baseEntity.name = "Avatar"
                        print("✅ Base entity name set to 'Avatar'")
                        self.setupBaseEntity()
                        
                        // Load additional avatar parts
                        for (category, modelName) in self.chosenModels where !modelName.isEmpty {
                            print("   - Loading avatar part: \(modelName) for \(category)")
                            self.loadAvatarPart(named: modelName, category: category)
                            if let color = self.chosenColors[category] {
                                self.changeAvatarPartColor(for: category, to: color)
                            }
                        }
                    } else {
                        print("❌ Failed to cast entity to ModelEntity")
                    }
                } catch {
                    print("❌ Error loading base avatar model from bundle: \(error)")
                    // Fallback to async method
                    self.loadBaseModelAsync()
                }
            }
        } else {
            print("❌ body.usdz not found in bundle, trying async method")
            loadBaseModelAsync()
        }
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

    // MARK: - Optimized Avatar Part Management
    func loadAvatarPart(named modelName: String, category: String) {
        print("🔄 Loading avatar part: \(modelName) for category: \(category)")
        Task {
            do {
                // Validate inputs
                guard !modelName.isEmpty else {
                    print("❌ Invalid model name")
                    return
                }
                
                // Hide existing item in the same category
                if let existingModel = chosenModels[category] {
                    print("👋 Hiding existing model: \(existingModel)")
                    hideEntity(for: existingModel)
                }
                
                // Get or create new entity with optimized loading
                let entity = try await getOrCreateEntity(for: modelName)
                print("✅ Created/retrieved entity for: \(modelName)")
                
                // Safely check model component
                guard let model = entity.model else {
                    print("❌ Entity has no model component")
                    return
                }
                
                print("🔍 Initial materials count: \(model.materials.count)")
                
                // Get the last selected color for this category or use white as default
                let lastColor = chosenColors[category] ?? .white
                
                // Create both materials
                var colorMaterial = SimpleMaterial(color: lastColor, isMetallic: false)
                colorMaterial.roughness = 0.5
                colorMaterial.metallic = 0.0
                
                var whiteMaterial = SimpleMaterial(color: .white, isMetallic: false)
                whiteMaterial.roughness = 0.5
                whiteMaterial.metallic = 0.0
                
                // Safely apply materials
                do {
                    entity.model?.materials = [colorMaterial, whiteMaterial]
                    print("✅ Applied initial materials:")
                    print("   - First material: \(lastColor)")
                    print("   - Second material: white")
                } catch {
                    print("❌ Failed to apply materials: \(error)")
                    return
                }
                
                // Store the color material in category materials
                categoryMaterials[category] = colorMaterial
                
                // Queue scene update
                queueSceneUpdate { [weak self] in
                    guard let self = self else { return }
                    
                    // Add to scene if not already present
                    if entity.parent == nil {
                        self.baseEntity?.addChild(entity)
                        print("✅ Added entity to scene")
                    }
                }
                
                // Update chosen models
                chosenModels[category] = modelName
                print("✅ Updated chosen models")
                
                // Clean up inactive entities periodically
                cleanupInactiveEntities()
            } catch {
                print("❌ Failed to load avatar part: \(error)")
            }
        }
    }
    
    func removeAvatarPart(for category: String) {
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
    func changeAvatarPartColor(for category: String, to color: UIColor) {
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
        print("\n🎨 Starting material color update for category: \(category)")
        print("   - Target color: \(color)")
        
        // Validate inputs
        guard !category.isEmpty else {
            print("❌ Invalid category")
            return
        }
        
        materialUpdateQueue.async { [weak self] in
            guard let self = self else {
                print("❌ Self is nil")
                return
            }
            
            // Create new material with updated color
            var newMaterial = SimpleMaterial(color: color, isMetallic: false)
            newMaterial.roughness = 0.5
            newMaterial.metallic = 0.0
            
            // Create fixed white material for second slot
            var whiteMaterial = SimpleMaterial(color: .white, isMetallic: false)
            whiteMaterial.roughness = 0.5
            whiteMaterial.metallic = 0.0
            
            print("✅ Created materials:")
            print("   - New color material: \(color)")
            print("   - White material: white")
            
            // Update category material
            self.categoryMaterials[category] = newMaterial
            
            // Queue scene update to apply the change
            self.queueSceneUpdate { [weak self] in
                guard let self = self else {
                    print("❌ Self is nil in scene update")
                    return
                }
                
                // Ensure we're on the main queue for material operations
                DispatchQueue.main.async {
                
                if category == "skin" {
                    // Update base entity material
                    if let baseEntity = self.baseEntity {
                        do {
                            baseEntity.model?.materials = [newMaterial]
                            print("✅ Applied skin material to base entity")
                        } catch {
                            print("❌ Failed to apply skin material: \(error)")
                        }
                    } else {
                        print("❌ Base entity is nil")
                    }
                } else {
                    // For all other categories, use two materials
                    guard let modelName = self.chosenModels[category] else {
                        print("❌ No model name found for category: \(category)")
                        print("   - Available categories: \(self.chosenModels.keys.joined(separator: ", "))")
                        return
                    }
                    
                    print("📦 Looking for entity with model name: \(modelName)")
                    
                    guard let entity = self.entityPool[modelName] else {
                        print("❌ Entity not found in pool for model: \(modelName)")
                        print("   - Available models in pool: \(self.entityPool.keys.joined(separator: ", "))")
                        return
                    }
                    
                    print("✅ Found entity in pool")
                    
                    guard let model = entity.model else {
                        print("❌ Entity has no model component")
                        return
                    }
                    
                    print("🔍 Current materials count: \(model.materials.count)")
                    
                    // First material is color-changing, second is fixed white
                    do {
                        // Safely assign materials with bounds checking
                        let materialsArray = [newMaterial, whiteMaterial]
                        entity.model?.materials = materialsArray
                        print("✅ Applied new materials to entity")
                        
                        // Verify material assignment with additional safety
                        guard let updatedModel = entity.model else {
                            print("❌ Model component is nil after assignment")
                            return
                        }
                        
                        print("🔍 Materials array count: \(materialsArray.count)")
                        print("🔍 Updated model materials count: \(updatedModel.materials.count)")
                        
                        // Verify material assignment
                        if let updatedModel = entity.model {
                            print("🔍 Final materials state:")
                            print("   - Materials count: \(updatedModel.materials.count)")
                            if let firstMaterial = updatedModel.materials.first as? SimpleMaterial {
                                print("   - First material color: \(firstMaterial.color)")
                            }
                            if updatedModel.materials.count > 1 {
                                let secondMaterial = updatedModel.materials[1] as? SimpleMaterial
                                if let color = secondMaterial?.color {
                                    print("   - Second material color: \(color)")
                                } else {
                                    print("   - Second material has no color")
                                }
                            } else {
                                print("   - No second material available")
                            }
                        }
                    } catch {
                        print("❌ Failed to apply materials: \(error)")
                    }
                }
                } // Close DispatchQueue.main.async
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
