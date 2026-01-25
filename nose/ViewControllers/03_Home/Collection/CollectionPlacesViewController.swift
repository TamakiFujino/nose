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
    private var currentIconName: String? // Track current icon name for updates (SF Symbol)
    private var currentIconUrl: String? // Track current icon URL for updates (custom image)
    
    // Heart tracking: placeId -> [userId] array
    private var placeHearts: [String: [String]] = [:]
    private var collectionMembers: [String] = [] // Users who have access to this collection
    
    // Debouncing for heart writes
    private var pendingHeartChanges: [String: [String]] = [:] // placeId -> hearts array to write
    private var heartDebounceTimer: Timer?
    private let heartDebounceInterval: TimeInterval = 0.8 // Wait 0.8 seconds before writing
    
    private static let imageCache = NSCache<NSString, UIImage>()
    
    // Tab selection
    private enum Tab: Int {
        case places = 0
        case events = 1
    }
    private var selectedTab: Tab = .places
    private var futureEvents: [Event] = []
    private var pastEvents: [Event] = []

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
        tableView.separatorStyle = .none
        return tableView
    }()

    private lazy var collectionIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit // Preserve aspect ratio
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true // Ensure corner radius works properly
        imageView.layer.cornerRadius = 30 // 60 / 2 for circular appearance
        // Icon tap is disabled - editing is done through "Edit Collection" menu option
        imageView.isUserInteractionEnabled = false
        return imageView
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
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.secondaryLabel)
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

    private lazy var customizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Customize avatar", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .fourthColor
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 24 // rounded here only
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(customizeAvatarTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var categoryTabScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        return scrollView
    }()
    
    private lazy var categoryTabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
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
        currentIconName = collection.iconName // Initialize with collection's icon (SF Symbol)
        currentIconUrl = collection.iconUrl // Initialize with collection's icon URL (custom image)
        setupUI()
        // Hide shared friends label until count is loaded
        sharedFriendsLabel.isHidden = true
        // Preload icon immediately if it's a remote URL
        preloadCollectionIconIfNeeded()
        loadPlaces()
        loadSharedFriendsCount()
        sessionToken = GMSAutocompleteSessionToken()

        // Listen for avatar thumbnail updates
        NotificationCenter.default.addObserver(self, selector: #selector(handleAvatarThumbnailUpdatedNotification(_:)), name: Notification.Name("AvatarThumbnailUpdated"), object: nil)
        
        // Listen for collection updates to refresh places
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPlaces), name: NSNotification.Name("RefreshCollections"), object: nil)
        
        // prefillAvatarImageIfCached() // disabled since big avatar image is not shown
    }
    
    @objc private func refreshPlaces() {
        // Reload places from Firestore when collections are updated (e.g., after copying a place)
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Reload collection from Firestore to get latest places
        let collectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        collectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error refreshing collection: \(error.localizedDescription)", level: .error, category: "Collection")
                return
            }
            
            guard let data = snapshot?.data(),
                  let updatedCollection = PlaceCollection(dictionary: data) else {
                Logger.log("Failed to parse refreshed collection", level: .error, category: "Collection")
                return
            }
            
            // Update the collection property with fresh data
            // Note: collection is let, so we can't reassign it, but we can update places
            DispatchQueue.main.async {
                self.places = updatedCollection.places
                self.tableView.reloadData()
                self.updatePlacesCountLabel()
            }
        }
    }
    
    private func preloadCollectionIconIfNeeded() {
        let iconUrlToUse = currentIconUrl ?? collection.iconUrl
        if let iconUrl = iconUrlToUse, !iconUrl.isEmpty {
            // Check if already cached
            if CollectionPlacesViewController.imageCache.object(forKey: iconUrl as NSString) == nil {
                // Preload the icon
                loadRemoteIconImage(urlString: iconUrl) { [weak self] image in
                    DispatchQueue.main.async {
                        guard let self = self, let image = image else { return }
                        // Update the icon display immediately if loaded
                        self.collectionIconImageView.image = self.createIconImageWithBackground(remoteImage: image)
                    }
                }
            } else {
                // Already cached, use it immediately
                if let cachedImage = CollectionPlacesViewController.imageCache.object(forKey: iconUrl as NSString) {
                    collectionIconImageView.image = createIconImageWithBackground(remoteImage: cachedImage)
                }
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(headerView)
        headerView.addSubview(collectionIconImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(menuButton)
        headerView.addSubview(sharedFriendsLabel)
        headerView.addSubview(placesCountLabel)
        headerView.addSubview(avatarsStackView)
        headerView.addSubview(customizeButton)
        view.addSubview(categoryTabScrollView)
        categoryTabScrollView.addSubview(categoryTabStackView)
        view.addSubview(tableView)

        // Hide menu button if user is not the owner
        menuButton.isHidden = !collection.isOwner
        
        // Icon editing is now done through "Edit Collection" menu option, not by tapping icon
        
        // Set initial icon image
        updateCollectionIconDisplay()
        
        setupCategoryTabs()

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            collectionIconImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            collectionIconImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            collectionIconImageView.widthAnchor.constraint(equalToConstant: 60),
            collectionIconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: collectionIconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: collectionIconImageView.centerYAnchor),

            menuButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            menuButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),

            placesCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            placesCountLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            sharedFriendsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            sharedFriendsLabel.leadingAnchor.constraint(equalTo: placesCountLabel.trailingAnchor, constant: 16),

            avatarsStackView.topAnchor.constraint(equalTo: sharedFriendsLabel.bottomAnchor, constant: 8),
            avatarsStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 0),
            avatarsStackView.heightAnchor.constraint(equalToConstant: 216),

            customizeButton.topAnchor.constraint(equalTo: avatarsStackView.bottomAnchor, constant: 6),
            customizeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            customizeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            customizeButton.heightAnchor.constraint(equalToConstant: 48),

            headerView.bottomAnchor.constraint(equalTo: customizeButton.bottomAnchor),
            
            // Category tabs scroll view
            categoryTabScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            categoryTabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryTabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryTabScrollView.heightAnchor.constraint(equalToConstant: 30),
            
            // Category tabs stack view inside scroll view
            categoryTabStackView.leadingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            categoryTabStackView.trailingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            categoryTabStackView.topAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.topAnchor),
            categoryTabStackView.bottomAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.bottomAnchor),
            categoryTabStackView.heightAnchor.constraint(equalTo: categoryTabScrollView.frameLayoutGuide.heightAnchor),

            tableView.topAnchor.constraint(equalTo: categoryTabScrollView.bottomAnchor),
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Flush any pending heart changes before leaving
        heartDebounceTimer?.invalidate()
        flushPendingHeartChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        heartDebounceTimer?.invalidate()
    }

    // MARK: - Actions

    @objc private func menuButtonTapped() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Edit Collection action (only for owner)
        if collection.isOwner {
            let editAction = UIAlertAction(title: "Edit Collection", style: .default) { [weak self] _ in
                self?.editCollection()
            }
            editAction.setValue(UIImage(systemName: "pencil"), forKey: "image")
            alertController.addAction(editAction)
        }
        
        // Share with friends action
        let shareAction = UIAlertAction(title: "Share with Friends", style: .default) { [weak self] _ in
            self?.shareCollection()
        }
        shareAction.setValue(UIImage(systemName: "square.and.arrow.up"), forKey: "image")
        alertController.addAction(shareAction)
        
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
    
    private func editCollection() {
        let editModal = EditCollectionModalViewController(collection: collection)
        editModal.delegate = self
        editModal.modalPresentationStyle = .overFullScreen
        editModal.modalTransitionStyle = .crossDissolve
        present(editModal, animated: true)
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
    
    private func updateCollectionIcon(iconName: String?, iconUrl: String?) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Show loading indicator
        let alert = UIAlertController(title: "Updating icon...", message: nil, preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true)
        
        // Get references to both collections (user's copy and owner's copy)
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // Create a batch write to update both
        let batch = db.batch()
        
        // Prepare update data - support both iconName (SF Symbol) and iconUrl (custom image)
        var updateData: [String: Any] = [:]
        
        if let iconUrl = iconUrl, !iconUrl.isEmpty {
            // Using custom image URL - set it and clear iconName
            updateData["iconUrl"] = iconUrl
            updateData["iconName"] = FieldValue.delete()
        } else if let iconName = iconName, !iconName.isEmpty {
            // Using SF Symbol - set it and clear iconUrl
            updateData["iconName"] = iconName
            updateData["iconUrl"] = FieldValue.delete()
        }
        
        // Only update if we have changes
        guard !updateData.isEmpty else {
            // No changes, just dismiss
            alert.dismiss(animated: true)
            return
        }
        
        batch.updateData(updateData, forDocument: userCollectionRef)
        batch.updateData(updateData, forDocument: ownerCollectionRef)
        
        // Commit the batch
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                // Dismiss the local alert directly
                alert.dismiss(animated: true) {
                    guard let self = self else { return }
                    
                    if let error = error {
                        Logger.log("Error updating collection icon: \(error.localizedDescription)", level: .error, category: "Collection")
                        ToastManager.showToast(message: "Failed to update icon", type: .error)
                    } else {
                        // Update the current icon name/URL and refresh the image view
                        self.currentIconName = iconName
                        self.currentIconUrl = iconUrl
                        self.updateCollectionIconDisplay()
                        ToastManager.showToast(message: "Icon updated", type: .success)
                        // Post notification to refresh collections
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
    }
    
    private func shareCollection() {
        let shareVC = ShareCollectionViewController(collection: collection)
        shareVC.delegate = self
        let navController = UINavigationController(rootViewController: shareVC)
        present(navController, animated: true)
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
    
    // MARK: - Tab Management
    
    private func setupCategoryTabs() {
        let tabs: [(Tab, String)] = [(.places, "Places"), (.events, "Events")]
        for (index, (tab, title)) in tabs.enumerated() {
            let button = createTabButton(title: title, tag: index, tab: tab)
            categoryTabStackView.addArrangedSubview(button)
        }
        updateTabButtonStates()
    }
    
    private func createTabButton(title: String, tag: Int, tab: Tab) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .secondColor
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        button.layer.masksToBounds = true
        button.tag = tag
        button.addTarget(self, action: #selector(categoryTabTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Padding so text doesn't touch edges
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        // Set height constraint
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        // Minimum width for easy tapping, but size to content
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        
        // Allow button to size to content
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return button
    }
    
    private func updateTabButtonStates() {
        let tabs: [Tab] = [.places, .events]
        for (index, tab) in tabs.enumerated() {
            guard index < categoryTabStackView.arrangedSubviews.count,
                  let button = categoryTabStackView.arrangedSubviews[index] as? UIButton else { continue }
            
            let isSelected = tab == selectedTab
            // Active tab: darker background with white text
            // Inactive tab: secondColor background with black text
            button.backgroundColor = isSelected ? .fourthColor : .secondColor
            button.setTitleColor(isSelected ? .white : .black, for: .normal)
            button.layer.cornerRadius = 16
        }
    }
    
    @objc private func categoryTabTapped(_ sender: UIButton) {
        guard sender.tag < 2 else { return }
        let tabs: [Tab] = [.places, .events]
        let tab = tabs[sender.tag]
        selectedTab = tab
        updateTabButtonStates()
        tableView.reloadData()
    }
    
    // MARK: - Data Loading

    private func loadPlaces() {
        places = collection.places
        loadPlaceHearts()
        loadEvents()
        updatePlacesCountLabel()
        tableView.reloadData()
    }
    
    private func loadPlaceHearts() {
        let db = Firestore.firestore()
        
        // Always load hearts from the owner's collection (single source of truth)
        // This ensures all users see the same heart data
        FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Error loading place hearts: \(error.localizedDescription)", level: .error, category: "Collection")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    self.placeHearts = [:]
                    self.collectionMembers = []
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                    return
                }
                
                // Load hearts data
                if let heartsData = data["placeHearts"] as? [String: [String]] {
                    self.placeHearts = heartsData
                } else {
                    self.placeHearts = [:]
                }
                
                // Load members list
                if let members = data["members"] as? [String] {
                    self.collectionMembers = members
                } else {
                    // Default to owner if no members field
                    self.collectionMembers = [self.collection.userId]
                }
                
                // Sort places by heart count (most hearts first)
                self.sortPlacesByHeartCount()
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
    }
    
    private func sortPlacesByHeartCount() {
        places.sort { place1, place2 in
            let hearts1 = placeHearts[place1.placeId]?.count ?? 0
            let hearts2 = placeHearts[place2.placeId]?.count ?? 0
            // Sort by heart count descending (most hearts first)
            // If same heart count, maintain original order
            return hearts1 > hearts2
        }
    }
    
    private func toggleHeart(for placeId: String, isHearted: Bool) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            ToastManager.showToast(message: "Please sign in to heart spots", type: .error)
            return
        }
        
        // Check if user is a member of this collection
        guard collectionMembers.contains(currentUserId) else {
            ToastManager.showToast(message: "Only collection members can heart spots", type: .error)
            return
        }
        
        // Get current hearts for this place
        var currentHearts = placeHearts[placeId] ?? []
        
        if isHearted {
            // Add user to hearts if not already there
            if !currentHearts.contains(currentUserId) {
                currentHearts.append(currentUserId)
            }
        } else {
            // Remove user from hearts
            currentHearts.removeAll { $0 == currentUserId }
        }
        
        // Update local state immediately for responsive UI
        placeHearts[placeId] = currentHearts.isEmpty ? nil : currentHearts
        
        // Update the specific cell directly (without reloading to prevent image flicker)
        if let index = places.firstIndex(where: { $0.placeId == placeId }) {
            let indexPath = IndexPath(row: index, section: 1)
            if let cell = tableView.cellForRow(at: indexPath) as? PlaceTableViewCell {
                cell.updateHeartState(isHearted: isHearted, heartCount: currentHearts.count)
            }
        }
        
        // Store pending change for debounced write
        pendingHeartChanges[placeId] = currentHearts
        
        // Reset debounce timer
        heartDebounceTimer?.invalidate()
        heartDebounceTimer = Timer.scheduledTimer(withTimeInterval: heartDebounceInterval, repeats: false) { [weak self] _ in
            self?.flushPendingHeartChanges()
        }
    }
    
    /// Write all pending heart changes to Firestore (called after debounce interval)
    private func flushPendingHeartChanges() {
        guard !pendingHeartChanges.isEmpty else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // Get references to both collections (user's copy and owner's copy)
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // Build update data for all pending changes
        var updateData: [String: Any] = [:]
        for (placeId, hearts) in pendingHeartChanges {
            updateData["placeHearts.\(placeId)"] = hearts.isEmpty ? FieldValue.delete() : hearts
        }
        
        // Clear pending changes before writing
        let changesToWrite = pendingHeartChanges
        pendingHeartChanges.removeAll()
        
        // Batch write to both documents
        let batch = db.batch()
        batch.updateData(updateData, forDocument: userCollectionRef)
        batch.updateData(updateData, forDocument: ownerCollectionRef)
        
        batch.commit { [weak self] error in
            if let error = error {
                Logger.log("Error saving hearts: \(error.localizedDescription)", level: .error, category: "Collection")
                ToastManager.showToast(message: "Failed to save hearts", type: .error)
                
                // Revert local state on error
                self?.loadPlaceHearts()
            }
        }
    }
    
    private func loadEvents() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Load events from the collection
        FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    Logger.log("Error loading events: \(error.localizedDescription)", level: .error, category: "Collection")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let eventsArray = data["events"] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        self?.events = []
                        self?.updatePlacesCountLabel()
                        self?.tableView.reloadData()
                    }
                    return
                }
                
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
                        Logger.log("Skipping event with incomplete data", level: .warn, category: "Collection")
                        continue
                    }
                    
                    let latitude = eventDict["latitude"] as? Double ?? 0.0
                    let longitude = eventDict["longitude"] as? Double ?? 0.0
                    let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    
                    // Verify the event still exists in the user's events collection
                    group.enter()
                    FirestorePaths.eventDoc(userId: userId, eventId: eventId, db: db)
                        .getDocument { eventSnapshot, eventError in
                            // Check if event exists and is active
                            guard let eventData = eventSnapshot?.data(),
                                  let status = eventData["status"] as? String,
                                  status == "active" else {
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
                    self?.events = loadedEvents
                    self?.categorizeEvents()
                    self?.updatePlacesCountLabel()
                    self?.tableView.reloadData()
                    
                    // Clean up deleted events from the collection if count doesn't match
                    if loadedEvents.count != eventsArray.count {
                        self?.cleanupDeletedEvents(activeEvents: loadedEvents)
                    }
                }
            }
    }
    
    private func categorizeEvents() {
        let now = Date()
        futureEvents = events.filter { event in
            // Future events include current events (events that haven't ended yet)
            return event.dateTime.endDate >= now
        }
        pastEvents = events.filter { event in
            // Past events are those that have ended
            return event.dateTime.endDate < now
        }
        
        // Sort future events by start date (earliest first)
        futureEvents.sort { $0.dateTime.startDate < $1.dateTime.startDate }
        
        // Sort past events by end date (most recent first)
        pastEvents.sort { $0.dateTime.endDate > $1.dateTime.endDate }
    }
    
    private func cleanupDeletedEvents(activeEvents: [Event]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Create array of active event IDs
        let activeEventIds = Set(activeEvents.map { $0.id })
        
        // Get the collection document
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
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
                        Logger.log("Error cleaning up deleted events: \(error.localizedDescription)", level: .error, category: "Collection")
                    }
                }
            }
        }
    }

    private func loadSharedFriendsCount() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // First get the blocked users
        FirestorePaths.blocked(userId: currentUserId, db: db)
            .getDocuments { [weak self] blockedSnapshot, blockedError in
                if let blockedError = blockedError {
                    Logger.log("Error loading blocked users: \(blockedError.localizedDescription)", level: .error, category: "Collection")
                    return
                }
                
                // Get list of blocked user IDs
                let blockedUserIds = blockedSnapshot?.documents.map { $0.documentID } ?? []
                
                // Now get the collection data
                let collectionRef = FirestorePaths.collectionDoc(userId: self?.collection.userId ?? "", collectionId: self?.collection.id ?? "", db: db)
                
                collectionRef.getDocument { [weak self] snapshot, error in
                    if let error = error {
                        Logger.log("Error loading collection: \(error.localizedDescription)", level: .error, category: "Collection")
                        return
                    }
                    
                    if let members = snapshot?.data()?["members"] as? [String] {
                        // Filter out blocked users but include the owner in the count
                        let activeMembers = members.filter { 
                            !blockedUserIds.contains($0)
                        }
                        self?.sharedFriendsCount = activeMembers.count
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
        // Show the label now that the count is loaded
        sharedFriendsLabel.isHidden = false
    }

    private func updatePlacesCountLabel() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.secondaryLabel)
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
        LoadingView.shared.showAlertLoading(title: title, on: self)
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
        switch selectedTab {
        case .places:
            return 1 // Single section for places
        case .events:
            // Section 0: Future events (including current), Section 1: Past events
            let hasFutureEvents = !futureEvents.isEmpty
            let hasPastEvents = !pastEvents.isEmpty
            if hasFutureEvents && hasPastEvents {
                return 2
            } else if hasFutureEvents || hasPastEvents {
                return 1
            }
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch selectedTab {
        case .places:
            return nil // No section header for places
        case .events:
            let hasFutureEvents = !futureEvents.isEmpty
            let hasPastEvents = !pastEvents.isEmpty
            
            if hasFutureEvents && hasPastEvents {
                return section == 0 ? "Upcoming Events" : "Past Events"
            } else if hasFutureEvents {
                return "Upcoming Events"
            } else if hasPastEvents {
                return "Past Events"
            }
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Return 0 for places tab to ensure no spacing
        if selectedTab == .places {
            return 0
        }
        // Use default height for events sections
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch selectedTab {
        case .places:
            return places.count
        case .events:
            let hasFutureEvents = !futureEvents.isEmpty
            let hasPastEvents = !pastEvents.isEmpty
            
            if hasFutureEvents && hasPastEvents {
                return section == 0 ? futureEvents.count : pastEvents.count
            } else if hasFutureEvents {
                return futureEvents.count
            } else if hasPastEvents {
                return pastEvents.count
            }
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch selectedTab {
        case .places:
            // Place cell
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
            let place = places[indexPath.row]
            cell.delegate = self
            
            // Check if current user is a member (can heart spots)
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            let canHeart = collectionMembers.contains(currentUserId)
            
            // Get heart data for this place
            let heartedUserIds = placeHearts[place.placeId] ?? []
            let isHearted = heartedUserIds.contains(currentUserId)
            let heartCount = heartedUserIds.count
            
            cell.configure(with: place, isHearted: isHearted, heartCount: heartCount, showHeartButton: canHeart)
            return cell
            
        case .events:
            // Event cell
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
            
            let hasFutureEvents = !futureEvents.isEmpty
            let event: Event
            if hasFutureEvents && indexPath.section == 0 {
                event = futureEvents[indexPath.row]
            } else {
                event = pastEvents[indexPath.row]
            }
            
            cell.configureWithEvent(event)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch selectedTab {
        case .places:
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
            
        case .events:
            // Event tapped
            let hasFutureEvents = !futureEvents.isEmpty
            let event: Event
            if hasFutureEvents && indexPath.section == 0 {
                event = futureEvents[indexPath.row]
            } else {
                event = pastEvents[indexPath.row]
            }
            let detailVC = EventDetailViewController(event: event)
            present(detailVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // Map icon tapped - only available for places
        guard selectedTab == .places, indexPath.row < places.count else { return }
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
        FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
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
            // Always render to a square canvas so default and remote look identical in size
            let source = image ?? UIImage(named: "AvatarPlaceholder")
            let processed = renderSquare(image: source)
            let iv = UIImageView(image: processed)
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
            FirestorePaths.collectionDoc(userId: uid, collectionId: collectionId, db: db).getDocument { snap, _ in
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
        FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db).getDocument { snap, _ in
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
    
    // MARK: - Helper Methods
    private func createCollectionIconImage(collection: PlaceCollection?, iconName: String? = nil, iconUrl: String? = nil) -> UIImage? {
        let size: CGFloat = 60 // 1.5x larger (40 * 1.5)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        // Priority: iconUrl > provided iconName > collection's iconUrl > collection's iconName
        let finalIconUrl = iconUrl ?? collection?.iconUrl
        let finalIconName = iconName ?? collection?.iconName
        
        // Check if icon is set - either iconUrl exists (even if not loaded) or iconName exists
        let hasIcon = (finalIconUrl != nil && !finalIconUrl!.isEmpty) || (finalIconName != nil && UIImage(systemName: finalIconName!) != nil)
        
        // If we have an iconUrl, create a placeholder that will be replaced by async loading
        if let iconUrlString = finalIconUrl, let url = URL(string: iconUrlString) {
            // For now, return a placeholder - the actual image will be loaded asynchronously
            // The caller should update the imageView separately
            return renderer.image { context in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                let cgContext = context.cgContext
                
                // Draw background circle - white if icon is set, light gray if no icon
                let path = UIBezierPath(ovalIn: rect)
                cgContext.setFillColor(hasIcon ? UIColor.white.cgColor : UIColor.systemGray5.cgColor)
                cgContext.addPath(path.cgPath)
                cgContext.fillPath()
                
                // Draw white border
                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(1.5)
                cgContext.addPath(path.cgPath)
                cgContext.strokePath()
            }
        }
        
        // Fall back to SF Symbol if iconUrl is not available
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let cgContext = context.cgContext
            
            // Draw background circle - white if icon is set, light gray if no icon
            let path = UIBezierPath(ovalIn: rect)
            cgContext.setFillColor(hasIcon ? UIColor.white.cgColor : UIColor.systemGray5.cgColor)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()
            
            // Draw white border
            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineWidth(1.5)
            cgContext.addPath(path.cgPath)
            cgContext.strokePath()
            
            // Draw icon if available
            if let iconName = finalIconName,
               let iconImage = UIImage(systemName: iconName) {
                let iconSize: CGFloat = 33 // Proportional icon size (22 * 1.5)
                let iconRect = CGRect(
                    x: (size - iconSize) / 2,
                    y: (size - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                
                // Calculate aspect-preserving rect
                let aspect = iconImage.size.width / iconImage.size.height
                var drawRect = iconRect
                
                if aspect > 1 {
                    // Wider than tall
                    let height = iconRect.width / aspect
                    drawRect = CGRect(
                        x: iconRect.origin.x,
                        y: iconRect.origin.y + (iconRect.height - height) / 2,
                        width: iconRect.width,
                        height: height
                    )
                } else {
                    // Taller than wide
                    let width = iconRect.height * aspect
                    drawRect = CGRect(
                        x: iconRect.origin.x + (iconRect.width - width) / 2,
                        y: iconRect.origin.y,
                        width: width,
                        height: iconRect.height
                    )
                }
                
                // Draw icon in darker color
                let tintedIcon = iconImage.withTintColor(.systemGray, renderingMode: .alwaysTemplate)
                tintedIcon.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
            }
        }
    }
    
    private func loadRemoteIconImage(urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Check cache first
        if let cachedImage = CollectionPlacesViewController.imageCache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }
        
        // Download image
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            // Cache the image
            CollectionPlacesViewController.imageCache.setObject(image, forKey: urlString as NSString)
            completion(image)
        }.resume()
    }
    
    private func updateCollectionIconDisplay() {
        // Priority: currentIconUrl > currentIconName > collection.iconUrl > collection.iconName
        let iconUrlToUse = currentIconUrl ?? collection.iconUrl
        let iconNameToUse = currentIconName ?? collection.iconName
        
        // Check if we have an iconUrl
        if let iconUrl = iconUrlToUse, !iconUrl.isEmpty {
            // Load remote image
            loadRemoteIconImage(urlString: iconUrl) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let image = image {
                        // Create circular background for the remote image
                        self.collectionIconImageView.image = self.createIconImageWithBackground(remoteImage: image)
                    } else {
                        // Fallback to SF Symbol if download fails
                        self.collectionIconImageView.image = self.createCollectionIconImage(collection: self.collection, iconName: iconNameToUse, iconUrl: nil)
                    }
                }
            }
        } else {
            // Use SF Symbol
            collectionIconImageView.image = createCollectionIconImage(collection: collection, iconName: iconNameToUse, iconUrl: nil)
        }
    }
    
    private func createIconImageWithBackground(remoteImage: UIImage) -> UIImage? {
        let size: CGFloat = 60
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let cgContext = context.cgContext
            
            // Draw background circle
            let path = UIBezierPath(ovalIn: rect)
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()
            
            // Draw white border
            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineWidth(1.5)
            cgContext.addPath(path.cgPath)
            cgContext.strokePath()
            
            // Draw remote image in the center, preserving aspect ratio
            let imageSize: CGFloat = size * 0.75 // 75% of circle size for padding
            let imageRect = CGRect(
                x: (size - imageSize) / 2,
                y: (size - imageSize) / 2,
                width: imageSize,
                height: imageSize
            )
            
            // Clip to circle
            cgContext.addPath(path.cgPath)
            cgContext.clip()
            
            // Calculate aspect-preserving rect
            let aspect = remoteImage.size.width / remoteImage.size.height
            var drawRect = imageRect
            
            if aspect > 1 {
                // Wider than tall
                let height = imageRect.width / aspect
                drawRect = CGRect(
                    x: imageRect.origin.x,
                    y: imageRect.origin.y + (imageRect.height - height) / 2,
                    width: imageRect.width,
                    height: height
                )
            } else {
                // Taller than wide
                let width = imageRect.height * aspect
                drawRect = CGRect(
                    x: imageRect.origin.x + (imageRect.width - width) / 2,
                    y: imageRect.origin.y,
                    width: width,
                    height: imageRect.height
                )
            }
            
            remoteImage.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
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
        mapAction.backgroundColor = .systemGreen
        mapAction.image = UIImage(systemName: "map")

        // Visited action
        let visitedAction = UIContextualAction(style: .normal, title: place.visited ? "Unvisited" : "Visited") { [weak self] (action, view, completion) in
            self?.toggleVisitedStatus(at: indexPath)
            completion(true) // Dismiss the swipe action immediately
        }
        visitedAction.backgroundColor = UIColor.blueColor
        visitedAction.image = UIImage(systemName: place.visited ? "xmark.circle" : "checkmark.circle")
        
        // Copy action
        let copyAction = UIContextualAction(style: .normal, title: "Copy") { [weak self] (action, view, completion) in
            self?.showCopyOptions(for: place, at: indexPath)
            completion(true)
        }
        copyAction.backgroundColor = .systemOrange
        copyAction.image = UIImage(systemName: "doc.on.doc")
        
        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            self?.confirmDeletePlace(at: indexPath)
            completion(false) // Don't dismiss the swipe action until user confirms
        }
        deleteAction.backgroundColor = .fourthColor
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, copyAction, visitedAction, mapAction])
    }
    
    private func confirmDeleteEvent(at indexPath: IndexPath) {
        guard indexPath.row < events.count else { return }
        let event = events[indexPath.row]
        let alertController = UIAlertController(
            title: "Remove Event",
            message: "Are you sure you want to remove '\(event.title)' from this collection?",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let deleteAction = UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.deleteEvent(at: indexPath)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true)
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
    
    private func showCopyOptions(for place: PlaceCollection.Place, at indexPath: IndexPath) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            ToastManager.showToast(message: "Please sign in to move places", type: .error)
            return
        }
        
        let db = Firestore.firestore()
        
        // Load user's collections
        FirestorePaths.collections(userId: currentUserId, db: db)
            .whereField("status", isEqualTo: "active")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Error loading collections: \(error.localizedDescription)", level: .error, category: "Collection")
                    ToastManager.showToast(message: "Failed to load collections", type: .error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    ToastManager.showToast(message: "No collections found", type: .error)
                    return
                }
                
                // Filter out the current collection
                let otherCollections = documents.compactMap { doc -> (id: String, name: String)? in
                    let data = doc.data()
                    guard doc.documentID != self.collection.id,
                          let name = data["name"] as? String else {
                        return nil
                    }
                    return (id: doc.documentID, name: name)
                }
                
                if otherCollections.isEmpty {
                    ToastManager.showToast(message: "No other collections to move to", type: .info)
                    return
                }
                
                // Show action sheet with collection options
                DispatchQueue.main.async {
                    self.presentCopyActionSheet(for: place, at: indexPath, collections: otherCollections)
                }
            }
    }
    
    private func presentCopyActionSheet(for place: PlaceCollection.Place, at indexPath: IndexPath, collections: [(id: String, name: String)]) {
        let actionSheet = UIAlertController(
            title: "Copy to Collection",
            message: "Select a collection to copy '\(place.name)' to:",
            preferredStyle: .actionSheet
        )
        
        for collection in collections {
            let action = UIAlertAction(title: collection.name, style: .default) { [weak self] _ in
                self?.confirmCopyPlace(place, at: indexPath, toCollection: collection)
            }
            actionSheet.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(cancelAction)
        
        // For iPad support
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(actionSheet, animated: true)
    }
    
    private func confirmCopyPlace(_ place: PlaceCollection.Place, at indexPath: IndexPath, toCollection targetCollection: (id: String, name: String)) {
        let alertController = UIAlertController(
            title: "Copy Place",
            message: "Copy '\(place.name)' to '\(targetCollection.name)'?",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let copyAction = UIAlertAction(title: "Copy", style: .default) { [weak self] _ in
            self?.copyPlace(place, toCollectionId: targetCollection.id)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(copyAction)
        
        present(alertController, animated: true)
    }
    
    private func copyPlace(_ place: PlaceCollection.Place, toCollectionId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        showLoadingAlert(title: "Copying place...")
        
        let db = Firestore.firestore()
        
        // Get source collection reference (owner's if shared, user's if owned)
        let sourceRef = collection.userId != currentUserId ?
            FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db) :
            FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
        
        let targetUserRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: toCollectionId, db: db)
        
        // Step 1: Get place data from source
        sourceRef.getDocument { [weak self] sourceSnapshot, error in
            guard let self = self else { return }
            
            guard error == nil,
                  let sourceData = sourceSnapshot?.data(),
                  let placesArray = sourceData["places"] as? [[String: Any]],
                  let placeIndex = placesArray.firstIndex(where: { ($0["placeId"] as? String) == place.placeId }),
                  let placeId = placesArray[placeIndex]["placeId"] as? String,
                  let name = placesArray[placeIndex]["name"] as? String else {
                self.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to copy place", type: .error)
                }
                return
            }
            
            // Prepare clean place data with proper types
            let cleanPlaceData = self.preparePlaceDataForCopy(
                from: placesArray[placeIndex],
                placeId: placeId,
                name: name
            )
            
            // Step 2: Copy to target collection
            self.copyPlaceToTarget(
                placeData: cleanPlaceData,
                placeId: placeId,
                targetUserRef: targetUserRef,
                toCollectionId: toCollectionId,
                currentUserId: currentUserId,
                db: db
            )
        }
    }
    
    /// Prepares place data for copying by ensuring all required fields exist with correct types
    private func preparePlaceDataForCopy(from placeData: [String: Any], placeId: String, name: String) -> [String: Any] {
        // Helper to convert any numeric type to Double
        func toDouble(_ value: Any?) -> Double {
            if let val = value as? Double { return val }
            if let val = value as? Float { return Double(val) }
            if let val = value as? Int { return Double(val) }
            return 0.0
        }
        
        // Helper to convert rating to Float
        func toFloat(_ value: Any?) -> Float {
            if let val = value as? Float { return val }
            if let val = value as? Double { return Float(val) }
            if let val = value as? String, let floatVal = Float(val) { return floatVal }
            return 0.0
        }
        
        return [
            "placeId": placeId,
            "name": name,
            "formattedAddress": placeData["formattedAddress"] as? String ?? "",
            "phoneNumber": placeData["phoneNumber"] as? String ?? "",
            "rating": toFloat(placeData["rating"]),
            "latitude": toDouble(placeData["latitude"]),
            "longitude": toDouble(placeData["longitude"]),
            "visited": placeData["visited"] as? Bool ?? false,
            "addedAt": Timestamp()
        ]
    }
    
    /// Copies place to target collection (handles both owned and shared collections)
    private func copyPlaceToTarget(
        placeData: [String: Any],
        placeId: String,
        targetUserRef: DocumentReference,
        toCollectionId: String,
        currentUserId: String,
        db: Firestore
    ) {
        targetUserRef.getDocument { [weak self] targetSnapshot, error in
            guard let self = self else { return }
            
            guard error == nil,
                  targetSnapshot?.exists == true,
                  let targetData = targetSnapshot?.data() else {
                self.dismiss(animated: true) {
                    ToastManager.showToast(message: "Target collection not found", type: .error)
                }
                return
            }
            
            // Determine if target is shared collection
            let targetOwnerId = targetData["userId"] as? String ?? currentUserId
            let isTargetShared = targetOwnerId != currentUserId
            
            // Get the correct target reference
            let targetRefToUpdate = isTargetShared ?
                FirestorePaths.collectionDoc(userId: targetOwnerId, collectionId: toCollectionId, db: db) :
                targetUserRef
            
            // For shared collections, verify owner's collection exists
            if isTargetShared {
                targetRefToUpdate.getDocument { [weak self] ownerSnapshot, error in
                    guard let self = self else { return }
                    
                    guard error == nil, ownerSnapshot?.exists == true else {
                        self.dismiss(animated: true) {
                            ToastManager.showToast(message: "Target collection not found", type: .error)
                        }
                        return
                    }
                    
                    self.performCopy(placeData: placeData, targetRef: targetRefToUpdate, userCopyRef: targetUserRef)
                }
            } else {
                // For own collection, check for duplicates first
                let targetPlaces = targetData["places"] as? [[String: Any]] ?? []
                if targetPlaces.contains(where: { ($0["placeId"] as? String) == placeId }) {
                    self.dismiss(animated: true) {
                        ToastManager.showToast(message: "Place already in collection", type: .info)
                    }
                    return
                }
                
                // Update with full array (more reliable than arrayUnion for own collections)
                var updatedPlaces = targetPlaces
                updatedPlaces.append(placeData)
                
                let batch = db.batch()
                batch.updateData(["places": updatedPlaces], forDocument: targetRefToUpdate)
                
                batch.commit { [weak self] error in
                    self?.dismiss(animated: true) {
                        if let error = error {
                            Logger.log("Error copying place: \(error.localizedDescription)", level: .error, category: "Collection")
                            ToastManager.showToast(message: "Failed to copy place", type: .error)
                        } else {
                            ToastManager.showToast(message: "Place copied successfully", type: .success)
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    /// Performs the actual copy operation using arrayUnion
    private func performCopy(placeData: [String: Any], targetRef: DocumentReference, userCopyRef: DocumentReference) {
        let batch = Firestore.firestore().batch()
        batch.updateData(["places": FieldValue.arrayUnion([placeData])], forDocument: targetRef)
        batch.updateData(["places": FieldValue.arrayUnion([placeData])], forDocument: userCopyRef)
        
        batch.commit { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    Logger.log("Error copying place: \(error.localizedDescription)", level: .error, category: "Collection")
                    ToastManager.showToast(message: "Failed to copy place", type: .error)
                } else {
                    ToastManager.showToast(message: "Place copied successfully", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
            }
        }
    }
    
    private func deleteEvent(at indexPath: IndexPath) {
        guard indexPath.row < events.count else { return }
        let event = events[indexPath.row]
        showLoadingAlert(title: "Removing Event")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Get references to both collections
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
            
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // Get current collection data
        userCollectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove event", type: .error)
                }
                return
            }
            
            guard let data = snapshot?.data(),
                  var eventsArray = data["events"] as? [[String: Any]] else {
                Logger.log("No events array found in collection", level: .error, category: "Collection")
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
                        Logger.log("Error removing event: \(error.localizedDescription)", level: .error, category: "Collection")
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
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
            
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // First get the current collection data
        userCollectionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                LoadingView.shared.hideAlertLoading()
                    ToastManager.showToast(message: "Failed to update place status", type: .error)
                return
            }
            
            guard let data = snapshot?.data() else {
                Logger.log("No data found in collection document", level: .error, category: "Collection")
                LoadingView.shared.hideAlertLoading()
                    ToastManager.showToast(message: "Failed to update place status", type: .error)
                return
            }
            
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
                        LoadingView.shared.hideAlertLoading()
                        
                            if let error = error {
                                Logger.log("Error updating place status: \(error.localizedDescription)", level: .error, category: "Collection")
                                ToastManager.showToast(message: "Failed to update place status", type: .error)
                            } else {
                                // Update local data
                            self.places[indexPath.row].visited = newVisitedStatus
                            self.tableView.reloadRows(at: [indexPath], with: .automatic)
                                ToastManager.showToast(message: newVisitedStatus ? "Marked as visited" : "Marked as unvisited", type: .success)
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                        }
                    }
                } else {
                    Logger.log("Place not found in collection data", level: .error, category: "Collection")
                    LoadingView.shared.hideAlertLoading()
                        ToastManager.showToast(message: "Failed to update place status", type: .error)
                }
            } else {
                Logger.log("No places array found in collection data", level: .error, category: "Collection")
                LoadingView.shared.hideAlertLoading()
                    ToastManager.showToast(message: "Failed to update place status", type: .error)
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
        let userCollectionRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
            
        let ownerCollectionRef = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // First get the current collection data
        userCollectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                Logger.log("Error getting collection: \(error.localizedDescription)", level: .error, category: "Collection")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                }
                return
            }
            
            guard let data = snapshot?.data() else {
                Logger.log("No data found in collection document", level: .error, category: "Collection")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                }
                return
            }
            
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
                            Logger.log("Error removing place: \(error.localizedDescription)", level: .error, category: "Collection")
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
                Logger.log("No places array found in collection data", level: .error, category: "Collection")
                self?.dismiss(animated: true) {
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                }
            }
        }
    }
}

