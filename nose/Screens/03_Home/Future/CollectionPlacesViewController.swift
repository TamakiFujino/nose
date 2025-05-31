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
        headerView.addSubview(menuButton)
        headerView.addSubview(sharedFriendsLabel)
        headerView.addSubview(placesCountLabel)
        headerView.addSubview(avatarContainer)
        view.addSubview(tableView)

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
        avatarViewController = Avatar3DViewController()
        guard let avatarVC = avatarViewController else { return }
        
        addChild(avatarVC)
        avatarContainer.addSubview(avatarVC.view)
        avatarVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            avatarVC.view.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarVC.view.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarVC.view.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
            avatarVC.view.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
        ])
        
        avatarVC.didMove(toParent: self)
        loadAvatarData()
    }

    private func loadAvatarData() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        print("DEBUG: Loading avatar data for collection: \(collection.id)")
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading collection: \(error.localizedDescription)")
                    return
                }
                
                if let avatarData = snapshot?.data()?["avatarData"] as? [String: Any] {
                    print("DEBUG: Found avatar data: \(avatarData)")
                    if let avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarData) {
                        DispatchQueue.main.async {
                            print("DEBUG: Loading avatar data into view controller")
                            self?.avatarViewController?.loadAvatarData(avatarData)
                        }
                    } else {
                        print("DEBUG: Failed to parse avatar data")
                    }
                } else {
                    print("DEBUG: No avatar data found in collection")
                }
            }
    }

    // MARK: - Actions
    @objc private func avatarContainerTapped() {
        let avatarVC = AvatarCustomViewController(collectionId: collection.id)
        let navController = UINavigationController(rootViewController: avatarVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true) { [weak self] in
            // Reload avatar data after customization
            self?.loadAvatarData()
        }
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
        updatePlacesCountLabel()
        tableView.reloadData()
    }

    private func loadSharedFriendsCount() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading collection: \(error.localizedDescription)")
                    return
                }
                
                if let sharedWith = snapshot?.data()?["sharedWith"] as? [String] {
                    self?.sharedFriendsCount = sharedWith.count
                } else {
                    self?.sharedFriendsCount = 0
                }
                self?.updateSharedFriendsLabel()
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
        
        // After sharing is complete, reload the shared friends count
        loadSharedFriendsCount()
    }
    
    private func shareWithFriends(_ friends: [User]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Show loading state
        let loadingAlert = UIAlertController(title: "Sharing Collection", message: "Please wait...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // Update the collection document with shared information
        let sharedData = [
            "sharedWith": friends.map { $0.id },
            "sharedAt": FieldValue.serverTimestamp()
        ] as [String: Any]
        
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .updateData(sharedData) { [weak self] error in
                if let error = error {
                    print("Error sharing collection: \(error.localizedDescription)")
                    self?.dismiss(animated: true) {
                        ToastManager.showToast(message: "Failed to share collection", type: .error)
                    }
                    return
                }
                
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Collection shared successfully", type: .success)
                    self?.loadSharedFriendsCount()
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
