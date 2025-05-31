import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth

class CollectionPlacesViewController: UIViewController {

    // MARK: - Properties

    private let collection: PlaceCollection
    private var places: [PlaceCollection.Place] = []
    private var sessionToken: GMSAutocompleteSessionToken?

    // MARK: - UI Components

    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        return view
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

    private lazy var customizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Customize", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(customizeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var sharedFriendsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 8
        return view
    }()
    
    private lazy var friendIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "person.2.fill")
        imageView.tintColor = .fourthColor
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var sharedCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.text = "0 friends"
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
        sessionToken = GMSAutocompleteSessionToken()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(customizeButton)
        headerView.addSubview(menuButton)
        headerView.addSubview(sharedFriendsView)
        sharedFriendsView.addSubview(friendIconImageView)
        sharedFriendsView.addSubview(sharedCountLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 140),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -16),

            menuButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            menuButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),

            customizeButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            customizeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            customizeButton.heightAnchor.constraint(equalToConstant: 44),
            
            sharedFriendsView.topAnchor.constraint(equalTo: customizeButton.bottomAnchor, constant: 8),
            sharedFriendsView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            sharedFriendsView.heightAnchor.constraint(equalToConstant: 32),
            sharedFriendsView.widthAnchor.constraint(equalToConstant: 120),
            
            friendIconImageView.leadingAnchor.constraint(equalTo: sharedFriendsView.leadingAnchor, constant: 12),
            friendIconImageView.centerYAnchor.constraint(equalTo: sharedFriendsView.centerYAnchor),
            friendIconImageView.widthAnchor.constraint(equalToConstant: 16),
            friendIconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            sharedCountLabel.leadingAnchor.constraint(equalTo: friendIconImageView.trailingAnchor, constant: 8),
            sharedCountLabel.trailingAnchor.constraint(equalTo: sharedFriendsView.trailingAnchor, constant: -12),
            sharedCountLabel.centerYAnchor.constraint(equalTo: sharedFriendsView.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Actions
    @objc private func customizeButtonTapped() {
        let avatarVC = AvatarCustomViewController(collectionId: collection.id)
        let navController = UINavigationController(rootViewController: avatarVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

    @objc private func menuButtonTapped() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
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
        
        // Delete collection action
        let deleteAction = UIAlertAction(title: "Delete Collection", style: .destructive) { [weak self] _ in
            self?.confirmDeleteCollection()
        }
        deleteAction.setValue(UIImage(systemName: "trash"), forKey: "image")
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(shareAction)
        alertController.addAction(completeAction)
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
        // TODO: Implement collection completion logic
        print("Completing collection: \(collection.name)")
        // You can add your completion logic here
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
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        
        // Show loading state
        let loadingAlert = UIAlertController(title: "Deleting Collection", message: "Please wait...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // First, delete any shared collections
        db.collection("users")
            .whereField("sharedCollections.\(collection.id).sharedBy", isEqualTo: currentUserId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error finding shared collections: \(error.localizedDescription)")
                    self.dismiss(animated: true) {
                        ToastManager.showToast(message: "Failed to delete collection", type: .error)
                    }
                    return
                }
                
                // Create a dispatch group to handle multiple deletions
                let group = DispatchGroup()
                
                // Delete shared collections from each user
                snapshot?.documents.forEach { document in
                    group.enter()
                    db.collection("users")
                        .document(document.documentID)
                        .collection("sharedCollections")
                        .document(self.collection.id)
                        .delete { error in
                            if let error = error {
                                print("Error deleting shared collection: \(error.localizedDescription)")
                            }
                            group.leave()
                        }
                }
                
                // After all shared collections are deleted, delete the main collection
                group.notify(queue: .main) {
                    db.collection("users")
                        .document(currentUserId)
                        .collection("collections")
                        .document(self.collection.id)
                        .delete { [weak self] error in
                            self?.dismiss(animated: true) {
                                if let error = error {
                                    print("Error deleting collection: \(error.localizedDescription)")
                                    ToastManager.showToast(message: "Failed to delete collection", type: .error)
                                } else {
                                    print("Successfully deleted collection")
                                    ToastManager.showToast(message: "Collection deleted", type: .success)
                                    
                                    // Dismiss the view controller and notify parent to refresh
                                    self?.dismiss(animated: true) {
                                        // Post notification to refresh collections
                                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                                    }
                                }
                            }
                        }
                }
            }
    }

    // MARK: - Data Loading

    private func loadPlaces() {
        places = collection.places
        tableView.reloadData()
    }

    private func loadSharedFriendsCount() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // First check if this collection is shared by others
        db.collection("users")
            .document(currentUserId)
            .collection("sharedCollections")
            .document(self.collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading shared friends count: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let sharedWith = data["sharedWith"] as? [String] {
                    DispatchQueue.main.async {
                        self?.sharedCountLabel.text = "\(sharedWith.count) friends"
                        self?.sharedFriendsView.isHidden = false
                    }
                } else {
                    // If not shared by others, check if this user has shared it
                    db.collection("users")
                        .whereField("sharedCollections.\(self?.collection.id ?? "").sharedBy", isEqualTo: currentUserId)
                        .getDocuments { [weak self] snapshot, error in
                            if let error = error {
                                print("Error loading shared friends count: \(error.localizedDescription)")
                                return
                            }
                            
                            let count = snapshot?.documents.count ?? 0
                            DispatchQueue.main.async {
                                self?.sharedCountLabel.text = "\(count) friends"
                                self?.sharedFriendsView.isHidden = count == 0
                            }
                        }
                }
            }
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let place = places[indexPath.row]
        let db = Firestore.firestore()
        
        // Show loading state
        let loadingAlert = UIAlertController(title: "Removing Place", message: "Please wait...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // Remove the place from the collection
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .updateData([
                "places": FieldValue.arrayRemove([place.toFirestoreData()])
            ]) { [weak self] error in
                self?.dismiss(animated: true) {
                    if let error = error {
                        print("Error removing place: \(error.localizedDescription)")
                        ToastManager.showToast(message: "Failed to remove place", type: .error)
                    } else {
                        // Update local data
                        self?.places.remove(at: indexPath.row)
                        self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                        ToastManager.showToast(message: "Place removed", type: .success)
                        
                        // Notify parent to refresh
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
    }
}

// MARK: - PlaceTableViewCell

class PlaceTableViewCell: UITableViewCell {
    private let placeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(placeImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)

        NSLayoutConstraint.activate([
            placeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            placeImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 80),
            placeImageView.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            ratingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            ratingLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 16),
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with place: PlaceCollection.Place) {
        nameLabel.text = place.name
        ratingLabel.text = "Rating: \(String(format: "%.1f", place.rating))"

        let placesClient = GMSPlacesClient.shared()
        let fields: GMSPlaceField = [.photos]

        placesClient.fetchPlace(fromPlaceID: place.placeId, placeFields: fields, sessionToken: nil) { [weak self] place, error in
            if let photoMetadata = place?.photos?.first {
                placesClient.loadPlacePhoto(photoMetadata) { [weak self] photo, _ in
                    DispatchQueue.main.async {
                        self?.placeImageView.image = photo
                    }
                }
            }
        }
    }
}

// MARK: - ShareCollectionViewControllerDelegate
extension CollectionPlacesViewController: ShareCollectionViewControllerDelegate {
    func shareCollectionViewController(_ controller: ShareCollectionViewController, didSelectFriends friends: [User]) {
        // Create a shareable link or content
        let shareText = "Check out my collection: \(collection.name)"
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // For iPad support
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = menuButton
            popoverController.sourceRect = menuButton.bounds
        }
        
        present(activityViewController, animated: true)
        
        // Share with selected friends
        shareWithFriends(friends)
    }
    
    private func shareWithFriends(_ friends: [User]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Create a shared collection document
        let sharedCollection = [
            "collectionId": collection.id,
            "sharedBy": currentUserId,
            "sharedAt": FieldValue.serverTimestamp(),
            "sharedWith": friends.map { $0.id }
        ] as [String: Any]
        
        // Add to each friend's shared collections
        for friend in friends {
            db.collection("users")
                .document(friend.id)
                .collection("sharedCollections")
                .document(collection.id)
                .setData(sharedCollection) { error in
                    if let error = error {
                        print("Error sharing collection with \(friend.name): \(error.localizedDescription)")
                    } else {
                        print("Successfully shared collection with \(friend.name)")
                    }
                }
        }
    }
}

// MARK: - PlaceCollection.Place
extension PlaceCollection.Place {
    func toFirestoreData() -> [String: Any] {
        return [
            "placeId": placeId,
            "name": name,
            "formattedAddress": formattedAddress,
            "rating": rating,
            "phoneNumber": phoneNumber,
            "addedAt": Timestamp(date: addedAt)
        ]
    }
}