// MARK: - PlaceTableViewCellDelegate
extension CollectionPlacesViewController: PlaceTableViewCellDelegate {
    func placeTableViewCell(_ cell: PlaceTableViewCell, didTapHeart placeId: String, isHearted: Bool) {
        toggleHeart(for: placeId, isHearted: isHearted)
    }
}

// MARK: - EditCollectionModalViewControllerDelegate
extension CollectionPlacesViewController: EditCollectionModalViewControllerDelegate {
    func editCollectionModalViewController(_ controller: EditCollectionModalViewController, didUpdateCollection collection: PlaceCollection) {
        // Refresh the UI with updated collection data
        // Reload collection from Firestore to get latest data
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
            .getDocument { [weak self] document, error in
                guard let self = self,
                      let document = document,
                      document.exists,
                      let data = document.data() else {
                    Logger.log("Error fetching updated collection: \(error?.localizedDescription ?? "Unknown error")", level: .error, category: "Collection")
                    return
                }
                
                // Update local collection properties
                if let name = data["name"] as? String {
                    self.titleLabel.text = name
                }
                
                // Update icon
                if let iconUrl = data["iconUrl"] as? String, !iconUrl.isEmpty {
                    self.currentIconUrl = iconUrl
                    self.currentIconName = nil
                } else if let iconName = data["iconName"] as? String, !iconName.isEmpty {
                    self.currentIconName = iconName
                    self.currentIconUrl = nil
                }
                
                self.updateCollectionIconDisplay()
                
                // Post notification to refresh collections list
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                
                ToastManager.showToast(message: "Collection updated", type: .success)
            }
    }
}

// MARK: - ShareCollectionViewControllerDelegate
extension CollectionPlacesViewController: ShareCollectionViewControllerDelegate {
    func shareCollectionViewController(_ controller: ShareCollectionViewController, didSelectFriends friends: [User]) {
        LoadingView.shared.showOverlayLoading(on: view, message: "Sharing Collection...")
        
        CollectionContainerManager.shared.shareCollection(collection, with: friends) { [weak self] error in
            DispatchQueue.main.async {
                LoadingView.shared.hideOverlayLoading()
                
                if let error = error {
                    Logger.log("Error sharing collection: \(error.localizedDescription)", level: .error, category: "Collection")
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
