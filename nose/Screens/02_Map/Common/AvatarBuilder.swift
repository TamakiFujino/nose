import RealityKit
import UIKit

struct AvatarBuilder {
    static func buildAvatar(for userId: String) -> ModelEntity? {
        guard let baseEntity = try? Entity.loadModel(named: "body") as? ModelEntity else {
            print("❌ Failed to load base model")
            return nil
        }

        // Load chosenModels
        var chosenModels: [String: String] = [:]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            if key.hasPrefix("chosenModels_\(userId)_"),
               let modelName = value as? String {
                let category = key.replacingOccurrences(of: "chosenModels_\(userId)_", with: "")
                chosenModels[category] = modelName
            }
        }

        // Load chosenColors
        var chosenColors: [String: UIColor] = [:]
        if let colorData = UserDefaults.standard.data(forKey: "chosenColors_\(userId)"),
           let colors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(colorData) as? [String: UIColor] {
            chosenColors = colors
        }

        // Attach clothing models and colors
        for (category, modelName) in chosenModels {
            if let clothing = try? Entity.loadModel(named: modelName) as? ModelEntity {
                clothing.name = modelName
                clothing.scale = SIMD3<Float>(repeating: 1.0)
                baseEntity.addChild(clothing)

                if let color = chosenColors[category] {
                    var material = SimpleMaterial()
                    material.baseColor = .color(color)
                    material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
                    material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
                    clothing.model?.materials = [material]
                }
            }
        }

        return baseEntity
    }
}
