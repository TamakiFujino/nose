import UIKit
import RealityKit
import Combine

extension Avatar3DViewController {

    func loadAvatarModel() {
        let categories = ["bottoms", "tops", "hair_base", "hair_front", "hair_back", "jackets", "skin", "eye", "eyebrow", "nose", "mouth", "socks", "shoes", "head", "neck", "eyewear"]
        var savedModelsLocal = [String: String]() // Use a local var to avoid confusion
        for category in categories {
            savedModelsLocal[category] = UserDefaults.standard.string(forKey: "chosen\(category.capitalized)Model") ?? ""
        }
        chosenModels = savedModelsLocal

        if let savedColorsData = UserDefaults.standard.data(forKey: "chosenColors") {
            do {
                if let unarchivedColors = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: savedColorsData) as? [String: UIColor] {
                    chosenColors = unarchivedColors
                }
            } catch {
                print("Error unarchiving colors: \(error)")
            }
        }

        // Load and cache the base avatar model
        if let cached = modelCache["body"] {
            baseEntity = cached.clone(recursive: true)
            self.setupBaseEntityAndLoadSelections() 
        } else {
            ModelEntity.loadModelAsync(named: "body")
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error loading base avatar model asynchronously: \(error)")
                    }
                }, receiveValue: { [weak self] entity in
                    guard let self = self else { return }
                    entity.name = "Avatar" // Base entity name
                    self.modelCache["body"] = entity
                    self.baseEntity = entity.clone(recursive: true)
                    self.setupBaseEntityAndLoadSelections()
                })
                .store(in: &cancellables)
        }
    }

    private func setupBaseEntityAndLoadSelections() {
        setupBaseEntity() 

        for (category, modelName) in chosenModels {
            if !modelName.isEmpty {
                loadClothingItem(named: modelName, category: category)
            }
        }
    }

    func loadClothingItem(named modelName: String, category: String) {
        guard baseEntity != nil else { return }

        // If the requested model is already active for this category, do nothing.
        if let activeEntity = activeModelEntities[category], activeEntity.name == modelName {
            // Ensure chosenModels is also up-to-date, though it should be if activeModelEntities is correct.
            chosenModels[category] = modelName
            // If color needs re-application (e.g., outfit load), handle it here or ensure loadOutfitFrom calls changeColor.
            if let color = chosenColors[category] {
                changeClothingItemColor(for: category, to: color) // Re-apply color if needed
            }
            return
        }

        // Remove current model for this category, if any
        if let oldEntity = activeModelEntities[category] {
            oldEntity.removeFromParent()
            activeModelEntities[category] = nil
        }
        // chosenModels[category] will be updated when the new model is added successfully.

        // Cancel any ongoing load for this specific category before starting a new one.
        currentCategoryLoadingOps[category]?.cancel()

        if let cached = modelCache[modelName] {
            let modelEntity = cached.clone(recursive: true)
            modelEntity.name = modelName // Explicitly set name on the clone
            self.addClothingEntityToScene(modelEntity, category: category)
        } else {
            let newLoadOp = ModelEntity.loadModelAsync(named: modelName)
                .sink(receiveCompletion: { [weak self] completion in
                    self?.currentCategoryLoadingOps[category] = nil // Clear op on completion
                    if case .failure(let error) = completion {
                        print("Error loading clothing item \(modelName) asynchronously: \(error)")
                        // Potentially clear chosenModels[category] if load fails and it was set prematurely
                    }
                }, receiveValue: { [weak self] loadedEntity in
                    guard let self = self else { return }
                    // self.currentCategoryLoadingOps[category] = nil // Already cleared in completion
                    loadedEntity.name = modelName 
                    self.modelCache[modelName] = loadedEntity // Cache the original loaded entity
                    let modelEntityClone = loadedEntity.clone(recursive: true) // Clone for the scene
                    // modelEntityClone.name is inherited from loadedEntity upon cloning if not set otherwise
                    self.addClothingEntityToScene(modelEntityClone, category: category)
                })
            
            newLoadOp.store(in: &cancellables) // Store in global set for lifetime management
            currentCategoryLoadingOps[category] = newLoadOp // Track this specific category's operation
        }
    }

    private func addClothingEntityToScene(_ modelEntity: ModelEntity, category: String) {
        guard let baseEntity = self.baseEntity else { return }
        // The name should already be set on modelEntity before calling this function.
        // modelEntity.name = category // No, should be modelName for consistency with cache and findEntity (if ever needed)
        
        modelEntity.scale = SIMD3<Float>(repeating: 1.0)
        baseEntity.addChild(modelEntity)
        activeModelEntities[category] = modelEntity
        chosenModels[category] = modelEntity.name // Update chosenModels with the actual name of the added entity

        if let color = chosenColors[category] {
            changeClothingItemColor(for: category, to: color)
        }
    }

    func removeClothingItem(for category: String) {
        if let entityToRemove = activeModelEntities[category] {
            entityToRemove.removeFromParent()
            activeModelEntities[category] = nil
        }
        chosenModels[category] = "" // Mark as no model chosen for this category
        // chosenColors[category] = nil // Optionally clear color too
    }
} 