import UIKit
import GooglePlaces
import FirebaseAuth

class CollectionPlacesViewController: UIViewController {

    // MARK: - Properties

    let collection: PlaceCollection
    var places: [PlaceCollection.Place] = []
    var events: [Event] = []
    var sessionToken: GMSAutocompleteSessionToken?
    var sharedFriendsCount: Int = 0
    var avatarsLoadGeneration: Int = 0
    var currentIconName: String?
    var currentIconUrl: String?

    // Heart tracking: placeId -> [userId] array
    var placeHearts: [String: [String]] = [:]
    var collectionMembers: [String] = []

    // Debouncing for heart writes
    var pendingHeartChanges: [String: [String]] = [:]
    var heartDebounceTimer: Timer?
    let heartDebounceInterval: TimeInterval = 0.8

    static let imageCache = NSCache<NSString, UIImage>()

    // Tab selection
    enum Tab: Int {
        case places = 0
        case events = 1
    }
    var selectedTab: Tab = .places
    var futureEvents: [Event] = []
    var pastEvents: [Event] = []

    // MARK: - UI Components

    lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        return view
    }()

    
    // Removed old avatar preview loading indicator

    lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .fourthColor
        button.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "more_button"
        button.accessibilityLabel = "More"
        return button
    }()

    lazy var tableView: UITableView = {
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

    lazy var collectionIconImageView: UIImageView = {
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
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = collection.name
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    lazy var sharedFriendsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .thirdColor
        
        // Create attributed string with icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.thirdColor)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " 0", attributes: [
            .foregroundColor: UIColor.thirdColor
        ])
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        label.attributedText = attributedText
        label.accessibilityLabel = "Number of shared friends"
        label.accessibilityValue = "0"
        label.accessibilityIdentifier = "shared_friends_count_label"
        return label
    }()

    lazy var placesCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .thirdColor
        
        // Create attributed string with icon
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.thirdColor)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " 0", attributes: [
            .foregroundColor: UIColor.thirdColor
        ])
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        label.attributedText = attributedText
        label.accessibilityLabel = "Number of places saved"
        label.accessibilityValue = "0"
        label.accessibilityIdentifier = "places_count_label"
        return label
    }()
    
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .clear
        return imageView
    }()

    lazy var avatarsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.spacing = -180 // adjust overlap to -100
        return stack
    }()

    lazy var customizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Customize avatar", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .themeBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 24 // rounded here only
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(customizeAvatarTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var categoryTabScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        return scrollView
    }()
    
    lazy var categoryTabStackView: UIStackView = {
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.fetchCollection(userId: currentUserId, collectionId: collection.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let updatedCollection):
                DispatchQueue.main.async {
                    self.places = updatedCollection.places
                    self.tableView.reloadData()
                    self.updatePlacesCountLabel()
                }
            case .failure(let error):
                Logger.log("Error refreshing collection: \(error.localizedDescription)", level: .error, category: "Collection")
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

        // Show menu button for all collections (owner and shared)
        menuButton.isHidden = false
        
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
            // Active tab: themeBlue background with white text
            // Inactive tab: secondColor background with black text
            button.backgroundColor = isSelected ? .themeBlue : .secondColor
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
        CollectionDataService.shared.loadPlaceHearts(ownerId: collection.userId, collectionId: collection.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.placeHearts = data.hearts
                self.collectionMembers = data.members
                self.sortPlacesByHeartCount()
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                Logger.log("Error loading place hearts: \(error.localizedDescription)", level: .error, category: "Collection")
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
    
    func toggleHeart(for placeId: String, isHearted: Bool) {
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
            let indexPath = IndexPath(row: index, section: 0)
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

        let changesToWrite = pendingHeartChanges
        pendingHeartChanges.removeAll()

        CollectionDataService.shared.flushHeartChanges(
            pendingChanges: changesToWrite,
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        ) { [weak self] error in
            if let error = error {
                Logger.log("Error saving hearts: \(error.localizedDescription)", level: .error, category: "Collection")
                ToastManager.showToast(message: "Failed to save hearts", type: .error)
                self?.loadPlaceHearts()
            }
        }
    }
    
    private func loadEvents() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.loadEvents(userId: currentUserId, collectionId: collection.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self.events = data.events
                    self.categorizeEvents()
                    self.updatePlacesCountLabel()
                    self.tableView.reloadData()

                    if data.events.count != data.rawCount {
                        self.cleanupDeletedEvents(activeEvents: data.events)
                    }
                }
            case .failure(let error):
                Logger.log("Error loading events: \(error.localizedDescription)", level: .error, category: "Collection")
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
        let activeEventIds = Set(activeEvents.map { $0.id })

        CollectionDataService.shared.cleanupDeletedEvents(
            activeEventIds: activeEventIds,
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        )
    }

    func loadSharedFriendsCount() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.loadSharedFriendsCount(
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        ) { [weak self] result in
            switch result {
            case .success(let count):
                self?.sharedFriendsCount = count
                self?.updateSharedFriendsLabel()
            case .failure(let error):
                Logger.log("Error loading shared friends count: \(error.localizedDescription)", level: .error, category: "Collection")
            }
        }
    }

    private func updateSharedFriendsLabel() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.thirdColor)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let textString = NSAttributedString(string: " \(sharedFriendsCount)", attributes: [
            .foregroundColor: UIColor.thirdColor
        ])
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        sharedFriendsLabel.attributedText = attributedText
        sharedFriendsLabel.accessibilityValue = "\(sharedFriendsCount)"
        // Show the label now that the count is loaded
        sharedFriendsLabel.isHidden = false
    }

    func updatePlacesCountLabel() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.thirdColor)
        let imageString = NSAttributedString(attachment: imageAttachment)
        
        let totalItems = places.count + events.count
        let textString = NSAttributedString(string: " \(totalItems)", attributes: [
            .foregroundColor: UIColor.thirdColor
        ])
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(imageString)
        attributedText.append(textString)
        
        placesCountLabel.attributedText = attributedText
        placesCountLabel.accessibilityValue = "\(totalItems)"
    }
    
    func showLoadingAlert(title: String) {
        LoadingView.shared.showAlertLoading(title: title, on: self)
    }
}

