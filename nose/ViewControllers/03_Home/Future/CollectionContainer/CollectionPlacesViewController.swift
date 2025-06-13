import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth

class CollectionPlacesViewController: UIViewController {

    // MARK: - Properties

    private let collection: PlaceCollection
    private var places: [PlaceCollection.Place] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var sharedFriendsCount: Int = 0
    private var avatarViewController: Avatar3DViewController?
    private var isCompleted: Bool = false

    // MARK: - UI Components

    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        return view
    }()

    private lazy var avatarContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 8
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarContainerTapped))
        view.addGestureRecognizer(tapGesture)
        return view
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .fourthColor
        return indicator
    }()

    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .fourthColor
        button.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaceTableViewCell.self, forCellReuseIdentifier: "PlaceCell")
        tableView.backgroundColor = .systemBackground
        tableView.rowHeight = 100
        return tableView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = collection.name
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    private lazy var sharedFriendsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        
        // Create attributed string with icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.secondaryLabel)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " 0")
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        label.attributedText = attributedText
        label.accessibilityLabel = "Number of shared friends"
        label.accessibilityValue = "0"
        label.accessibilityIdentifier = "shared_friends_count_label"
        return label
    }()

    private lazy var placesCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        
        // Create attributed string with icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.secondaryLabel)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " 0")
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        label.attributedText = attributedText
        label.accessibilityLabel = "Number of places saved"
        label.accessibilityValue = "0"
        label.accessibilityIdentifier = "places_count_label"
        return label
    }()

    // MARK: - Initialization

    init(collection: PlaceCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPlaces()
        loadSharedFriendsCount()
        checkIfCompleted()
        sessionToken = GMSAutocompleteSessionToken()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(menuButton)
        headerView.addSubview(sharedFriendsLabel)
        headerView.addSubview(placesCountLabel)
        headerView.addSubview(avatarContainer)
        view.addSubview(tableView)

        // Hide menu button if user is not the owner
        menuButton.isHidden = !collection.isOwner

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 300), // Increased height for larger avatar

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -16),

            menuButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            menuButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),

            sharedFriendsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            sharedFriendsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            placesCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            placesCountLabel.leadingAnchor.constraint(equalTo: sharedFriendsLabel.trailingAnchor, constant: 16),

            avatarContainer.topAnchor.constraint(equalTo: sharedFriendsLabel.bottomAnchor, constant: 16),
            avatarContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            avatarContainer.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            avatarContainer.heightAnchor.constraint(equalToConstant: 180), // Increased height for larger avatar

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupAvatarView()
    }

    private func setupAvatarView() {
        let avatarVC = Avatar3DViewController()
        avatarVC.cameraPosition = SIMD3<Float>(0.0, 3.0, 7.0)
        avatarViewController = avatarVC

        addChild(avatarVC)
        avatarContainer.addSubview(avatarVC.view)
        avatarVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add loading indicator
        avatarContainer.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            avatarVC.view.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarVC.view.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarVC.view.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            avatarVC.view.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor)
        ])
        
        avatarVC.didMove(toParent: self)
        loadingIndicator.startAnimating()
        loadAvatarData()
    }
    
    private func loadAvatarData() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        print("DEBUG: Loading avatar data for collection: \(collection.id)")
        let collectionType = collection.isOwner ? "owned" : "shared"
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionType)
            .collection(collectionType)
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading collection: \(error.localizedDescription)")
                    self?.loadingIndicator.stopAnimating()
                    return
                }
                
                if let avatarData = snapshot?.data()?["avatarData"] as? [String: Any] {
                    print("DEBUG: Found avatar data: \(avatarData)")
                    if let avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarData) {
                        DispatchQueue.main.async {
                            print("DEBUG: Loading avatar data into view controller")
                            self?.avatarViewController?.loadAvatarData(avatarData)
                            self?.loadingIndicator.stopAnimating()
                        }
                    } else {
                        print("DEBUG: Failed to parse avatar data")
                        self?.loadingIndicator.stopAnimating()
                    }
                } else {
                    print("DEBUG: No avatar data found in collection")
                    self?.loadingIndicator.stopAnimating()
                }
            }
    }

    // MARK: - Actions
    @objc private func avatarContainerTapped() {
        showAvatarCustomization()
    }

    @objc private func menuButtonTapped() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if collection.status == .completed {
            // Put back collection action
            let putBackAction = UIAlertAction(title: "Put back collection", style: .default) { [weak self] _ in
                self?.putBackCollection()
            }
            putBackAction.setValue(UIImage(systemName: "arrow.uturn.backward"), forKey: "image")
            alertController.addAction(putBackAction)
        } else {
            // Share with friends action
            let shareAction = UIAlertAction(title: "Share with Friends", style: .default) { [weak self] _ in
                self?.shareCollection()
            }
            shareAction.setValue(UIImage(systemName: "square.and.arrow.up"), forKey: "image")
            
            // Complete collection action
            let completeAction = UIAlertAction(title: "Complete the Collection", style: .default) { [weak self] _ in
                self?.completeCollection()
            }
            completeAction.setValue(UIImage(systemName: "checkmark.circle"), forKey: "image")
            
            alertController.addAction(shareAction)
            alertController.addAction(completeAction)
        }
        
        // Delete collection action
        let deleteAction = UIAlertAction(title: "Delete Collection", style: .destructive) { [weak self] _ in
            self?.confirmDeleteCollection()
        }
        deleteAction.setValue(UIImage(systemName: "trash"), forKey: "image")
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        // For iPad support
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = menuButton
            popoverController.sourceRect = menuButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func shareCollection() {
        let shareVC = ShareCollectionViewController(collection: collection)
        shareVC.delegate = self
        let navController = UINavigationController(rootViewController: shareVC)
        present(navController, animated: true)
    }
    
    private func completeCollection() {
        let alertController = UIAlertController(
            title: "Complete Collection",
            message: "Are you sure you want to mark '\(collection.name)' as completed?",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let completeAction = UIAlertAction(title: "Complete", style: .default) { [weak self] _ in
            self?.markCollectionAsCompleted()
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(completeAction)
        
        present(alertController, animated: true)
    }
    
    private func markCollectionAsCompleted() {
        showLoadingAlert(title: "Completing Collection")
        
        CollectionContainerManager.shared.completeCollection(collection) { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    ToastManager.showToast(message: "Failed to complete collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection completed", type: .success)
                    // Dismiss the view controller and post notification
                    self?.dismiss(animated: true) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
    }
    
    private func confirmDeleteCollection() {
        // Create a custom alert controller with a more prominent warning
        let alertController = UIAlertController(
            title: "Delete Collection",
            message: "Are you sure you want to delete '\(collection.name)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        // Add a destructive delete action
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCollection()
        }
        
        // Add a cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        // Add actions to the alert controller
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        // Present the alert controller
        present(alertController, animated: true)
    }
    
    private func deleteCollection() {
        showLoadingAlert(title: "Deleting Collection")
        
        CollectionContainerManager.shared.deleteCollection(collection) { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    ToastManager.showToast(message: "Failed to delete collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection deleted", type: .success)
                    self?.dismiss(animated: true) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
    }

    private func putBackCollection() {
        showLoadingAlert(title: "Putting back collection")
        
        CollectionContainerManager.shared.putBackCollection(collection) { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    ToastManager.showToast(message: "Failed to put back collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection put back", type: .success)
                    self?.dismiss(animated: true) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadPlaces() {
        places = collection.places
        updatePlacesCountLabel()
        tableView.reloadData()
    }

    private func loadSharedFriendsCount() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // First get the blocked users
        db.collection("users")
            .document(currentUserId)
            .collection("blocked")
            .getDocuments { [weak self] blockedSnapshot, blockedError in
                if let blockedError = blockedError {
                    print("Error loading blocked users: \(blockedError.localizedDescription)")
                    return
                }
                
                // Get list of blocked user IDs
                let blockedUserIds = blockedSnapshot?.documents.map { $0.documentID } ?? []
                
                // Now get the collection data
                let collectionRef = db.collection("users")
                    .document(self?.collection.userId ?? "")  // Use the collection owner's ID
                    .collection("collections")
                    .document("owned")
                    .collection("owned")
                    .document(self?.collection.id ?? "")
                
                collectionRef.getDocument { [weak self] snapshot, error in
                    if let error = error {
                        print("Error loading collection: \(error.localizedDescription)")
                        return
                    }
                    
                    if let sharedWith = snapshot?.data()?["sharedWith"] as? [String] {
                        // Filter out blocked users from the count
                        let activeSharedUsers = sharedWith.filter { !blockedUserIds.contains($0) }
                        self?.sharedFriendsCount = activeSharedUsers.count
                    } else {
                        self?.sharedFriendsCount = 0
                    }
                    self?.updateSharedFriendsLabel()
                }
            }
    }

    private func updateSharedFriendsLabel() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.secondaryLabel)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " \(sharedFriendsCount)")
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        sharedFriendsLabel.attributedText = attributedText
        sharedFriendsLabel.accessibilityValue = "\(sharedFriendsCount)"
    }

    private func updatePlacesCountLabel() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.secondaryLabel)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " \(places.count)")
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        placesCountLabel.attributedText = attributedText
        placesCountLabel.accessibilityValue = "\(places.count)"
    }
    
    private func showLoadingAlert(title: String) {
        LoadingView.shared.showAlertLoading(title: title, on: self)
    }

    private func checkIfCompleted() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let isCompleted = snapshot?.data()?["isCompleted"] as? Bool {
                    self?.isCompleted = isCompleted
                    DispatchQueue.main.async {
                        // Always show the menu button, but with different actions based on completion status
                        self?.menuButton.isHidden = false
                    }
                }
            }
    }

    private func showAvatarCustomization() {
        // If the current user is the collection's userId, they are the owner
        let isOwner = collection.userId == Auth.auth().currentUser?.uid
        let avatarVC = AvatarCustomViewController(collectionId: collection.id, isOwner: isOwner)
        avatarVC.delegate = self
        let navController = UINavigationController(rootViewController: avatarVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension CollectionPlacesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        places.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
        cell.configure(with: places[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let place = places[indexPath.row]
        let placesClient = GMSPlacesClient.shared()
        let fields: GMSPlaceField = [.name, .coordinate, .formattedAddress, .phoneNumber, .rating, .openingHours, .photos, .placeID]

        placesClient.fetchPlace(fromPlaceID: place.placeId, placeFields: fields, sessionToken: sessionToken) { [weak self] place, error in
            if let place = place {
                DispatchQueue.main.async {
                    let detailVC = PlaceDetailViewController(place: place, isFromCollection: true)
                    self?.present(detailVC, animated: true)
                }
            }
        }
    }
    
    // Add swipe-to-delete functionality
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            self?.confirmDeletePlace(at: indexPath)
            completion(false) // Don't dismiss the swipe action until user confirms
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func confirmDeletePlace(at indexPath: IndexPath) {
        let place = places[indexPath.row]
        let alertController = UIAlertController(
            title: "Delete Place",
            message: "Are you sure you want to remove '\(place.name)' from this collection?",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deletePlace(at: indexPath)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true)
    }
    
    private func deletePlace(at indexPath: IndexPath) {
        let place = places[indexPath.row]
        showLoadingAlert(title: "Removing Place")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Determine the correct collection type and path
        let collectionType = collection.isOwner ? "owned" : "shared"
        print("📄 Collection type: \(collectionType)")
        print("📄 Collection ID: \(collection.id)")
        
        // Get references to both collections
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collectionType)
            .collection(collectionType)
            .document(collection.id)
            
        let ownerCollectionRef = db.collection("users")
            .document(collection.userId)  // This is the owner's ID
            .collection("collections")
            .document("owned")
            .collection("owned")
            .document(collection.id)
        
        print("📄 Firestore path: users/\(currentUserId)/collections/\(collectionType)/\(collectionType)/\(collection.id)")
        print("📄 Owner path: users/\(collection.userId)/collections/owned/owned/\(collection.id)")
        
        // First get the current collection data
        userCollectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error getting collection: \(error.localizedDescription)")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                }
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No data found in collection document")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                }
                return
            }
            
            print("📄 Collection data before removal: \(data)")
            
            // Create a mutable copy of the data
            var updatedData = data
            
            // Get current places array
            if var places = data["places"] as? [[String: Any]] {
                // Remove the place with matching placeId
                places.removeAll { placeDict in
                    guard let placeId = placeDict["placeId"] as? String else { return false }
                    return placeId == place.placeId
                }
                
                // Update the places array in the data
                updatedData["places"] = places
                
                // Create a batch to update both collections
                let batch = db.batch()
                
                // Update user's collection
                batch.updateData(["places": places], forDocument: userCollectionRef)
                
                // Update owner's collection
                batch.updateData(["places": places], forDocument: ownerCollectionRef)
                
                // Commit the batch
                batch.commit { error in
                    self?.dismiss(animated: true) {
                        if let error = error {
                            print("Error removing place: \(error.localizedDescription)")
                            ToastManager.showToast(message: "Failed to remove place", type: .error)
                        } else {
                            // Update local data
                            self?.places.remove(at: indexPath.row)
                            self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                            self?.updatePlacesCountLabel()
                            ToastManager.showToast(message: "Place removed", type: .success)
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                        }
                    }
                }
            } else {
                print("Failed to parse places array from collection data")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                }
            }
        }
    }
}

