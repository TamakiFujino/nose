import UIKit
import FirebaseFirestore
import FirebaseAuth

class BoxViewController: UIViewController {
    
    // MARK: - Properties
    private var ownedCompletedCollections: [PlaceCollection] = []
    private var sharedCompletedCollections: [PlaceCollection] = []
    private var selectedCollection: PlaceCollection?
    private var currentTab: CollectionTab = .personal
    
    private enum CollectionTab {
        case personal
        case shared
    }
    
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
    
    @objc private func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentTab = sender.selectedSegmentIndex == 0 ? .personal : .shared
        tableView.reloadData()
    }
    
    // MARK: - Data Loading
    private func loadCompletedCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Load owned completed collections
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .whereField("isOwner", isEqualTo: true)
            .whereField("status", isEqualTo: PlaceCollection.Status.completed.rawValue)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading owned completed collections: \(error.localizedDescription)")
                    return
                }
                
                self?.ownedCompletedCollections = snapshot?.documents.compactMap { document in
                    var data = document.data()
                    data["id"] = document.documentID
                    data["isOwner"] = true
                    return PlaceCollection(dictionary: data)
                } ?? []
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
            
        // Load shared completed collections
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .whereField("isOwner", isEqualTo: false)
            .whereField("status", isEqualTo: PlaceCollection.Status.completed.rawValue)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading shared completed collections: \(error.localizedDescription)")
                    return
                }
                
                let group = DispatchGroup()
                var loadedCollections: [PlaceCollection] = []
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    let data = document.data()
                    
                    if let ownerId = data["userId"] as? String,
                       let collectionId = data["id"] as? String {
                        db.collection("users")
                            .document(ownerId)
                            .collection("collections")
                            .document(collectionId)
                            .getDocument { snapshot, error in
                                defer { group.leave() }
                                
                                if let error = error {
                                    print("Error loading original collection: \(error.localizedDescription)")
                                    return
                                }
                                
                                if let originalData = snapshot?.data() {
                                    var collectionData = originalData
                                    collectionData["id"] = collectionId
                                    collectionData["isOwner"] = false
                                    
                                    if let collection = PlaceCollection(dictionary: collectionData) {
                                        loadedCollections.append(collection)
                                    }
                                }
                            }
                    } else {
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self?.sharedCompletedCollections = loadedCollections
                    self?.tableView.reloadData()
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
        content.secondaryText = "\(collection.places.count) places"
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
