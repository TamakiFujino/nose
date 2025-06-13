import RealityKit
import UIKit

final class AvatarMaterialManager {
    static let shared = AvatarMaterialManager()
    private init() {}
    
    private var materialCache: [String: SimpleMaterial] = [:]
    private var categoryMaterials: [String: SimpleMaterial] = [:]
    private let materialUpdateQueue = DispatchQueue(label: "com.avatar.material", qos: .userInteractive)
    private var lastMaterialUpdate: [String: Date] = [:]
    private let materialUpdateThrottle: TimeInterval = 0.016 // ~60 FPS
    
    // MARK: - Public Interface
    
    func getMaterial(for category: String) -> SimpleMaterial? {
        return categoryMaterials[category]
    }
    
    func createMaterial(color: UIColor, isMetallic: Bool = false) -> SimpleMaterial {
        let key = "\(color.toHexString() ?? "")_\(isMetallic)"
        if let cachedMaterial = materialCache[key] {
            return cachedMaterial
        }
        
        var material = SimpleMaterial(color: color, isMetallic: isMetallic)
        material.roughness = 0.5
        material.metallic = isMetallic ? 0.8 : 0.0
        materialCache[key] = material
        return material
    }
    
    func updateMaterial(for category: String, color: UIColor, isMetallic: Bool = false) {
        let material = createMaterial(color: color, isMetallic: isMetallic)
        categoryMaterials[category] = material
    }
    
    func applyMaterial(_ material: SimpleMaterial, to entity: ModelEntity) {
        guard let model = entity.model else { return }
        // Create a new model with the updated materials
        let newModel = ModelComponent(mesh: model.mesh, materials: [material])
        entity.model = newModel
    }
    
    func clearCache() {
        materialCache.removeAll()
        categoryMaterials.removeAll()
        lastMaterialUpdate.removeAll()
    }
    
    // MARK: - Throttled Updates
    
    func shouldUpdateMaterial(for category: String) -> Bool {
        let now = Date()
        if let lastUpdate = lastMaterialUpdate[category] {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < materialUpdateThrottle {
                return false
            }
        }
        lastMaterialUpdate[category] = now
        return true
    }
} 