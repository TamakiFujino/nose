import UIKit
import FirebaseFirestore
import FirebaseAuth

class BoxViewController: UIViewController {
    
    // MARK: - Properties
    private var ownedCompletedCollections: [PlaceCollection] = []
    private var sharedCompletedCollections: [PlaceCollection] = []
    private var selectedCollection: PlaceCollection?
    private var currentTab: CollectionTab = .personal
    
    
    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Completed Collections"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
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
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CollectionCell")
        tableView.backgroundColor = .backgroundPrimary
        return tableView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCompletedCollections()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .backgroundPrimary
        view.addSubview(titleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
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
    
    @objc private func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentTab = sender.selectedSegmentIndex == 0 ? .personal : .shared
        tableView.reloadData()
    }
    
    // MARK: - Data Loading
    private func loadCompletedCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // Owned completed
                let ownedQuery = db.collection("users")
                    .document(currentUserId)
                    .collection("collections")
                    .whereField("isOwner", isEqualTo: true)
                    .whereField("status", isEqualTo: PlaceCollection.Status.completed.rawValue)
                let ownedSnap = try await getDocumentsAsync(ownedQuery)
                self.ownedCompletedCollections = ownedSnap.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    data["isOwner"] = true
                    return PlaceCollection(dictionary: data)
                }
                self.tableView.reloadData()
            } catch {
                Logger.log("Error loading owned completed collections: \(error.localizedDescription)", level: .error, category: "Box")
            }
            do {
                // Shared completed (resolve to owner originals)
                let sharedQuery = db.collection("users")
                    .document(currentUserId)
                    .collection("collections")
                    .whereField("isOwner", isEqualTo: false)
                    .whereField("status", isEqualTo: PlaceCollection.Status.completed.rawValue)
                let sharedSnap = try await getDocumentsAsync(sharedQuery)
                var loaded: [PlaceCollection] = []
                for doc in sharedSnap.documents {
                    let data = doc.data()
                    guard let ownerId = data["userId"] as? String,
                          let collectionId = data["id"] as? String else { continue }
                    let ownerRef = db.collection("users").document(ownerId).collection("collections").document(collectionId)
                    let ownerSnap = try await getDocumentAsync(ownerRef)
                    if let original = ownerSnap.data() {
                        var cdata = original
                        cdata["id"] = collectionId
                        cdata["isOwner"] = false
                        if let c = PlaceCollection(dictionary: cdata) { loaded.append(c) }
                    }
                }
                self.sharedCompletedCollections = loaded
                self.tableView.reloadData()
            } catch {
                Logger.log("Error loading shared completed collections: \(error.localizedDescription)", level: .error, category: "Box")
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
    
    private func showLoadingAlert(title: String) {
        LoadingView.shared.showOverlayLoading(on: self.view, message: title)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension BoxViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTab == .personal ? ownedCompletedCollections.count : sharedCompletedCollections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath)
        let collections = currentTab == .personal ? ownedCompletedCollections : sharedCompletedCollections
        let collection = collections[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = collection.name
        content.secondaryAttributedText = AttributedIconText.iconWithText(
            systemName: "bookmark.fill",
            tintColor: .fourthColor,
            text: "\(collection.places.count)",
            textColor: .fourthColor
        )
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let collections = currentTab == .personal ? ownedCompletedCollections : sharedCompletedCollections
        let collection = collections[indexPath.row]
        selectedCollection = collection
        let placesVC = CollectionPlacesViewController(collection: collection)
        if let sheet = placesVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(placesVC, animated: true)
    }
}
