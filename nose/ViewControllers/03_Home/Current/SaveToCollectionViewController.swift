import UIKit
import GooglePlaces
import FirebaseAuth
import FirebaseFirestore

protocol SaveToCollectionViewControllerDelegate: AnyObject {
    func saveToCollectionViewController(_ controller: SaveToCollectionViewController, didSavePlace place: GMSPlace, toCollection collection: PlaceCollection)
}

class SaveToCollectionViewController: UIViewController {
    // MARK: - Properties
    private let place: GMSPlace
    private var ownedCollections: [PlaceCollection] = []
    private var sharedCollections: [PlaceCollection] = []
    private var selectedCollection: PlaceCollection?
    private var newCollectionName: String = ""
    private var currentTab: CollectionTab = .personal
    
    private enum CollectionTab {
        case personal
        case shared
    }
    
    weak var delegate: SaveToCollectionViewControllerDelegate?
    
    // MARK: - UI Components
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .fourthColor
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Save to Collection"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var placeNameLabel: UILabel = {
        let label = UILabel()
        label.text = place.name
        label.font = .systemFont(ofSize: 16)
        label.textColor = .fourthColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let items = ["Your Collections", "From Friends"]
        let control = UISegmentedControl(items: items)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var collectionsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CollectionCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var createNewCollectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .white
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        button.addTarget(self, action: #selector(createNewCollectionTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var saveButton: UIButton = {
        let button = CustomButton()
        button.setTitle("Save", for: .normal)
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    init(place: GMSPlace) {
        self.place = place
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCollections()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(placeNameLabel)
        view.addSubview(segmentedControl)
        view.addSubview(collectionsTableView)
        view.addSubview(createNewCollectionButton)
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            // Close button constraints
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            // Place name label constraints
            placeNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            placeNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            placeNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Segmented control constraints
            segmentedControl.topAnchor.constraint(equalTo: placeNameLabel.bottomAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Collections table view constraints
            collectionsTableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            collectionsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionsTableView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),
            
            // Create new collection button constraints
            createNewCollectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            createNewCollectionButton.bottomAnchor.constraint(equalTo: collectionsTableView.bottomAnchor, constant: -16),
            createNewCollectionButton.widthAnchor.constraint(equalToConstant: 44),
            createNewCollectionButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Save button constraints
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Helper Methods
    private func loadCollections() {
        loadUserCollections()
    }
    
    private func loadUserCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Load owned collections
        let ownedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .whereField("isOwner", isEqualTo: true)
        
        ownedCollectionsRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading owned collections: \(error.localizedDescription)")
                return
            }
            
            self?.ownedCollections = snapshot?.documents.compactMap { document in
                var data = document.data()
                data["id"] = document.documentID
                data["isOwner"] = true
                
                if let collection = PlaceCollection(dictionary: data) {
                    print("✅ Loaded owned collection: '\(collection.name)' (ID: \(collection.id))")
                    return collection
                }
                print("❌ Failed to parse owned collection: \(document.documentID)")
                return nil
            } ?? []
            
            // Filter to only show active collections
            self?.ownedCollections = self?.ownedCollections.filter { $0.status == .active } ?? []
            
            DispatchQueue.main.async {
                self?.collectionsTableView.reloadData()
            }
        }
        
        // Load shared collections
        let sharedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .whereField("isOwner", isEqualTo: false)
        
        sharedCollectionsRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading shared collections: \(error.localizedDescription)")
                return
            }
            
            let group = DispatchGroup()
            var loadedCollections: [PlaceCollection] = []
            
            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                
                // Get the original collection data from the owner's collections
                if let ownerId = data["userId"] as? String,
                   let collectionId = data["id"] as? String {
                    print("🔍 Loading original collection from owner: \(ownerId), collection: \(collectionId)")
                    
                    db.collection("users")
                        .document(ownerId)
                        .collection("collections")
                        .document(collectionId)
                        .getDocument { snapshot, error in
                            defer { group.leave() }
                            
                            if let error = error {
                                print("❌ Error loading original collection: \(error.localizedDescription)")
                                return
                            }
                            
                            if let originalData = snapshot?.data() {
                                var collectionData = originalData
                                collectionData["id"] = collectionId
                                collectionData["isOwner"] = false
                                
                                if let collection = PlaceCollection(dictionary: collectionData) {
                                    print("✅ Loaded shared collection: '\(collection.name)' (ID: \(collection.id))")
                                    loadedCollections.append(collection)
                                } else {
                                    print("❌ Failed to parse shared collection: \(collectionId)")
                                }
                            } else {
                                print("❌ No data found for shared collection: \(collectionId)")
                            }
                        }
                } else {
                    print("❌ Invalid shared collection data: \(data)")
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self?.sharedCollections = loadedCollections.filter { $0.status == .active }
                self?.collectionsTableView.reloadData()
            }
        }
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = selectedCollection != nil || !newCollectionName.isEmpty
    }
    
    private func showCreateCollectionAlert() {
        let alert = UIAlertController(title: "New Collection", message: "Enter a name for your collection", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Collection Name"
            textField.autocapitalizationType = .words
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self = self,
                  let textField = alert.textFields?.first,
                  let collectionName = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !collectionName.isEmpty else {
                return
            }
            
            // Create new collection in Firestore
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            let collectionId = UUID().uuidString
            
            let collectionData: [String: Any] = [
                "id": collectionId,
                "name": collectionName,
                "places": [],
                "userId": currentUserId,
                "createdAt": Timestamp(date: Date()),
                "isOwner": true,
                "status": PlaceCollection.Status.active.rawValue,
                "members": [currentUserId]  // Add owner to members list by default
            ]
            
            let collectionRef = db.collection("users")
                .document(currentUserId)
                .collection("collections")
                .document(collectionId)
            
            collectionRef.setData(collectionData) { error in
                if let error = error {
                    print("❌ Error creating collection: \(error.localizedDescription)")
                    return
                }
                
                print("✅ Successfully created collection: \(collectionName)")
                self.loadUserCollections()
            }
        }
        
        alert.addAction(cancelAction)
        alert.addAction(createAction)
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func createNewCollectionTapped() {
        showCreateCollectionAlert()
    }
    
    @objc private func saveButtonTapped() {
        guard let collection = selectedCollection else { return }
        
        print("💾 Saving place '\(place.name ?? "Unknown")' to collection '\(collection.name)'")
        print("💾 Current places in collection: \(collection.places.count)")
        
        // Check if place is already in the collection
        if collection.places.contains(where: { $0.placeId == place.placeID }) {
            print("⚠️ Place is already in this collection")
            showAlert(title: "Already Saved", message: "This place is already saved in this collection.")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Saving...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Create place data
        let placeData: [String: Any] = [
            "name": place.name ?? "",
            "placeId": place.placeID ?? "",
            "rating": place.rating,
            "latitude": place.coordinate.latitude,
            "longitude": place.coordinate.longitude,
            "formattedAddress": place.formattedAddress ?? "",
            "phoneNumber": place.phoneNumber ?? "",
            "addedAt": Timestamp(date: Date())
        ]
        
        // Get references for both user and owner collections
        let db = Firestore.firestore()
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        
        // Reference to the current user's collection
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
        
        print("📄 User's collection path: \(userCollectionRef.path)")
        
        // If this is a shared collection, also get reference to owner's collection
        let ownerCollectionRef = collection.isOwner ? nil : db.collection("users")
            .document(collection.userId)
            .collection("collections")
            .document(collection.id)
        
        if let ownerRef = ownerCollectionRef {
            print("📄 Owner's collection path: \(ownerRef.path)")
        }
        
        // First, verify both collections exist
        let group = DispatchGroup()
        var userCollectionExists = false
        var ownerCollectionExists = false
        
        group.enter()
        userCollectionRef.getDocument { snapshot, error in
            defer { group.leave() }
            if let error = error {
                print("❌ Error checking user collection: \(error.localizedDescription)")
                return
            }
            userCollectionExists = snapshot?.exists ?? false
            print("📄 User collection exists: \(userCollectionExists)")
        }
        
        if let ownerRef = ownerCollectionRef {
            group.enter()
            ownerRef.getDocument { snapshot, error in
                defer { group.leave() }
                if let error = error {
                    print("❌ Error checking owner collection: \(error.localizedDescription)")
                    return
                }
                ownerCollectionExists = snapshot?.exists ?? false
                print("📄 Owner collection exists: \(ownerCollectionExists)")
            }
        } else {
            ownerCollectionExists = true // No owner collection to check
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Create a batch write
            let batch = db.batch()
            
            // Update user's copy
            batch.updateData([
                "places": FieldValue.arrayUnion([placeData])
            ], forDocument: userCollectionRef)
            
            // If this is a shared collection, also update owner's copy
            if let ownerRef = ownerCollectionRef {
                batch.updateData([
                    "places": FieldValue.arrayUnion([placeData])
                ], forDocument: ownerRef)
            }
            
            // Commit the batch
            batch.commit { error in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if let error = error {
                            print("❌ Error saving place: \(error.localizedDescription)")
                            print("❌ Error details: \(error)")
                            // Show error alert
                            let errorAlert = UIAlertController(
                                title: "Error",
                                message: "Failed to save place. Please try again.",
                                preferredStyle: .alert
                            )
                            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(errorAlert, animated: true)
                        } else {
                            print("✅ Successfully saved place to collection")
                            // Refresh collections to update the count
                            self.loadCollections()
                            // Notify delegate and dismiss
                            self.delegate?.saveToCollectionViewController(self, didSavePlace: self.place, toCollection: collection)
                            self.dismiss(animated: true)
                        }
                    }
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentTab = sender.selectedSegmentIndex == 0 ? .personal : .shared
        createNewCollectionButton.isHidden = currentTab == .shared
        collectionsTableView.reloadData()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension SaveToCollectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTab == .personal ? ownedCollections.count : sharedCollections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath)
        let collections = currentTab == .personal ? ownedCollections : sharedCollections
        let collection = collections[indexPath.row]
        
        print("📱 Configuring cell for collection '\(collection.name)' with \(collection.places.count) places")
        
        var content = cell.defaultContentConfiguration()
        content.text = collection.name
        content.secondaryText = "\(collection.places.count) \(collection.places.count == 1 ? "place" : "places")"
        cell.contentConfiguration = content
        
        // Show checkmark for selected collection
        cell.accessoryType = (selectedCollection?.id == collection.id) ? .checkmark : .none
        // change checkmark color
        cell.tintColor = .fourthColor
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let collections = currentTab == .personal ? ownedCollections : sharedCollections
        selectedCollection = collections[indexPath.row]
        print("👆 Selected collection '\(selectedCollection?.name ?? "Unknown")' with \(selectedCollection?.places.count ?? 0) places")
        collectionsTableView.reloadData()
        updateSaveButtonState()
    }
}
