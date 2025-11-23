import UIKit
import FirebaseFirestore
import FirebaseAuth

class CollectionsViewController: UIViewController {
    
    // MARK: - Properties
    private var personalCollections: [PlaceCollection] = []
    private var sharedCollections: [PlaceCollection] = []
    private var collectionEventCounts: [String: Int] = [:] // collectionId -> event count
    private var currentTab: CollectionTab = .personal
    weak var mapManager: GoogleMapManager?
    
    private enum CollectionTab {
        case personal
        case shared
    }
    
    // MARK: - UI Components
    private lazy var segmentedControl: UISegmentedControl = {
        let items = ["Your Collections", "From Friends"]
        let control = UISegmentedControl(items: items)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CollectionCell")
        tableView.backgroundColor = .systemBackground
        return tableView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "My Collections"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
        loadCollections()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSheetPresentation()
        loadCollections()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Update map in case collections were already loaded
        updateMapWithCollections()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func configureSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        
        // Create a small detent identifier (approximately 10% of screen height)
        let smallDetentIdentifier = UISheetPresentationController.Detent.Identifier("small")
        let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallDetentIdentifier) { context in
            return context.maximumDetentValue * 0.1 // 10% of screen
        }
        
        // Set detents: small (minimized) and large (full)
        sheet.detents = [smallDetent, .large()]
        
        // Set the initial detent to large (full modal)
        sheet.selectedDetentIdentifier = .large
        
        // Allow interaction with the map behind when minimized
        // This makes the map interactive when the modal is at the small detent
        sheet.largestUndimmedDetentIdentifier = smallDetentIdentifier
        
        // Enable grabber for better UX
        sheet.prefersGrabberVisible = true
        
        // Allow dismissing by dragging down from any detent
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCollections),
            name: NSNotification.Name("RefreshCollections"),
            object: nil
        )
    }
    
    @objc private func refreshCollections() {
        loadCollections()
    }
    
    @objc private func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentTab = sender.selectedSegmentIndex == 0 ? .personal : .shared
        tableView.reloadData()
    }
    
    private func updateMapWithCollections() {
        // Combine all collections (personal + shared) and show on map
        let allCollections = personalCollections + sharedCollections
        mapManager?.showCollectionPlacesOnMap(allCollections)
    }
    
    private func showLoadingAlert(title: String) {
        LoadingView.shared.showAlertLoading(title: title, on: self)
    }
    
    private func cacheCollectionsForExtension() {
        let simpleCollections = personalCollections.map { ["id": $0.id, "name": $0.name] }
        if let defaults = UserDefaults(suiteName: "group.com.tamakifujino.nose") {
            defaults.set(simpleCollections, forKey: "CachedCollections")
            defaults.synchronize()
            print("💾 Cached \(simpleCollections.count) collections for Share Extension")
        }
    }
    
    // MARK: - Data Loading
    private func loadCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        print("🔍 Loading collections for user: \(currentUserId)")
        
        // Load owned collections
        let ownedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
        
        print("📂 Loading owned collections from path: \(ownedCollectionsRef.path)")
        
        ownedCollectionsRef.whereField("isOwner", isEqualTo: true).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading owned collections: \(error.localizedDescription)")
                return
            }
            
            print("📄 Found \(snapshot?.documents.count ?? 0) owned collections")
            
            self?.personalCollections = snapshot?.documents.compactMap { document in
                var data = document.data()
                data["id"] = document.documentID
                data["isOwner"] = true
                
                // If status is missing, treat it as active
                if data["status"] == nil {
                    data["status"] = PlaceCollection.Status.active.rawValue
                }
                
                // Store events count for this collection
                if let eventsArray = data["events"] as? [[String: Any]] {
                    self?.collectionEventCounts[document.documentID] = eventsArray.count
                } else {
                    self?.collectionEventCounts[document.documentID] = 0
                }
                
                if let collection = PlaceCollection(dictionary: data) {
                    print("✅ Loaded owned collection: '\(collection.name)' (ID: \(collection.id))")
                    return collection
                }
                print("❌ Failed to parse owned collection: \(document.documentID)")
                return nil
            } ?? []
            
            // Filter to only show active collections
            self?.personalCollections = self?.personalCollections.filter { $0.status == .active } ?? []
            print("🎯 Active owned collections: \(self?.personalCollections.count ?? 0)")
            
            DispatchQueue.main.async {
                self?.tableView.reloadData()
                // Update map with all collections (personal + shared)
                self?.updateMapWithCollections()
                // Cache for Share Extension
                self?.cacheCollectionsForExtension()
            }
        }
        
        // Load shared collections
        let sharedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
        
        print("📂 Loading shared collections from path: \(sharedCollectionsRef.path)")
        
        sharedCollectionsRef.whereField("isOwner", isEqualTo: false).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading shared collections: \(error.localizedDescription)")
                return
            }
            
            print("📄 Found \(snapshot?.documents.count ?? 0) shared collections")
            
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
                                
                                // If status is missing, treat it as active
                                if collectionData["status"] == nil {
                                    collectionData["status"] = PlaceCollection.Status.active.rawValue
                                }
                                
                                // Store events count for this collection
                                if let eventsArray = originalData["events"] as? [[String: Any]] {
                                    self?.collectionEventCounts[collectionId] = eventsArray.count
                                } else {
                                    self?.collectionEventCounts[collectionId] = 0
                                }
                                
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
                print("🎯 Active shared collections: \(self?.sharedCollections.count ?? 0)")
                self?.tableView.reloadData()
                // Update map with all collections (personal + shared)
                self?.updateMapWithCollections()
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CollectionsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTab == .personal ? personalCollections.count : sharedCollections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath)
        let collections = currentTab == .personal ? personalCollections : sharedCollections
        let collection = collections[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = collection.name
        
        // Count both places and events
        let placesCount = collection.places.count
        let eventsCount = collectionEventCounts[collection.id] ?? 0
        let totalCount = placesCount + eventsCount
        
        // Create attributed string with bookmark icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.secondaryLabel)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " \(totalCount)", attributes: [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 14)
        ])
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        content.secondaryAttributedText = attributedText
        
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let collections = currentTab == .personal ? personalCollections : sharedCollections
        let collection = collections[indexPath.row]
        let placesVC = CollectionPlacesViewController(collection: collection)
        if let sheet = placesVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(placesVC, animated: true)
    }
}
