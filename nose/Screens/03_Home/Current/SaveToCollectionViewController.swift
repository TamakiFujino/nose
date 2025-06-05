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
    private var collections: [PlaceCollection] = []
    private var selectedCollection: PlaceCollection?
    private var newCollectionName: String = ""
    
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
            
            // Collections table view constraints
            collectionsTableView.topAnchor.constraint(equalTo: placeNameLabel.bottomAnchor, constant: 24),
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        print("📥 Fetching collections for user \(currentUserId)...")
        
        // Load owned collections
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document("owned")
            .collection("owned")
            .getDocuments { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
                if let error = error {
                    print("❌ Error loading collections: \(error.localizedDescription)")
                    self?.createDefaultCollections()
                    return
                }
                
                let fetchedCollections = snapshot?.documents.compactMap { document -> PlaceCollection? in
                    var data = document.data()
                    data["id"] = document.documentID
                    data["isOwner"] = true
                    
                    // If status is missing, treat it as active
                    if data["status"] == nil {
                        data["status"] = PlaceCollection.Status.active.rawValue
                    }
                    
                    if let collection = PlaceCollection(dictionary: data) {
                        print("✅ Loaded collection: '\(collection.name)' with \(collection.places.count) places")
                        return collection
                    }
                    return nil
                } ?? []
                
                DispatchQueue.main.async {
                    if fetchedCollections.isEmpty {
                        self?.createDefaultCollections()
                    } else {
                        self?.collections = fetchedCollections.filter { $0.status == .active }
                        self?.collectionsTableView.reloadData()
                    }
                }
            }
    }
    
    private func createDefaultCollections() {
        print("📚 Creating default collections...")
        let defaultCollections = [
            PlaceCollection(id: UUID().uuidString, name: "Favorites", places: [], userId: Auth.auth().currentUser?.uid ?? ""),
            PlaceCollection(id: UUID().uuidString, name: "Want to Visit", places: [], userId: Auth.auth().currentUser?.uid ?? ""),
            PlaceCollection(id: UUID().uuidString, name: "Been There", places: [], userId: Auth.auth().currentUser?.uid ?? "")
        ]
        
        // Save default collections to Firestore
        for collection in defaultCollections {
            print("📚 Creating default collection: \(collection.name)")
            CollectionContainerManager.shared.createCollection(name: collection.name) { result in
                switch result {
                case .success(let collection):
                    print("✅ Successfully created collection: \(collection.name)")
                case .failure(let error):
                    print("❌ Failed to create collection: \(error.localizedDescription)")
                }
            }
        }
        
        collections = defaultCollections
        collectionsTableView.reloadData()
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
            CollectionContainerManager.shared.createCollection(name: collectionName) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let newCollection):
                        self?.collections.append(newCollection)
                        self?.selectedCollection = newCollection
                        self?.collectionsTableView.reloadData()
                        self?.updateSaveButtonState()
                    case .failure(let error):
                        print("Error creating collection: \(error.localizedDescription)")
                        // Show error alert
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Failed to create collection. Please try again.",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                }
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
        
        // Save place to collection in Firestore
        let collectionRef = Firestore.firestore().collection("users")
            .document(Auth.auth().currentUser?.uid ?? "")
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        collectionRef.updateData([
            "places": FieldValue.arrayUnion([placeData])
        ]) { [weak self] (error: Error?) in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if let error = error {
                        print("❌ Error saving place: \(error.localizedDescription)")
                        // Show error alert
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Failed to save place. Please try again.",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    } else {
                        print("✅ Successfully saved place to collection")
                        // Refresh collections to update the count
                        self?.loadCollections()
                        // Notify delegate and dismiss
                        self?.delegate?.saveToCollectionViewController(self!, didSavePlace: self!.place, toCollection: collection)
                        self?.dismiss(animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension SaveToCollectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return collections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath)
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
        selectedCollection = collections[indexPath.row]
        print("👆 Selected collection '\(selectedCollection?.name ?? "Unknown")' with \(selectedCollection?.places.count ?? 0) places")
        collectionsTableView.reloadData()
        updateSaveButtonState()
    }
}
