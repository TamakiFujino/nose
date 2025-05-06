import RealityKit
import UIKit

class AvatarRenderer {
    static func renderSavedAvatar(in arView: ARView) {
        do {
            let baseEntity = try Entity.loadModel(named: "body") as? ModelEntity
            baseEntity?.name = "Avatar"
            baseEntity?.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])

            let anchor = AnchorEntity(world: [0, 0, 0])
            if let baseEntity = baseEntity {
                anchor.addChild(baseEntity)

                let savedModels = loadSavedModelNames()
                let savedColors = loadSavedColors()

                for (category, modelName) in savedModels {
                    if !modelName.isEmpty {
                        if let clothingEntity = try? Entity.loadModel(named: modelName) as? ModelEntity {
                            clothingEntity.name = modelName
                            clothingEntity.scale = [1, 1, 1]
                            baseEntity.addChild(clothingEntity)

                            if let color = savedColors[category] {
                                applyColor(to: clothingEntity, color: color)
                            }
                        }
                    }
                }

                if let skinColor = savedColors["skin"], let model = baseEntity.model {
                    var material = SimpleMaterial()
                    material.baseColor = .color(skinColor)
                    material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
                    material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
                    var materials = model.materials
                    if !materials.isEmpty {
                        materials[0] = material
                        baseEntity.model?.materials = materials
                    }
                }
            }

            arView.scene.anchors.append(anchor)
        } catch {
            //print("\u274c Failed to load avatar preview: \(error)")
        }
    }

    private static func loadSavedModelNames() -> [String: String] {
        var modelDict: [String: String] = [
            "bottoms": "", "tops": "", "hair_base": "", "hair_front": "", "hair_back": "",
            "jackets": "", "skin": "", "eye": "", "eyebrow": "", "nose": "",
            "mouth": "", "socks": "", "shoes": "", "head": "", "neck": "", "eyewear": ""
        ]
        for category in modelDict.keys {
            if let model = UserDefaults.standard.string(forKey: "chosen\(category.capitalized)Model") {
                modelDict[category] = model
            }
        }
        return modelDict
    }

    private static func loadSavedColors() -> [String: UIColor] {
        if let data = UserDefaults.standard.data(forKey: "chosenColors"),
           let colors = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: UIColor] {
            return colors
        }
        return [:]
    }

    private static func applyColor(to entity: ModelEntity, color: UIColor) {
        var material = SimpleMaterial()
        material.baseColor = .color(color)
        material.roughness = MaterialScalarParameter(floatLiteral: 1.0)
        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
        if var materials = entity.model?.materials {
            materials[0] = material
            entity.model?.materials = materials
        }
    }
}
