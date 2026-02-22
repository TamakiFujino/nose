import UIKit
import FirebaseAuth
import FirebaseFirestore

protocol EditCollectionModalViewControllerDelegate: AnyObject {
    func editCollectionModalViewController(_ controller: EditCollectionModalViewController, didUpdateCollection collection: PlaceCollection)
}

class EditCollectionModalViewController: CollectionModalViewController {
    // MARK: - Properties
    weak var delegate: EditCollectionModalViewControllerDelegate?
    private let collection: PlaceCollection
    
    // MARK: - Initialization
    init(collection: PlaceCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    override func configureInitialState() {
        titleLabel.text = "Edit Collection"
        
        // Load current collection data
        collectionName = collection.name
        nameTextField.text = collection.name
        
        // Set current icon
        selectedIconUrl = collection.iconUrl
        selectedIconName = collection.iconName
        
        // Update icon button display
        if let iconUrl = collection.iconUrl, !iconUrl.isEmpty {
            updateIconButton(with: iconUrl)
        } else {
            resetIconButton()
        }
        
        // Update save button state based on initial name
        updateSaveButtonState()
    }
    
    // MARK: - Actions
    @objc override func saveButtonTapped() {
        guard !collectionName.isEmpty else { return }
        
        // Check if anything changed
        let nameChanged = collectionName != collection.name
        let iconChanged = (selectedIconUrl != collection.iconUrl) || (selectedIconName != collection.iconName)
        
        guard nameChanged || iconChanged else {
            // Nothing changed, just dismiss
            dismiss(animated: true)
            return
        }
        
        // Show loading indicator
        saveButton.isEnabled = false
        let originalTitle = saveButton.title(for: .normal)
        saveButton.setTitle("Saving...", for: .normal)
        
        updateCollection(name: collectionName, iconUrl: selectedIconUrl, iconName: selectedIconName)
    }
    
    private func updateCollection(name: String, iconUrl: String?, iconName: String?) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            saveButton.isEnabled = true
            saveButton.setTitle("Save", for: .normal)
            let messageModal = MessageModalViewController(title: "Error", message: "User not authenticated")
            present(messageModal, animated: true)
            return
        }
        
        let db = Firestore.firestore()
        
        // Get references to both collections
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // Prepare update data
        var updateData: [String: Any] = [:]
        
        if name != collection.name {
            updateData["name"] = name
        }
        
        // Check if icon changed
        let iconChanged: Bool
        if let iconUrl = iconUrl, !iconUrl.isEmpty {
            // Using custom image URL
            iconChanged = (iconUrl != collection.iconUrl)
            if iconChanged {
                updateData["iconUrl"] = iconUrl
                updateData["iconName"] = FieldValue.delete()
            }
        } else if let iconName = iconName, !iconName.isEmpty {
            // Using SF Symbol (though ImagePickerViewController primarily uses URLs)
            iconChanged = (iconName != collection.iconName)
            if iconChanged {
                updateData["iconName"] = iconName
                updateData["iconUrl"] = FieldValue.delete()
            }
        } else {
            // No icon selected - check if we need to clear existing icon
            iconChanged = (collection.iconUrl != nil || collection.iconName != nil)
            if iconChanged {
                updateData["iconUrl"] = FieldValue.delete()
                updateData["iconName"] = FieldValue.delete()
            }
        }
        
        guard !updateData.isEmpty else {
            // Nothing to update
            saveButton.isEnabled = true
            saveButton.setTitle("Save", for: .normal)
            dismiss(animated: true)
            return
        }
        
        // Create a batch to update both collections
        let batch = db.batch()
        batch.updateData(updateData, forDocument: userCollectionRef)
        batch.updateData(updateData, forDocument: ownerCollectionRef)
        
        // Commit the batch
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.saveButton.isEnabled = true
                self?.saveButton.setTitle("Save", for: .normal)
                
                if let error = error {
                    Logger.log("Error updating collection: \(error.localizedDescription)", level: .error, category: "Collection")
                    let messageModal = MessageModalViewController(title: "Error", message: "Failed to update collection. Please try again.")
                    self?.present(messageModal, animated: true)
                    return
                }
                
                self?.delegate?.editCollectionModalViewController(self!, didUpdateCollection: self!.collection)
                self?.dismiss(animated: true)
            }
        }
    }
}
