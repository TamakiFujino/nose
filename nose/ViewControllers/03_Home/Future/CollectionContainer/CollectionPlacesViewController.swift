import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth
import MapKit

class CollectionPlacesViewController: UIViewController {

    // MARK: - Properties

    private let collection: PlaceCollection
    private var places: [PlaceCollection.Place] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var sharedFriendsCount: Int = 0
    
    private var isCompleted: Bool = false
    private static let imageCache = NSCache<NSString, UIImage>()

    // MARK: - UI Components

    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        return view
    }()

    
    // Removed old avatar preview loading indicator

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

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .secondarySystemBackground
        return imageView
    }()

    // Removed button; using avatarImageView as trigger to customization

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

        // Listen for avatar thumbnail updates
        NotificationCenter.default.addObserver(self, selector: #selector(handleAvatarThumbnailUpdatedNotification(_:)), name: Notification.Name("AvatarThumbnailUpdated"), object: nil)
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(menuButton)
        headerView.addSubview(sharedFriendsLabel)
        headerView.addSubview(placesCountLabel)
        headerView.addSubview(avatarImageView)
        avatarImageView.isUserInteractionEnabled = true
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(avatarImageTapped))
        avatarImageView.addGestureRecognizer(avatarTap)
        view.addSubview(tableView)

        // Hide menu button if user is not the owner
        menuButton.isHidden = !collection.isOwner

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 420),

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

            avatarImageView.topAnchor.constraint(equalTo: sharedFriendsLabel.bottomAnchor, constant: 12),
            avatarImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            avatarImageView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            avatarImageView.heightAnchor.constraint(equalToConstant: 300),

            // No customize button; avatarImageView acts as the trigger

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // setupAvatarView()
        // Prefill avatar image synchronously if cached on disk to avoid placeholder flash
        prefillAvatarImageIfCached()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAvatarThumbnail(forceRefresh: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

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

    @objc private func avatarImageTapped() {
        let vc = ContentViewController(collection: collection)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
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
                if error != nil {
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
                if error != nil {
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
                if error != nil {
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
                    .document(self?.collection.id ?? "")
                
                collectionRef.getDocument { [weak self] snapshot, error in
                    if let error = error {
                        print("Error loading collection: \(error.localizedDescription)")
                        return
                    }
                    
                    if let members = snapshot?.data()?["members"] as? [String] {
                        // Filter out blocked users but include the owner in the count
                        let activeMembers = members.filter { 
                            !blockedUserIds.contains($0)
                        }
                        self?.sharedFriendsCount = activeMembers.count
                        print("📊 Total members (including owner): \(activeMembers.count)")
                    } else {
                        self?.sharedFriendsCount = 0
                        print("📊 No members found")
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

//    private func showAvatarCustomization() {
//        // If the current user is the collection's userId, they are the owner
//        let isOwner = collection.userId == Auth.auth().currentUser?.uid
//        let avatarVC = AvatarCustomViewController(collectionId: collection.id, isOwner: isOwner)
//        avatarVC.delegate = self
//        let navController = UINavigationController(rootViewController: avatarVC)
//        navController.modalPresentationStyle = .fullScreen
//        present(navController, animated: true)
//    }
    

}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension CollectionPlacesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        places.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
        cell.configure(with: places[indexPath.row])
        // Reliable built-in accessory button; handled in accessoryButtonTappedForRowAt
        cell.accessoryType = .detailButton
        cell.tintColor = .fourthColor
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let place = places[indexPath.row]
        
        // Since PlaceCollection.Place doesn't have coordinates, we need to fetch the place details
        // But we'll use the cache first to avoid unnecessary API calls
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: place.placeId) {
            let detailVC = PlaceDetailViewController(place: cachedPlace, isFromCollection: true)
            present(detailVC, animated: true)
            return
        }
        
        // If not cached, fetch the place details
        PlacesAPIManager.shared.fetchCollectionPlaceDetails(placeID: place.placeId) { [weak self] fetchedPlace in
            if let fetchedPlace = fetchedPlace {
                DispatchQueue.main.async {
                    let detailVC = PlaceDetailViewController(place: fetchedPlace, isFromCollection: true)
                    self?.present(detailVC, animated: true)
                }
            } else {
                // If we can't fetch the place details, just show a simple alert
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Unable to Load Details",
                        message: "Could not load complete details for \(place.name). Please try again later.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // Map icon tapped
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: place.placeId) {
            openPlaceInMapsByName(cachedPlace.name ?? place.name)
        } else {
            openPlaceInMapsByName(place.name)
        }
    }

    @objc private func handleAvatarThumbnailUpdatedNotification(_ note: Notification) {
        guard let updatedCollectionId = note.userInfo?["collectionId"] as? String,
              updatedCollectionId == collection.id else { return }
        loadAvatarThumbnail(forceRefresh: true)
    }

    private func loadAvatarThumbnail(forceRefresh: Bool) {
        // 1) Try in-memory cache by collection id
        let cacheKey = NSString(string: collection.id)
        if !forceRefresh, let cached = CollectionPlacesViewController.imageCache.object(forKey: cacheKey) {
            avatarImageView.image = cached
            return
        }

        // 2) Try remote URL stored in Firestore
        let db = Firestore.firestore()
        db.collection("users")
            .document(collection.userId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if var urlString = snapshot?.data()? ["avatarThumbnailURL"] as? String, let baseURL = URL(string: urlString) {
                    // Cache-bust with timestamp param if available
                    if let ts = snapshot?.data()? ["avatarThumbnailUpdatedAt"] as? Timestamp {
                        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                        var q = comps?.queryItems ?? []
                        q.append(URLQueryItem(name: "t", value: "\(Int(ts.dateValue().timeIntervalSince1970))"))
                        comps?.queryItems = q
                        urlString = comps?.url?.absoluteString ?? urlString
                    }
                    guard let finalURL = URL(string: urlString) else { self.loadAvatarThumbnailFromCachesFallback(); return }
                    self.downloadImage(from: finalURL, ignoreCache: true) { image in
                        DispatchQueue.main.async {
                            if let image = image {
                                CollectionPlacesViewController.imageCache.setObject(image, forKey: cacheKey)
                                self.avatarImageView.image = image
                            } else {
                                self.loadAvatarThumbnailFromCachesFallback()
                            }
                        }
                    }
                } else {
                    // 3) Fallback to local caches file (may exist on the device that captured)
                    self.loadAvatarThumbnailFromCachesFallback()
                }
            }
    }

    private func loadAvatarThumbnailFromCachesFallback() {
        let relativePath = "avatar_captures/users/\(collection.userId)/collections/\(collection.id)/avatar.png"
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cachesDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path), let image = UIImage(contentsOfFile: fileURL.path) {
            CollectionPlacesViewController.imageCache.setObject(image, forKey: NSString(string: collection.id))
            avatarImageView.image = image
        } else {
            // Defer placeholder until we confirm there's truly no remote image later
            // Keep whatever is currently set to avoid a flash
            if avatarImageView.image == nil {
                avatarImageView.image = UIImage(named: "AvatarPlaceholder") ?? UIImage(systemName: "person.crop.circle")
                avatarImageView.contentMode = .scaleAspectFit
            }
        }
    }

    private func prefillAvatarImageIfCached() {
        // Check in-memory cache first
        let cacheKey = NSString(string: collection.id)
        if let cached = CollectionPlacesViewController.imageCache.object(forKey: cacheKey) {
            avatarImageView.image = cached
            return
        }
        // Then check disk cache synchronously to avoid initial flash
        let relativePath = "avatar_captures/users/\(collection.userId)/collections/\(collection.id)/avatar.png"
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cachesDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path), let image = UIImage(contentsOfFile: fileURL.path) {
            CollectionPlacesViewController.imageCache.setObject(image, forKey: cacheKey)
            avatarImageView.image = image
        }
    }

    private func downloadImage(from url: URL, ignoreCache: Bool = false, completion: @escaping (UIImage?) -> Void) {
        var request = URLRequest(url: url)
        if ignoreCache {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
    
    // MARK: - Maps Integration
    private func openPlaceInMapsByName(_ name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name

        let sheet = UIAlertController(title: "Open in Maps", message: name, preferredStyle: .actionSheet)

        // Apple Maps (app) using maps:// scheme
        if let appleURL = URL(string: "maps://?q=\(encoded)") {
            sheet.addAction(UIAlertAction(title: "Apple Maps", style: .default, handler: { _ in
                UIApplication.shared.open(appleURL, options: [:]) { success in
                    if !success, let webURL = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                        UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                    }
                }
            }))
        }

        // Google Maps, if installed
        if let gmapsURL = URL(string: "comgooglemaps://?q=\(encoded)&zoom=16"), UIApplication.shared.canOpenURL(gmapsURL) {
            sheet.addAction(UIAlertAction(title: "Google Maps", style: .default, handler: { _ in
                UIApplication.shared.open(gmapsURL, options: [:], completionHandler: nil)
            }))
        }

        // Waze, if installed
        if let wazeURL = URL(string: "waze://?q=\(encoded)&navigate=yes"), UIApplication.shared.canOpenURL(wazeURL) {
            sheet.addAction(UIAlertAction(title: "Waze", style: .default, handler: { _ in
                UIApplication.shared.open(wazeURL, options: [:], completionHandler: nil)
            }))
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = sheet.popoverPresentationController {
            pop.sourceView = self.view
            pop.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    // MARK: - Accessory actions
    @objc private func didTapMapAccessory(_ sender: UIButton) {
        let row = sender.tag
        guard row >= 0 && row < places.count else { return }
        let place = places[row]
        // Use cached details if available for better name fidelity, otherwise fall back to collection name
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: place.placeId) {
            openPlaceInMapsByName(cachedPlace.name ?? place.name)
        } else {
            openPlaceInMapsByName(place.name)
        }
    }
    
    // Add swipe actions functionality
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Safety check to prevent crash
        guard indexPath.row < places.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        
        let place = places[indexPath.row]
        
        // Open in Maps action
        let mapAction = UIContextualAction(style: .normal, title: "Map") { [weak self] (action, view, completion) in
            self?.openPlaceInMapsByName(place.name)
            completion(true)
        }
        mapAction.backgroundColor = .systemGreen
        mapAction.image = UIImage(systemName: "map")

        // Visited action
        let visitedAction = UIContextualAction(style: .normal, title: place.visited ? "Unvisited" : "Visited") { [weak self] (action, view, completion) in
            self?.toggleVisitedStatus(at: indexPath)
            completion(true) // Dismiss the swipe action immediately
        }
        visitedAction.backgroundColor = .blueColor
        visitedAction.image = UIImage(systemName: place.visited ? "xmark.circle" : "checkmark.circle")
        
        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            self?.confirmDeletePlace(at: indexPath)
            completion(false) // Don't dismiss the swipe action until user confirms
        }
        deleteAction.backgroundColor = .fourthColor
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, visitedAction, mapAction])
    }
    
    private func confirmDeletePlace(at indexPath: IndexPath) {
        // Safety check to prevent crash
        guard indexPath.row < places.count else { return }
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
    
    private func toggleVisitedStatus(at indexPath: IndexPath) {
        // Safety check to prevent crash
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        let newVisitedStatus = !place.visited
        let actionTitle = newVisitedStatus ? "Marking as visited" : "Marking as unvisited"
        showLoadingAlert(title: actionTitle)
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Get references to both collections
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            
        let ownerCollectionRef = db.collection("users")
            .document(collection.userId)  // This is the owner's ID
            .collection("collections")
            .document(collection.id)
        
        print("📄 Firestore path: users/\(currentUserId)/collections/\(collection.id)")
        print("📄 Owner path: users/\(collection.userId)/collections/\(collection.id)")
        
        // First get the current collection data
        userCollectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error getting collection: \(error.localizedDescription)")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to update place status", type: .error)
                }
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No data found in collection document")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to update place status", type: .error)
                }
                return
            }
            
            print("📄 Collection data before update: \(data)")
            
            // Get current places array
            if var places = data["places"] as? [[String: Any]] {
                // Find and update the place with matching placeId
                if let placeIndex = places.firstIndex(where: { placeDict in
                    guard let placeId = placeDict["placeId"] as? String else { return false }
                    return placeId == place.placeId
                }) {
                    // Update the visited status
                    places[placeIndex]["visited"] = newVisitedStatus
                    
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
                                print("Error updating place status: \(error.localizedDescription)")
                                ToastManager.showToast(message: "Failed to update place status", type: .error)
                            } else {
                                // Update local data
                                self?.places[indexPath.row].visited = newVisitedStatus
                                self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                                ToastManager.showToast(message: newVisitedStatus ? "Marked as visited" : "Marked as unvisited", type: .success)
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                            }
                        }
                    }
                } else {
                    print("Place not found in collection data")
                    self?.dismiss(animated: true) {
                        ToastManager.showToast(message: "Failed to update place status", type: .error)
                    }
                }
            } else {
                print("No places array found in collection data")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to update place status", type: .error)
                }
            }
        }
    }
    
    private func deletePlace(at indexPath: IndexPath) {
        // Safety check to prevent crash
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        showLoadingAlert(title: "Removing Place")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Get references to both collections
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            
        let ownerCollectionRef = db.collection("users")
            .document(collection.userId)  // This is the owner's ID
            .collection("collections")
            .document(collection.id)
        
        print("📄 Firestore path: users/\(currentUserId)/collections/\(collection.id)")
        print("📄 Owner path: users/\(collection.userId)/collections/\(collection.id)")
        
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
                print("No places array found in collection data")
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

//// MARK: - AvatarCustomViewControllerDelegate
//extension CollectionPlacesViewController: AvatarCustomViewControllerDelegate {
//    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData) {
//        avatarViewController?.loadAvatarData(avatarData)
//        
//        CollectionContainerManager.shared.updateAvatarData(avatarData, for: collection) { error in
//            if let error = error {
//                print("Error updating collection avatar: \(error.localizedDescription)")
//            }
//        }
//    }
//}