// MARK: - ShareCollectionViewControllerDelegate
extension CollectionPlacesViewController: ShareCollectionViewControllerDelegate {
    func shareCollectionViewController(_ controller: ShareCollectionViewController, didSelectFriends friends: [User]) {
        print("📤 Received friends in CollectionPlacesViewController:")
        friends.forEach { friend in
            print("📤 Friend ID: \(friend.id), Name: \(friend.name)")
        }
        
        LoadingView.shared.showOverlayLoading(on: view, message: "Sharing Collection...")
        
        CollectionContainerManager.shared.shareCollection(collection, with: friends) { [weak self] error in
            DispatchQueue.main.async {
                LoadingView.shared.hideOverlayLoading()
                
                if let error = error {
                    print("❌ Error sharing collection: \(error.localizedDescription)")
                    ToastManager.showToast(message: "Failed to share collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection shared successfully", type: .success)
                    self?.loadSharedFriendsCount()
                }
            }
        }
    }
}

// MARK: - AvatarCustomViewControllerDelegate
extension CollectionPlacesViewController: AvatarCustomViewControllerDelegate {
    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData) {
        avatarViewController?.loadAvatarData(avatarData)
        
        CollectionContainerManager.shared.updateAvatarData(avatarData, for: collection) { error in
            if let error = error {
                print("Error updating collection avatar: \(error.localizedDescription)")
            }
        }
    }
}
