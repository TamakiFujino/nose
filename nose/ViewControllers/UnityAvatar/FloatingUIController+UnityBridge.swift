import UIKit

// MARK: - Unity Communication
extension FloatingUIController {

    // MARK: - Category Mapping

    // Mapping from display category to Unity category for compatibility
    // Can work with or without current tab context (for loading saved data)
    private func getUnityCategory(displayCategory: String) -> String {
        // Check if this is a face tab category
        if displayCategory == "Base" || displayCategory == "Hair" || displayCategory == "Make Up" {
            switch displayCategory {
            case "Base": return "Base"
            case "Hair": return "Hair"
            case "Make Up": return "Base"  // Make up is part of Base category in Unity
            default: return displayCategory
            }
        }
        // Check if this is a clothes tab category
        if displayCategory == "Clothes" || displayCategory == "Accessories" {
            return displayCategory  // These map directly
        }
        // Fallback: use current tab if available, otherwise return as-is
        switch selectedCategoryTab {
        case .face:
            switch displayCategory {
            case "Base": return "Base"
            case "Hair": return "Hair"
            case "Make Up": return "Base"
            default: return displayCategory
            }
        case .clothes:
            switch displayCategory {
            case "Clothes": return "Clothes"
            case "Accessories": return "Accessories"
            default: return displayCategory
            }
        }
    }

    private func getUnitySubcategory(displayCategory: String, displaySubcategory: String) -> String {
        // Check if this is a face tab category
        if displayCategory == "Base" || displayCategory == "Hair" || displayCategory == "Make Up" {
            switch displayCategory {
            case "Base":
                return displaySubcategory  // Body, Eye, Eyebrow map directly
            case "Hair":
                return displaySubcategory  // Base, Front, Side, Back, Arrange map directly
            case "Make Up":
                // Map make up subcategories
                switch displaySubcategory {
                case "Eyeshadow": return "Eyeshadow"
                case "Blush": return "Blush"
                default: return displaySubcategory
                }
            default:
                return displaySubcategory
            }
        }
        // Clothes tab categories map directly
        return displaySubcategory
    }

    // MARK: - Send Commands to Unity

    func sendSelectedColorToUnity(hex: String) {
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        sendColorToUnity(category: parent, subcategory: child, hex: hex)
    }

    func sendColorToUnity(category: String, subcategory: String, hex: String) {
        // Convert display category/subcategory to Unity category/subcategory
        let unityCategory = getUnityCategory(displayCategory: category)
        let unitySubcategory = getUnitySubcategory(displayCategory: category, displaySubcategory: subcategory)

        let payload: [String: Any] = [
            "category": unityCategory,
            "subcategory": unitySubcategory,
            "colorHex": hex
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ChangeColor", message: json)
        }
    }

