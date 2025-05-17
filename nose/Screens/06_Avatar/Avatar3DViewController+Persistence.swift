import UIKit
import RealityKit
import Combine

extension Avatar3DViewController {

    func saveChosenModelsAndColors() -> Bool {
        return saveChosenModelsAndColors(for: currentUserId)
    }

    func saveChosenModelsAndColors(for userId: String) -> Bool {
        for (category, modelName) in chosenModels {
            let key = "chosenModels_\(userId)_\(category)"
            UserDefaults.standard.set(modelName, forKey: key)
        }
        do {
            let colorsData = try NSKeyedArchiver.archivedData(withRootObject: chosenColors, requiringSecureCoding: false)
            UserDefaults.standard.set(colorsData, forKey: "chosenColors_\(userId)")
            print("✅ Saved models and colors for userId: \(userId)")
            return true
        } catch {
            print("❌ Failed to archive colors for userId \(userId): \(error)")
            return false
        }
    }

    func loadSelectionState() {
        if let savedSelection = UserDefaults.standard.object(forKey: "selectedItem") {
            self.selectedItem = savedSelection
            updateUIForSelectedItem()
        } else {
            self.selectedItem = nil
            updateUIForNoSelection()
        }
    }

    func saveImage(image: UIImage, toDirectory directory: String) {
        guard let data = image.pngData() else {
            print("❌ Failed to convert image to PNG data.")
            return
        }
        let fileManager = FileManager.default
        do {
            let documentsURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let directoryURL = documentsURL.appendingPathComponent(directory)
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            let filename = "avatar_\(UUID().uuidString).png"
            let fileURL = directoryURL.appendingPathComponent(filename)
            try data.write(to: fileURL)
            print("✅ Image saved successfully to \(fileURL.path)")
        } catch {
            print("❌ Error saving image: \(error)")
        }
    }

    func exportCurrentOutfitAsAvatarOutfit() -> AvatarOutfit {
        return AvatarOutfit(
            bottoms: chosenModels["bottoms"] ?? "",
            tops: chosenModels["tops"] ?? "",
            hairBase: chosenModels["hair_base"] ?? "",
            hairFront: chosenModels["hair_front"] ?? "",
            hairBack: chosenModels["hair_back"] ?? "",
            jackets: chosenModels["jackets"] ?? "",
            skin: chosenModels["skin"] ?? "",
            eye: chosenModels["eye"] ?? "",
            eyebrow: chosenModels["eyebrow"] ?? "",
            nose: chosenModels["nose"] ?? "",
            mouth: chosenModels["mouth"] ?? "",
            socks: chosenModels["socks"] ?? "",
            shoes: chosenModels["shoes"] ?? "",
            head: chosenModels["head"] ?? "",
            neck: chosenModels["neck"] ?? "",
            eyewear: chosenModels["eyewear"] ?? ""
        )
    }

    func loadOutfitFrom(_ outfit: AvatarOutfit) {
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
        for (category, modelName) in categories {
            if !modelName.isEmpty {
                loadClothingItem(named: modelName, category: category)
            }
        }
    }
} 