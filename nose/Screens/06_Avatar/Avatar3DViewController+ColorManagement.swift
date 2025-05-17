import UIKit
import RealityKit
import Combine

extension Avatar3DViewController {

    /// Only updates the color if it is different
    func changeClothingItemColor(for category: String, to color: UIColor, materialIndex: Int = 0) {
        guard let entity = activeModelEntities[category] else {
            return
        }
        
        // Check if current color is already the target color
        if let currentMaterial = entity.model?.materials[safe: materialIndex] as? SimpleMaterial,
           currentMaterial.baseColor.tintedColor == color {
            // If chosenColors isn't set, set it. Otherwise, colors match, do nothing.
            if chosenColors[category] == nil {
                 chosenColors[category] = color
            }
            return
        }

        var newMaterial = SimpleMaterial()
        newMaterial.baseColor = .color(color)
        newMaterial.roughness = MaterialScalarParameter(floatLiteral: 1.0)
        newMaterial.metallic = MaterialScalarParameter(floatLiteral: 0.0)

        if entity.model != nil {
            if entity.model!.materials.indices.contains(materialIndex) {
                entity.model!.materials[materialIndex] = newMaterial
            } else if materialIndex == 0 {
                // If trying to set the first material, and it doesn't exist, assign/append it.
                entity.model!.materials = [newMaterial]
            } else {
                 print("Warning: Material index \(materialIndex) out of bounds for category \(category) and not index 0.")
                return // Don't update chosenColors if we can't apply the material
            }
            chosenColors[category] = color // Update the chosen color state
        } else {
            print("Warning: Entity for category \(category) has no model component.")
        }
    }

    func changeSkinColor(to color: UIColor, materialIndex: Int = 0) {
        guard let baseEntity = baseEntity else { return }
        
        if let currentMaterial = baseEntity.model?.materials[safe: materialIndex] as? SimpleMaterial,
           currentMaterial.baseColor.tintedColor == color {
            // If chosenColors["skin"] isn't set, set it. Otherwise, colors match, do nothing.
            // Assuming skin color is also tracked in chosenColors for persistence and consistency
            if chosenColors["skin"] == nil {
                 chosenColors["skin"] = color
            }
            return
        }

        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)

        if baseEntity.model != nil {
            if baseEntity.model!.materials.indices.contains(materialIndex) {
                baseEntity.model!.materials[materialIndex] = material
            } else if materialIndex == 0 {
                baseEntity.model!.materials = [material]
            }
            chosenColors["skin"] = color // Update chosen color for skin
        } else {
            print("Warning: Base entity has no model component for skin color.")
        }
    }
} 