    func sendRemoveAssetToUnity(category: String, subcategory: String) {
        // Convert display category/subcategory to Unity category/subcategory
        let unityCategory = getUnityCategory(displayCategory: category)
        let unitySubcategory = getUnitySubcategory(displayCategory: category, displaySubcategory: subcategory)

        let payload: [String: Any] = [
            "category": unityCategory,
            "subcategory": unitySubcategory,
            "callbackId": UUID().uuidString
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "RemoveAsset", message: json)
        }
    }

    func sendResetBodyPose() {
        UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ResetBodyPose", message: "")
    }

    func changeAssetInUnity(asset: AssetItem) {
        // Convert display category/subcategory to Unity category/subcategory
        let unityCategory = getUnityCategory(displayCategory: asset.category)
        let unitySubcategory = getUnitySubcategory(displayCategory: asset.category, displaySubcategory: asset.subcategory)

        var assetInfo: [String: Any] = [
            "id": asset.id,
            "name": asset.name,
            "category": unityCategory,
            "subcategory": unitySubcategory
        ]
        if !asset.modelPath.isEmpty {
            assetInfo["modelPath"] = asset.modelPath
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: assetInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ChangeAsset", message: jsonString)
        }
    }

    func setSlotVisibilityInUnity(category: String, subcategory: String, visible: Bool) {
        // Convert display category/subcategory to Unity category/subcategory
        let unityCategory = getUnityCategory(displayCategory: category)
        let unitySubcategory = getUnitySubcategory(displayCategory: category, displaySubcategory: subcategory)

        let payload: [String: Any] = [
            "category": unityCategory,
            "subcategory": unitySubcategory,
            "visible": visible
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "SetCategoryVisibility", message: json)
        }
    }

    // MARK: - Selection Sync

    private func slotHasSelection(category: String, subcategory: String) -> Bool {
        let key = "\(category)_\(subcategory)"
        if category.lowercased() == "base" && subcategory.lowercased() == "body" {
            let pose = selections[key]? ["pose"] ?? selections[key]? ["model"]
            return (pose != nil && !(pose!.isEmpty))
        } else {
            let model = selections[key]? ["model"]
            return (model != nil && !(model!.isEmpty))
        }
    }

    func syncUnityRemovalsWithSelections() {
        for (pi, parent) in parentCategories.enumerated() {
            for child in childCategories[pi] {
                let key = "\(parent)_\(child)"
                let entry = selections[key]
                if parent.lowercased() == "base" && child.lowercased() == "body" {
                    // If no pose, reset body pose
                    let pose = entry? ["pose"] ?? entry? ["model"]
                    if pose == nil || pose == "" { sendResetBodyPose() }
                } else {
                    // If no model, ensure item removed
                    let model = entry? ["model"]
                    if model == nil || model == "" { sendRemoveAssetToUnity(category: parent, subcategory: child) }
                }
            }
        }
    }

    // MARK: - Public reset helpers
    func resetAllSlotsInUnity() {
        // Clear Unity state for ALL slots across BOTH tabs.
        // This is important because selectedCategoryTab defaults to .clothes, and we still need to clear face/makeup slots
        // so a new customization session doesn't inherit state from the previous one.
        let allSlots: [(parent: String, children: [String])] = [
            ("Base", ["Body", "Eye", "Eyebrow"]),
            ("Hair", ["Base", "Front", "Side", "Back", "Arrange"]),
            ("Make Up", ["Eyeshadow", "Blush"]),
            ("Clothes", ["Tops", "Bottoms", "Socks"]),
            ("Accessories", ["Headwear", "Neckwear"])
        ]
        for slot in allSlots {
            for child in slot.children {
                if slot.parent.lowercased() == "base" && child.lowercased() == "body" {
                    sendResetBodyPose()
                    // Reset skin color too; otherwise Unity keeps the previous session's material color.
                    let defaultHex = colorSwatches.first ?? "#FFFFFF"
                    sendColorToUnity(category: slot.parent, subcategory: child, hex: defaultHex)
                } else {
                    sendRemoveAssetToUnity(category: slot.parent, subcategory: child)
                }
                // Makeup is color-driven, so also force it off.
                if slot.parent == "Make Up" {
                    sendColorToUnity(category: slot.parent, subcategory: child, hex: "#000000")
                }
            }
        }
        // Clear local selection state
        selections.removeAll()
        currentTopIndex = -1
        updateThumbnailBorders()
    }

    // MARK: - Apply Selections

    func applySelectionForCurrentCategory() {
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        let key = "\(parent)_\(child)"
        guard let entry = selections[key] else {
            // If Base/Body has no saved selection, apply default pose without selecting any thumbnail
            if parent.lowercased() == "base" && child.lowercased() == "body" {
                // Reset to default A-pose on Unity side
                UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ResetBodyPose", message: "")
            }
            return
        }
        // Preselect model/pose if available
        let desiredName: String?
        if parent.lowercased() == "base" && child.lowercased() == "body" {
            desiredName = entry["pose"] ?? entry["model"]
        } else {
            desiredName = entry["model"]
        }
        if let name = desiredName, let idx = currentAssets.firstIndex(where: { $0.name == name }) {
            currentTopIndex = idx
            updateThumbnailBorders()
            changeAssetInUnity(asset: currentAssets[idx])
        }
        // Apply color if available
        if let hex = entry["color"], !hex.isEmpty {
            sendSelectedColorToUnity(hex: hex)
        }
    }

    private func defaultBodyPoseName() -> String? {
        if let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
           let explicit = plistDict["DefaultBodyPose"] as? String,
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicit.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    // MARK: - External API
    func applyInitialSelections(_ newSelections: [String: [String: String]]) {
        // Update and re-apply UI/Unity once data and UI are ready
        initialSelections = newSelections
        selections = newSelections
        // If assets are already loaded for current category, this will preselect and apply
        updateThumbnailsForCategory()
        // Proactively apply all saved selections to Unity so items appear without tab taps
        applyAllSelectionsToUnity()
    }

    func applyAllSelectionsToUnity() {
        for (key, entry) in selections {
            let parts = key.split(separator: "_").map(String.init)
            guard parts.count == 2 else { continue }
            let displayCategory = parts[0]
            let displaySubcategory = parts[1]

            // Convert display category/subcategory to Unity category/subcategory for Unity communication
            let unityCategory = getUnityCategory(displayCategory: displayCategory)
            let unitySubcategory = getUnitySubcategory(displayCategory: displayCategory, displaySubcategory: displaySubcategory)

            // Check if this is a color-only entry (like Blush, Eyeshadow) that doesn't have a model
            // NOTE: Base/Body is NOT color-only because we also need to apply the body pose.
            let isColorOnly = (displayCategory == "Make Up" && (displaySubcategory == "Blush" || displaySubcategory == "Eyeshadow"))

            // Apply model/asset if available
            if displayCategory.lowercased() == "base" && displaySubcategory.lowercased() == "body" {
                // Base/Body uses "pose" (or "model") as the pose name.
                let poseName = (entry["pose"] ?? entry["model"])?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let poseName, !poseName.isEmpty {
                    let asset = AssetItem(
                        id: "\(unityCategory)_\(unitySubcategory)_\(poseName)",
                        name: poseName,
                        modelPath: "",
                        thumbnailPath: nil,
                        category: unityCategory,
                        subcategory: unitySubcategory,
                        isActive: true,
                        metadata: nil
                    )
                    changeAssetInUnity(asset: asset)
                } else if let def = defaultBodyPoseName(), !def.isEmpty {
                    let asset = AssetItem(
                        id: "\(unityCategory)_\(unitySubcategory)_\(def)",
                        name: def,
                        modelPath: "",
                        thumbnailPath: nil,
                        category: unityCategory,
                        subcategory: unitySubcategory,
                        isActive: true,
                        metadata: nil
                    )
                    changeAssetInUnity(asset: asset)
                } else {
                    sendResetBodyPose()
                }
            } else if !isColorOnly {
                let name = entry["model"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let modelName = name, !modelName.isEmpty {
                    let modelPath = "Models/\(unityCategory)/\(unitySubcategory)/\(modelName)"
                    let asset = AssetItem(
                        id: "\(unityCategory)_\(unitySubcategory)_\(modelName)",
                        name: modelName,
                        modelPath: modelPath,
                        thumbnailPath: nil,
                        category: unityCategory,
                        subcategory: unitySubcategory,
                        isActive: true,
                        metadata: nil
                    )
                    changeAssetInUnity(asset: asset)
                }
            }

            // Apply color (for all entries including color-only ones like Blush/Eyeshadow)
            if displayCategory == "Make Up" && (displaySubcategory == "Blush" || displaySubcategory == "Eyeshadow") {
                let enabled = entry["enabled"]?.lowercased() == "true"
                if enabled, let hex = entry["color"], !hex.isEmpty {
                    sendColorToUnity(category: unityCategory, subcategory: unitySubcategory, hex: hex)
                } else {
                    // Disabled -> remove effect (shader uses Add, black = no effect)
                    sendColorToUnity(category: unityCategory, subcategory: unitySubcategory, hex: "#000000")
                }
            } else if let hex = entry["color"], !hex.isEmpty {
                sendColorToUnity(category: unityCategory, subcategory: unitySubcategory, hex: hex)
            } else if isColorOnly, let defaultHex = colorSwatches.first {
                // For color-only entries, apply default if no saved color
                sendColorToUnity(category: unityCategory, subcategory: unitySubcategory, hex: defaultHex)
                var updated = selections[key] ?? [:]
                updated["color"] = defaultHex
                selections[key] = updated
            }
        }
    }
}
