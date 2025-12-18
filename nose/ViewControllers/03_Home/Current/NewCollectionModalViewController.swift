import UIKit
import FirebaseAuth
import FirebaseFirestore

protocol NewCollectionModalViewControllerDelegate: AnyObject {
    func newCollectionModalViewController(_ controller: NewCollectionModalViewController, didCreateCollection collectionId: String)
}

class NewCollectionModalViewController: CollectionModalViewController {
    // MARK: - Properties
    weak var delegate: NewCollectionModalViewControllerDelegate?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        // Background tap to dismiss is disabled (defaults to false)
        super.viewDidLoad()
    }
    
    // MARK: - Configuration
    override func configureInitialState() {
        titleLabel.text = "New Collection"
        // Save button starts disabled (handled by base class)
    }
    
    // MARK: - Actions
    @objc override func saveButtonTapped() {
        guard !collectionName.isEmpty else { return }
        
        // Create new collection in Firestore
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let collectionId = UUID().uuidString
        
        var collectionData: [String: Any] = [
            "id": collectionId,
            "name": collectionName,
            "places": [],
            "userId": currentUserId,
            "createdAt": Timestamp(date: Date()),
            "isOwner": true,
            "status": PlaceCollection.Status.active.rawValue,
            "members": [currentUserId]
        ]
        
        // Add icon if selected
        if let iconUrl = selectedIconUrl {
            collectionData["iconUrl"] = iconUrl
        }
        
        let collectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionId)
        
        // Show loading indicator
        saveButton.isEnabled = false
        let originalTitle = saveButton.title(for: .normal)
        saveButton.setTitle("Saving...", for: .normal)
        
        collectionRef.setData(collectionData) { [weak self] error in
            DispatchQueue.main.async {
                self?.saveButton.isEnabled = true
                self?.saveButton.setTitle(originalTitle, for: .normal)
                
                if let error = error {
                    print("❌ Error creating collection: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Error", message: "Failed to create collection. Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    return
                }
                
                print("✅ Successfully created collection: \(self?.collectionName ?? "")")
                self?.delegate?.newCollectionModalViewController(self!, didCreateCollection: collectionId)
                self?.dismiss(animated: true)
            }
        }
    }
}
