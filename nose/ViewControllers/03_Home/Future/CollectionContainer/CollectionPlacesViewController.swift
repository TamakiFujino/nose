import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth
import MapKit

class CollectionPlacesViewController: UIViewController {

    // MARK: - Properties

    private let collection: PlaceCollection
    private var places: [PlaceCollection.Place] = []
    private var events: [Event] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var sharedFriendsCount: Int = 0
    private var avatarsLoadGeneration: Int = 0
    
    private var isCompleted: Bool = false
    private static let imageCache = NSCache<NSString, UIImage>()

    // MARK: - UI Components

    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .firstColor
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
        tableView.backgroundColor = .backgroundPrimary
        tableView.rowHeight = 100
        return tableView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = collection.name
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .sixthColor
        return label
    }()

    private lazy var sharedFriendsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .fourthColor
        
        // Create attributed string with icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.fourthColor)
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
        label.textColor = .fourthColor
        
        // Create attributed string with icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.fourthColor)
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
        imageView.backgroundColor = .clear
        return imageView
    }()

    private lazy var avatarsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.spacing = -180 // adjust overlap to -100
        return stack
    }()

    private lazy var customizeButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Customize avatar", for: .normal)
        button.size = .large
        button.style = .primary
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(customizeAvatarTapped), for: .touchUpInside)
        return button
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
        // prefillAvatarImageIfCached() // disabled since big avatar image is not shown
    }

    private func setupUI() {
        view.backgroundColor = .backgroundPrimary
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(menuButton)
        headerView.addSubview(sharedFriendsLabel)
        headerView.addSubview(placesCountLabel)
        headerView.addSubview(avatarsStackView)
        headerView.addSubview(customizeButton)
        view.addSubview(tableView)

        // Hide menu button if user is not the owner
        menuButton.isHidden = !collection.isOwner

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

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

            avatarsStackView.topAnchor.constraint(equalTo: sharedFriendsLabel.bottomAnchor, constant: 8),
            avatarsStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 0),
            avatarsStackView.heightAnchor.constraint(equalToConstant: 216),

            customizeButton.topAnchor.constraint(equalTo: avatarsStackView.bottomAnchor, constant: 6),
            customizeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            customizeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            customizeButton.heightAnchor.constraint(equalToConstant: 48),

            headerView.bottomAnchor.constraint(equalTo: customizeButton.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh overlapping avatars on return
        loadOverlappingAvatars()
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
    
    @objc private func customizeAvatarTapped() {
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
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let completeAction = UIAlertAction(title: "Complete", style: .default) { [weak self] _ in
            self?.markCollectionAsCompleted()
        }
        AlertManager.present(on: self, title: "Complete Collection", message: "Are you sure you want to mark '\(collection.name)' as completed?", style: .info, preferredStyle: .alert, actions: [cancelAction, completeAction])
    }
    
    private func markCollectionAsCompleted() {
        showLoadingAlert(title: "Completing Collection")
        
        CollectionContainerManager.shared.completeCollection(collection) { [weak self] error in
            LoadingView.shared.hideOverlayLoading()
                if error != nil {
                    ToastManager.showToast(message: "Failed to complete collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection completed", type: .success)
                    // Dismiss the view controller and post notification
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
        }
    }
    
    private func confirmDeleteCollection() {
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCollection()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        AlertManager.present(on: self, title: "Delete Collection", message: "Are you sure you want to delete '\(collection.name)'? This action cannot be undone.", style: .error, preferredStyle: .alert, actions: [cancelAction, deleteAction])
    }
    
    private func deleteCollection() {
        showLoadingAlert(title: "Deleting Collection")
        
        CollectionContainerManager.shared.deleteCollection(collection) { [weak self] error in
            LoadingView.shared.hideOverlayLoading()
                if error != nil {
                    ToastManager.showToast(message: "Failed to delete collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection deleted", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
        }
    }

    private func putBackCollection() {
        showLoadingAlert(title: "Putting back collection")
        
        CollectionContainerManager.shared.putBackCollection(collection) { [weak self] error in
            LoadingView.shared.hideOverlayLoading()
                if error != nil {
                    ToastManager.showToast(message: "Failed to put back collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection put back", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
        }
    }

    // MARK: - Data Loading

    private func loadPlaces() {
        places = collection.places
        loadEvents()
        updatePlacesCountLabel()
        tableView.reloadData()
    }
    
    private func loadEvents() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Load events from the collection
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading events: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let eventsArray = data["events"] as? [[String: Any]] else {
                    print("📄 No events in collection")
                    DispatchQueue.main.async {
                        self?.events = []
                        self?.updatePlacesCountLabel()
                        self?.tableView.reloadData()
                    }
                    return
                }
                
                print("📄 Found \(eventsArray.count) events in collection")
                
                // Use DispatchGroup to verify each event still exists
                let group = DispatchGroup()
                var loadedEvents: [Event] = []
                let appendQueue = DispatchQueue(label: "com.nose.collection.loadedEventsAppend")
                
                for eventDict in eventsArray {
                    guard let eventId = eventDict["eventId"] as? String,
                          let title = eventDict["title"] as? String,
                          let startTimestamp = eventDict["startDate"] as? Timestamp,
                          let endTimestamp = eventDict["endDate"] as? Timestamp,
                          let locationName = eventDict["locationName"] as? String,
                          let locationAddress = eventDict["locationAddress"] as? String,
                          let userId = eventDict["userId"] as? String else {
                        print("⚠️ Skipping event with incomplete data")
                        continue
                    }
                    
                    let latitude = eventDict["latitude"] as? Double ?? 0.0
                    let longitude = eventDict["longitude"] as? Double ?? 0.0
                    let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    
                    // Verify the event still exists in the user's events collection
                    group.enter()
                    db.collection("users")
                        .document(userId)
                        .collection("events")
                        .document(eventId)
                        .getDocument { eventSnapshot, eventError in
                            // Check if event exists and is active
                            guard let eventData = eventSnapshot?.data(),
                                  let status = eventData["status"] as? String,
                                  status == "active" else {
                                print("⚠️ Event \(eventId) no longer exists or is inactive, skipping")
                                group.leave()
                                return
                            }

                            let details = eventData["details"] as? String ?? ""
                            let createdAtTimestamp = eventData["createdAt"] as? Timestamp ?? Timestamp(date: Date())

                            let completeAndAppend: ([UIImage]) -> Void = { images in
                                let eventDateTime = EventDateTime(
                                    startDate: startTimestamp.dateValue(),
                                    endDate: endTimestamp.dateValue()
                                )
                                let eventLocation = EventLocation(
                                    name: locationName,
                                    address: locationAddress,
                                    coordinates: coordinates
                                )
                                let event = Event(
                                    id: eventId,
                                    title: title,
                                    dateTime: eventDateTime,
                                    location: eventLocation,
                                    details: details,
                                    images: images,
                                    createdAt: createdAtTimestamp.dateValue(),
                                    userId: userId
                                )
                                appendQueue.async {
                                    loadedEvents.append(event)
                                    group.leave()
                                }
                            }

                            if let imageURLs = eventData["imageURLs"] as? [String],
                               let firstImageURL = imageURLs.first,
                               !firstImageURL.isEmpty,
                               let url = URL(string: firstImageURL) {
                                let request = URLRequest(url: url)
                                URLSession.shared.dataTask(with: request) { data, _, _ in
                                    if let data = data, let image = UIImage(data: data) {
                                        completeAndAppend([image])
                                    } else {
                                        completeAndAppend([])
                                    }
                                }.resume()
                            } else {
                                completeAndAppend([])
                            }
                        }
                }
                
                // Wait for all event verifications to complete
                group.notify(queue: .main) {
                    print("✅ Loaded \(loadedEvents.count) active events")
                    self?.events = loadedEvents
                    self?.updatePlacesCountLabel()
                    self?.tableView.reloadData()
                    
                    // Clean up deleted events from the collection if count doesn't match
                    if loadedEvents.count != eventsArray.count {
                        print("🧹 Cleaning up \(eventsArray.count - loadedEvents.count) deleted events from collection")
                        self?.cleanupDeletedEvents(activeEvents: loadedEvents)
                    }
                }
            }
    }
    
    private func cleanupDeletedEvents(activeEvents: [Event]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Create array of active event IDs
        let activeEventIds = Set(activeEvents.map { $0.id })
        
        // Get the collection document
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
        
        let ownerCollectionRef = db.collection("users")
            .document(collection.userId)
            .collection("collections")
            .document(collection.id)
        
        userCollectionRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  var eventsArray = data["events"] as? [[String: Any]] else {
                return
            }
            
            // Filter out deleted events
            let cleanedEvents = eventsArray.filter { eventDict in
                guard let eventId = eventDict["eventId"] as? String else { return false }
                return activeEventIds.contains(eventId)
            }
            
            // Only update if there's a difference
            if cleanedEvents.count != eventsArray.count {
                let batch = db.batch()
                batch.updateData(["events": cleanedEvents], forDocument: userCollectionRef)
                batch.updateData(["events": cleanedEvents], forDocument: ownerCollectionRef)
                
                batch.commit { error in
                    if let error = error {
                        print("❌ Error cleaning up deleted events: \(error.localizedDescription)")
                    } else {
                        print("✅ Successfully cleaned up deleted events from collection")
                    }
                }
            }
        }
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
        imageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.fourthColor)
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
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.fourthColor)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let totalItems = places.count + events.count
        let textString = NSAttributedString(string: " \(totalItems)")
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        placesCountLabel.attributedText = attributedText
        placesCountLabel.accessibilityValue = "\(totalItems)"
    }
    
    private func showLoadingAlert(title: String) {
        LoadingView.shared.showOverlayLoading(on: self.view, message: title)
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
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // Section 0: Events, Section 1: Places
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return events.isEmpty ? nil : "Events"
        } else {
            return places.isEmpty ? nil : "Places"
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return events.count
        } else {
            return places.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            // Event cell
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
            let event = events[indexPath.row]
            cell.configureWithEvent(event)
            return cell
        } else {
            // Place cell
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
            cell.configure(with: places[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            // Event tapped
            let event = events[indexPath.row]
            let detailVC = EventDetailViewController(event: event)
            present(detailVC, animated: true)
            return
        }
        
        // Place tapped
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
        // Reload the overlapping avatars immediately when thumbnail updates
        loadOverlappingAvatars()
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

    private func loadOverlappingAvatars() {
        avatarsLoadGeneration += 1
        let currentGen = avatarsLoadGeneration
        avatarsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let db = Firestore.firestore()
        let ownerId = collection.userId
        let collectionId = collection.id
        let thumbSize: CGFloat = 216

        func renderSquare(image: UIImage?) -> UIImage? {
            guard let img = image else { return nil }
            let format = UIGraphicsImageRendererFormat.default()
            // Render at device scale for crisp output on Retina displays
            format.scale = UIScreen.main.scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbSize, height: thumbSize), format: format)
            let output = renderer.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize))
                let iw = img.size.width
                let ih = img.size.height
                if iw <= 0 || ih <= 0 { return }
                // High-quality aspect-fit
                let scale = min(thumbSize / iw, thumbSize / ih)
                let drawW = iw * scale
                let drawH = ih * scale
                let dx = (thumbSize - drawW) * 0.5
                let dy = (thumbSize - drawH) * 0.5
                img.draw(in: CGRect(x: dx, y: dy, width: drawW, height: drawH))
            }
            return output
        }

        func addAvatar(image: UIImage?) {
            // Ignore stale completions
            if currentGen != avatarsLoadGeneration { return }
            let iv = UIImageView(image: renderSquare(image: image) ?? UIImage(named: "AvatarPlaceholder"))
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = thumbSize / 2
            iv.layer.borderColor = UIColor.clear.cgColor // remove white curved line
            iv.layer.borderWidth = 0
            // Improve downscaling quality
            iv.layer.contentsScale = UIScreen.main.scale
            iv.layer.magnificationFilter = .linear
            iv.layer.minificationFilter = .trilinear
            NSLayoutConstraint.activate([
                iv.widthAnchor.constraint(equalToConstant: thumbSize),
                iv.heightAnchor.constraint(equalToConstant: thumbSize)
            ])
            avatarsStackView.addArrangedSubview(iv)
        }

        func loadOne(uid: String, completion: @escaping () -> Void) {
            db.collection("users").document(uid).collection("collections").document(collectionId).getDocument { snap, _ in
                if let urlString = snap?.data()? ["avatarThumbnailURL"] as? String, let url = URL(string: urlString) {
                    self.downloadImage(from: url, ignoreCache: true) { image in
                        DispatchQueue.main.async {
                            if currentGen == self.avatarsLoadGeneration { addAvatar(image: image) }
                            completion()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        if currentGen == self.avatarsLoadGeneration { addAvatar(image: nil) }
                        completion()
                    }
                }
            }
        }

        // Fetch the owner's collection doc to get all members
        db.collection("users").document(ownerId).collection("collections").document(collectionId).getDocument { snap, _ in
            var orderedIds: [String] = []
            var seen = Set<String>()
            // Owner first
            if !ownerId.isEmpty { orderedIds.append(ownerId); seen.insert(ownerId) }
            // Then unique members (may already include owner)
            if let members = snap?.data()? ["members"] as? [String] {
                for uid in members where !uid.isEmpty && !seen.contains(uid) {
                    orderedIds.append(uid)
                    seen.insert(uid)
                }
            }
            if orderedIds.isEmpty { return }

            // Load all avatars (no cap) in order
            let group = DispatchGroup()
            for uid in orderedIds {
                group.enter()
                loadOne(uid: uid) { group.leave() }
            }
        }
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
        // Handle events section
        if indexPath.section == 0 {
            guard indexPath.row < events.count else {
                return UISwipeActionsConfiguration(actions: [])
            }
            
            // Delete action for events
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
                self?.confirmDeleteEvent(at: indexPath)
                completion(false)
            }
            deleteAction.backgroundColor = .fourthColor
            deleteAction.image = UIImage(systemName: "trash")
            
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        
        // Handle places section
        guard indexPath.row < places.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        
        let place = places[indexPath.row]
        
        // Open in Maps action
        let mapAction = UIContextualAction(style: .normal, title: "Map") { [weak self] (action, view, completion) in
            self?.openPlaceInMapsByName(place.name)
            completion(true)
        }
        mapAction.backgroundColor = .statusSuccess
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
    
    private func confirmDeleteEvent(at indexPath: IndexPath) {
        guard indexPath.row < events.count else { return }
        let event = events[indexPath.row]
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let deleteAction = UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.deleteEvent(at: indexPath)
        }
        AlertManager.present(on: self, title: "Remove Event", message: "Are you sure you want to remove '\(event.title)' from this collection?", style: .error, preferredStyle: .alert, actions: [cancelAction, deleteAction])
    }
    
    private func confirmDeletePlace(at indexPath: IndexPath) {
        // Safety check to prevent crash
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deletePlace(at: indexPath)
        }
        AlertManager.present(on: self, title: "Delete Place", message: "Are you sure you want to remove '\(place.name)' from this collection?", style: .error, preferredStyle: .alert, actions: [cancelAction, deleteAction])
    }
    
    private func deleteEvent(at indexPath: IndexPath) {
        guard indexPath.row < events.count else { return }
        let event = events[indexPath.row]
        showLoadingAlert(title: "Removing Event")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Get references to both collections
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            
        let ownerCollectionRef = db.collection("users")
            .document(collection.userId)
            .collection("collections")
            .document(collection.id)
        
        // Get current collection data
        userCollectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error getting collection: \(error.localizedDescription)")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove event", type: .error)
                }
                return
            }
            
            guard let data = snapshot?.data(),
                  var eventsArray = data["events"] as? [[String: Any]] else {
                print("❌ No events array found in collection")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove event", type: .error)
                }
                return
            }
            
            // Remove the event with matching eventId
            eventsArray.removeAll { eventDict in
                guard let eventId = eventDict["eventId"] as? String else { return false }
                return eventId == event.id
            }
            
            // Create a batch to update both collections
            let batch = db.batch()
            batch.updateData(["events": eventsArray], forDocument: userCollectionRef)
            batch.updateData(["events": eventsArray], forDocument: ownerCollectionRef)
            
            // Commit the batch
            batch.commit { error in
                self?.dismiss(animated: true) {
                    if let error = error {
                        print("❌ Error removing event: \(error.localizedDescription)")
                        ToastManager.showToast(message: "Failed to remove event", type: .error)
                    } else {
                        // Update local data
                        self?.events.remove(at: indexPath.row)
                        self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self?.updatePlacesCountLabel()
                        ToastManager.showToast(message: "Event removed", type: .success)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
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
