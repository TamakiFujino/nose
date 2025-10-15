import UIKit
import FirebaseFirestore
import FirebaseAuth

class CollectionsViewController: UIViewController {
    
    // MARK: - Properties
    private var personalCollections: [PlaceCollection] = []
    private var sharedCollections: [PlaceCollection] = []
    private var collectionEventCounts: [String: Int] = [:] // collectionId -> event count
    private var currentTab: CollectionTab = .personal
    
    
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
        tableView.backgroundColor = .firstColor
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
        loadCollections()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .firstColor
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.lg),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: DesignTokens.Spacing.lg),
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
    
    private func showLoadingAlert(title: String) {
        LoadingView.shared.showOverlayLoading(on: self.view, message: title)
    }
    
    // MARK: - Data Loading
    private func loadCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        Logger.log("Loading collections for user: \(currentUserId)", level: .info, category: "Collections")
        
        // Load using async/await via CollectionManager
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let owned = try await CollectionManager.shared.fetchCollections(userId: currentUserId)
                self.personalCollections = owned.filter { $0.isOwner && $0.status == .active }
                // Precompute event counts from existing events arrays if present
                for collection in owned {
                    self.collectionEventCounts[collection.id] = 0
                }
                self.tableView.reloadData()
            } catch {
                Logger.log("Failed to load owned collections: \(error.localizedDescription)", level: .error, category: "Collections")
            }
            // Shared collections: read user's shared list and resolve to owner originals
            do {
                let sharedQuery = db.collection("users")
                    .document(currentUserId)
                    .collection("collections")
                    .whereField("isOwner", isEqualTo: false)

                let sharedSnapshot = try await getDocumentsAsync(sharedQuery)
                var loadedShared: [PlaceCollection] = []
                for document in sharedSnapshot.documents {
                    let data = document.data()
                    guard let ownerId = data["userId"] as? String,
                          let collectionId = data["id"] as? String else { continue }
                    let ownerDoc = db.collection("users").document(ownerId).collection("collections").document(collectionId)
                    let ownerSnapshot = try await getDocumentAsync(ownerDoc)
                    if let originalData = ownerSnapshot.data() {
                        var collectionData = originalData
                        collectionData["id"] = collectionId
                        collectionData["isOwner"] = false
                        if collectionData["status"] == nil {
                            collectionData["status"] = PlaceCollection.Status.active.rawValue
                        }
                        if let eventsArray = originalData["events"] as? [[String: Any]] {
                            self.collectionEventCounts[collectionId] = eventsArray.count
                        } else {
                            self.collectionEventCounts[collectionId] = 0
                        }
                        if let collection = PlaceCollection(dictionary: collectionData) {
                            loadedShared.append(collection)
                        }
                    }
                }
                self.sharedCollections = loadedShared.filter { $0.status == .active }
                self.tableView.reloadData()
            } catch {
                Logger.log("Failed to load shared collections: \(error.localizedDescription)", level: .error, category: "Collections")
            }
        }
    }
    
    // MARK: - Async Firestore helpers
    private func getDocumentsAsync(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No snapshot"]))
                }
            }
        }
    }
    
    private func getDocumentAsync(_ ref: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            ref.getDocument { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No snapshot"]))
                }
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
        content.secondaryAttributedText = AttributedIconText.iconWithText(
            systemName: "bookmark.fill",
            tintColor: .fourthColor,
            text: "\(totalCount)",
            textColor: .fourthColor
        )
        
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
