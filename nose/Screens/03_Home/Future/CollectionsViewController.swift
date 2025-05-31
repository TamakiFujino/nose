import UIKit
import FirebaseFirestore
import FirebaseAuth

class CollectionsViewController: UIViewController {
    
    // MARK: - Properties
    private var collections: [PlaceCollection] = []
    
    // MARK: - UI Components
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
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .fourthColor
        button.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        return button
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
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(menuButton)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -16),
            
            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
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
    
    @objc private func menuButtonTapped() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Create new collection action
        let createAction = UIAlertAction(title: "Create New Collection", style: .default) { [weak self] _ in
            self?.createNewCollection()
        }
        createAction.setValue(UIImage(systemName: "plus.circle"), forKey: "image")
        
        // View completed collections action
        let viewCompletedAction = UIAlertAction(title: "View Completed Collections", style: .default) { [weak self] _ in
            self?.viewCompletedCollections()
        }
        viewCompletedAction.setValue(UIImage(systemName: "checkmark.circle"), forKey: "image")
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(createAction)
        alertController.addAction(viewCompletedAction)
        alertController.addAction(cancelAction)
        
        // For iPad support
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = menuButton
            popoverController.sourceRect = menuButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func createNewCollection() {
        let alertController = UIAlertController(
            title: "New Collection",
            message: "Enter a name for your collection",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "Collection name"
        }
        
        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let name = alertController.textFields?.first?.text, !name.isEmpty else { return }
            
            self?.showLoadingAlert(title: "Creating Collection")
            
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            
            let status = PlaceCollection.Status.active.rawValue
            print("DEBUG: Creating new collection with status: \(status)")
            
            let collectionData: [String: Any] = [
                "name": name,
                "places": [],
                "userId": currentUserId,
                "status": status
            ]
            
            db.collection("users")
                .document(currentUserId)
                .collection("collections")
                .addDocument(data: collectionData) { [weak self] error in
                    self?.dismiss(animated: true) {
                        if let error = error {
                            ToastManager.showToast(message: "Failed to create collection", type: .error)
                            print("Error creating collection: \(error.localizedDescription)")
                        } else {
                            print("DEBUG: Successfully created new collection")
                            ToastManager.showToast(message: "Collection created", type: .success)
                            self?.loadCollections()
                        }
                    }
                }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(createAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    private func viewCompletedCollections() {
        let boxVC = BoxViewController()
        if let sheet = boxVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(boxVC, animated: true)
    }
    
    private func showLoadingAlert(title: String) {
        let loadingAlert = UIAlertController(title: title, message: "Please wait...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
    }
    
    // MARK: - Data Loading
    private func loadCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // First, let's check what data we have
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading collections: \(error.localizedDescription)")
                    return
                }
                
                print("DEBUG: Found \(snapshot?.documents.count ?? 0) collections")
                
                self?.collections = snapshot?.documents.compactMap { document in
                    var data = document.data()
                    data["id"] = document.documentID
                    
                    // If status is missing, treat it as active
                    if data["status"] == nil {
                        data["status"] = PlaceCollection.Status.active.rawValue
                    }
                    
                    if let collection = PlaceCollection(dictionary: data) {
                        print("DEBUG: Collection '\(collection.name)' has status: \(collection.status.rawValue)")
                        return collection
                    }
                    return nil
                } ?? []
                
                // Filter to only show active collections
                self?.collections = self?.collections.filter { $0.status == .active } ?? []
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CollectionsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return collections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath)
        let collection = collections[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = collection.name
        content.secondaryText = "\(collection.places.count) places"
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let collection = collections[indexPath.row]
        let placesVC = CollectionPlacesViewController(collection: collection)
        if let sheet = placesVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(placesVC, animated: true)
    }
}
