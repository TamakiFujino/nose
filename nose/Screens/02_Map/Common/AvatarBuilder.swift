import RealityKit
import UIKit

struct AvatarBuilder {
    static func buildAvatar(for userId: String) -> ModelEntity? {
        do {
            guard let baseEntity = try Entity.loadModel(named: "body") as? ModelEntity else {
                print("❌ Loaded entity is not a ModelEntity")
                return nil
            }
            print("✅ Successfully loaded base model 'body'")

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
                do {
                    let clothing = try Entity.loadModel(named: modelName) as! ModelEntity
                    clothing.name = modelName
                    clothing.scale = SIMD3<Float>(repeating: 1.0)
                    baseEntity.addChild(clothing)
                    print("✅ Loaded model for category '\(category)': \(modelName)")

                    if let color = chosenColors[category] {
                        var material = SimpleMaterial()
                        material.baseColor = .color(color)
                        material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
                        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
                        clothing.model?.materials = [material]
                    }
                } catch {
                    print("❌ Failed to load model for category '\(category)': \(modelName), error: \(error)")
                }
            }

            return baseEntity
        } catch {
            print("❌ Error loading base model 'body': \(error)")
            return nil
        }
    }

    func buildAvatar(from outfit: AvatarOutfit, into root: Entity) {
        let categories = [
            ("bottoms", outfit.bottoms),
            ("tops", outfit.tops),
            ("hair_base", outfit.hairBase),
            ("hair_front", outfit.hairFront),
            ("hair_back", outfit.hairBack),
            ("jackets", outfit.jackets),
            ("skin", outfit.skin),
            ("eye", outfit.eye),
            ("eyebrow", outfit.eyebrow),
            ("nose", outfit.nose),
            ("mouth", outfit.mouth),
            ("socks", outfit.socks),
            ("shoes", outfit.shoes),
            ("head", outfit.head),
            ("neck", outfit.neck),
            ("eyewear", outfit.eyewear)
        ]

        for (category, modelName) in categories where !modelName.isEmpty {
            do {
                let item = try Entity.loadModel(named: modelName)
                item.name = modelName
                root.addChild(item)
                print("✅ Loaded model for category '\(category)': \(modelName)")
            } catch {
                print("❌ Failed to load model for category '\(category)': \(modelName), error: \(error)")
            }
        }
    }
}
