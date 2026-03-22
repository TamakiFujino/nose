import UIKit
import FirebaseFirestore
import FirebaseAuth

class CollectionsViewController: UIViewController {
    
    // MARK: - Properties
    private var personalCollections: [PlaceCollection] = []
    private var sharedCollections: [PlaceCollection] = []
    private var collectionEventCounts: [String: Int] = [:] // collectionId -> event count
    private var collectionMemberCounts: [String: Int] = [:] // collectionId -> member count
    private var currentTab: CollectionTab = .personal
    weak var mapManager: MapboxMapManager?
    private static let imageCache = NSCache<NSString, UIImage>()
    private var loadedIconImages: [String: UIImage] = [:] // collectionId -> loaded image
    
    private enum CollectionTab {
        case personal
        case shared
    }
    
    // MARK: - UI Components
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
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CollectionCell")
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0
        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    private lazy var createNewCollectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .white
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        button.addTarget(self, action: #selector(createNewCollectionTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "add_collection_button"
        return button
    }()

    private lazy var emptyStateView: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true

        let imageView = UIImageView(image: UIImage(systemName: "map.fill"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .thirdColor
        imageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "collections_empty_personal")
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .thirdColor
        label.textAlignment = .center
        label.numberOfLines = 0

        container.addSubview(imageView)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }()

    private lazy var sharedEmptyStateView: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true

        let imageView = UIImageView(image: UIImage(systemName: "person.2.fill"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .thirdColor
        imageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "collections_empty_shared")
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .thirdColor
        label.textAlignment = .center
        label.numberOfLines = 0

        container.addSubview(imageView)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "collections_my_collections")
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .fourthColor
        return indicator
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Update map in case collections were already loaded
        updateMapWithCollections()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    func configureSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        
        // Create a small detent identifier (approximately 20% of screen height)
        let smallDetentIdentifier = UISheetPresentationController.Detent.Identifier("small")
        let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallDetentIdentifier) { context in
            return context.maximumDetentValue * 0.2 // 20% of screen
        }
        
        // Set detents: small (minimized) and large (full)
        sheet.detents = [smallDetent, .large()]
        
        // Set the initial detent to large (full modal)
        sheet.selectedDetentIdentifier = .large
        
        // Allow interaction with the map behind when minimized
        // This makes the map interactive when the modal is at the small detent
        sheet.largestUndimmedDetentIdentifier = smallDetentIdentifier
        
        // Enable grabber for better UX
        sheet.prefersGrabberVisible = true

        // Allow dismissing by dragging down from any detent
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false

        // Listen for detent changes
        sheet.delegate = self
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(categoryTabScrollView)
        categoryTabScrollView.addSubview(categoryTabStackView)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(sharedEmptyStateView)
        view.addSubview(loadingIndicator)
        view.addSubview(createNewCollectionButton)

        // Setup category tabs
        setupCategoryTabs()
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Category tabs scroll view
            categoryTabScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            categoryTabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryTabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryTabScrollView.heightAnchor.constraint(equalToConstant: 30),
            
            // Category tabs stack view inside scroll view
            categoryTabStackView.leadingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            categoryTabStackView.trailingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            categoryTabStackView.topAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.topAnchor),
            categoryTabStackView.bottomAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.bottomAnchor),
            categoryTabStackView.heightAnchor.constraint(equalTo: categoryTabScrollView.frameLayoutGuide.heightAnchor),
            
            tableView.topAnchor.constraint(equalTo: categoryTabScrollView.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Empty state view (centered in tableView area)
            emptyStateView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -60),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            // Shared empty state view (centered in tableView area)
            sharedEmptyStateView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            sharedEmptyStateView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -60),
            sharedEmptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            sharedEmptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            // Loading indicator (centered in tableView area)
            loadingIndicator.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),

            // Create new collection button (floating over tableView bottom-right)
            createNewCollectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            createNewCollectionButton.bottomAnchor.constraint(equalTo: tableView.bottomAnchor, constant: -32),
            createNewCollectionButton.widthAnchor.constraint(equalToConstant: 44),
            createNewCollectionButton.heightAnchor.constraint(equalToConstant: 44),
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
    
    // MARK: - Tab Management
    private func setupCategoryTabs() {
        let tabs: [(CollectionTab, String)] = [(.personal, String(localized: "collections_your_collections")), (.shared, String(localized: "collections_from_friends"))]
        for (index, (tab, title)) in tabs.enumerated() {
            let button = createTabButton(title: title, tag: index, tab: tab)
            categoryTabStackView.addArrangedSubview(button)
        }
        updateTabButtonStates()
    }
    
    private func createTabButton(title: String, tag: Int, tab: CollectionTab) -> UIButton {
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
        let tabs: [CollectionTab] = [.personal, .shared]
        for (index, tab) in tabs.enumerated() {
            guard index < categoryTabStackView.arrangedSubviews.count,
                  let button = categoryTabStackView.arrangedSubviews[index] as? UIButton else { continue }
            
            let isSelected = tab == currentTab
            // Active tab: themeBlue background with white text
            // Inactive tab: secondColor background with black text
            button.backgroundColor = isSelected ? .themeBlue : .secondColor
            button.setTitleColor(isSelected ? .white : .black, for: .normal)
            button.layer.cornerRadius = 16
        }
    }
    
    private var isSheetMinimized: Bool {
        sheetPresentationController?.selectedDetentIdentifier != .large
    }

    private func updateEmptyState() {
        let personalEmpty = currentTab == .personal && personalCollections.isEmpty
        let sharedEmpty = currentTab == .shared && sharedCollections.isEmpty
        emptyStateView.isHidden = isSheetMinimized || !personalEmpty
        sharedEmptyStateView.isHidden = isSheetMinimized || !sharedEmpty
        createNewCollectionButton.isHidden = isSheetMinimized || currentTab == .shared
    }

    @objc private func createNewCollectionTapped() {
        let modalVC = NewCollectionModalViewController()
        modalVC.delegate = self
        modalVC.modalPresentationStyle = .overCurrentContext
        modalVC.modalTransitionStyle = .crossDissolve
        present(modalVC, animated: true)
    }

    @objc private func categoryTabTapped(_ sender: UIButton) {
        guard sender.tag < 2 else { return }
        let tabs: [CollectionTab] = [.personal, .shared]
        let tab = tabs[sender.tag]
        currentTab = tab
        updateTabButtonStates()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateMapWithCollections() {
        // Combine all collections (personal + shared) and show on map
        let allCollections = personalCollections + sharedCollections
        mapManager?.showCollectionPlacesOnMap(allCollections)
    }
    
    private func showLoadingAlert(title: String) {
        LoadingView.shared.showAlertLoading(title: title, on: self)
    }
    
    private func cacheCollectionsForExtension() {
        let simpleCollections = personalCollections.map { ["id": $0.id, "name": $0.name] }
        if let defaults = UserDefaults(suiteName: "group.com.tamakifujino.nose") {
            defaults.set(simpleCollections, forKey: "CachedCollections")
            defaults.synchronize()
        }
    }
    
    // MARK: - Data Loading
    private func loadCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        // Show loading indicator
        DispatchQueue.main.async { [weak self] in
            self?.loadingIndicator.startAnimating()
        }

        // Create groups to track loading progress
        let memberCountGroup = DispatchGroup()
        var ownedCollectionsLoaded = false
        var sharedCollectionsLoaded = false
        var reloadSetup = false
        
        // Helper to check if we should reload the table
        let checkAndReload: () -> Void = { [weak self] in
            guard let self = self else { return }
            if ownedCollectionsLoaded && sharedCollectionsLoaded && !reloadSetup {
                reloadSetup = true
                // Wait for all member counts to load before reloading table
                memberCountGroup.notify(queue: .main) {
                    self.loadingIndicator.stopAnimating()
                    self.tableView.reloadData()
                    self.updateEmptyState()
                    // Update map with all collections (personal + shared)
                    self.updateMapWithCollections()
                    // Cache for Share Extension
                    self.cacheCollectionsForExtension()
                }
            }
        }
        
        // Load owned collections
        let ownedCollectionsRef = FirestorePaths.collections(userId: currentUserId)
        
        ownedCollectionsRef.whereField("isOwner", isEqualTo: true).getDocuments { [weak self] snapshot, error in
            if let error = error {
                Logger.log("Error loading owned collections: \(error.localizedDescription)", level: .error, category: "Collections")
                ownedCollectionsLoaded = true
                checkAndReload()
                return
            }
            
            self?.personalCollections = snapshot?.documents.compactMap { document in
                var data = document.data()
                data["id"] = document.documentID
                data["isOwner"] = true
                
                // If status is missing, treat it as active
                if data["status"] == nil {
                    data["status"] = PlaceCollection.Status.active.rawValue
                }
                
                // Store events count for this collection
                if let eventsArray = data["events"] as? [[String: Any]] {
                    self?.collectionEventCounts[document.documentID] = eventsArray.count
                } else {
                    self?.collectionEventCounts[document.documentID] = 0
                }
                
                if let collection = PlaceCollection(dictionary: data) {
                    // Load member count for this collection
                    memberCountGroup.enter()
                    self?.loadMemberCount(for: collection.id, ownerId: collection.userId, group: memberCountGroup)
                    return collection
                }
                return nil
            } ?? []
            
            // Filter to only show active collections
            self?.personalCollections = self?.personalCollections.filter { $0.status == .active } ?? []
            
            // Preload icons for owned collections
            self?.preloadCollectionIcons()
            
            ownedCollectionsLoaded = true
            checkAndReload()
        }
        
        // Load shared collections
        let sharedCollectionsRef = FirestorePaths.collections(userId: currentUserId)
        
        sharedCollectionsRef.whereField("isOwner", isEqualTo: false).getDocuments { [weak self] snapshot, error in
            if let error = error {
                Logger.log("Error loading shared collections: \(error.localizedDescription)", level: .error, category: "Collections")
                sharedCollectionsLoaded = true
                checkAndReload()
                return
            }
            
            let group = DispatchGroup()
            var loadedCollections: [PlaceCollection] = []
            
            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                
                // Get the original collection data from the owner's collections
                if let ownerId = data["userId"] as? String,
                   let collectionId = data["id"] as? String {
                    
                    // First check if owner account still exists and is not deleted
                    FirestorePaths.userDoc(ownerId).getDocument { [weak self] ownerSnapshot, ownerError in
                        if let ownerError = ownerError {
                            Logger.log("Error checking owner: \(ownerError.localizedDescription)", level: .error, category: "Collections")
                            group.leave()
                            return
                        }
                        
                        // Check if owner is deleted or doesn't exist
                        let ownerData = ownerSnapshot?.data()
                        let isOwnerDeleted = ownerData?["isDeleted"] as? Bool ?? false
                        
                        if ownerSnapshot?.exists == false || isOwnerDeleted {
                            
                            // Mark this collection as inactive in user's database
                            guard let currentUserId = Auth.auth().currentUser?.uid else {
                                group.leave()
                                return
                            }
                            
                            FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId)
                                .updateData([
                                    "status": "inactive",
                                    "ownerDeleted": true
                                ]) { error in
                                    if let error = error {
                                        Logger.log("Error marking collection as inactive: \(error.localizedDescription)", level: .error, category: "Collections")
                                    }
                                    group.leave()
                                }
                            return
                        }
                        
                        // Owner exists, proceed to load the collection
                    FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId)
                        .getDocument { snapshot, error in
                            defer { group.leave() }
                            
                            if let error = error {
                                Logger.log("Error loading original collection: \(error.localizedDescription)", level: .error, category: "Collections")
                                return
                            }
                            
                            if let originalData = snapshot?.data() {
                                var collectionData = originalData
                                collectionData["id"] = collectionId
                                collectionData["isOwner"] = false
                                
                                // If status is missing, treat it as active
                                if collectionData["status"] == nil {
                                    collectionData["status"] = PlaceCollection.Status.active.rawValue
                                }
                                
                                // Store events count for this collection
                                if let eventsArray = originalData["events"] as? [[String: Any]] {
                                    self?.collectionEventCounts[collectionId] = eventsArray.count
                                } else {
                                    self?.collectionEventCounts[collectionId] = 0
                                }
                                
                                if let collection = PlaceCollection(dictionary: collectionData) {
                                    // Load member count for this collection
                                    memberCountGroup.enter()
                                    self?.loadMemberCount(for: collection.id, ownerId: ownerId, group: memberCountGroup)
                                    loadedCollections.append(collection)
                                }
                            }
                            }
                        }
                } else {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self?.sharedCollections = loadedCollections.filter { $0.status == .active }
                sharedCollectionsLoaded = true
                // Preload all collection icons
                self?.preloadCollectionIcons()
                checkAndReload()
            }
        }
    }
    
    private func preloadCollectionIcons() {
        // Preload icons for all collections (personal + shared) in parallel
        let allCollections = personalCollections + sharedCollections
        
        for collection in allCollections {
            if (collection.iconName?.isEmpty ?? true),
               let iconUrl = collection.iconUrl,
               !iconUrl.isEmpty {
                // Only load if not already cached
                if CollectionsViewController.imageCache.object(forKey: iconUrl as NSString) == nil {
                    loadRemoteIconImage(urlString: iconUrl, collectionId: collection.id)
                }
            }
        }
    }
    
    private func loadMemberCount(for collectionId: String, ownerId: String, group: DispatchGroup) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            group.leave()
            return
        }

        // Get blocked users first
        FirestorePaths.blocked(userId: currentUserId)
            .getDocuments { [weak self] blockedSnapshot, _ in
                let blockedUserIds = blockedSnapshot?.documents.map { $0.documentID } ?? []
                
                // Get the collection document from owner
                FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId)
                    .getDocument { snapshot, _ in
                        defer { group.leave() }
                        
                        if let members = snapshot?.data()?["members"] as? [String] {
                            // Filter out blocked users
                            let activeMembers = members.filter { !blockedUserIds.contains($0) }
                            DispatchQueue.main.async {
                                self?.collectionMemberCounts[collectionId] = activeMembers.count
                            }
                        } else {
                            DispatchQueue.main.async {
                                self?.collectionMemberCounts[collectionId] = 0
                            }
                        }
                    }
            }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CollectionsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTab == .personal ? personalCollections.count : sharedCollections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath)
        let collections = currentTab == .personal ? personalCollections : sharedCollections
        let collection = collections[indexPath.row]
        
        // Set cell rounded corners (background removed)
        cell.layer.cornerRadius = 8
        cell.layer.masksToBounds = true
        
        var content = cell.defaultContentConfiguration()
        content.text = collection.name
        
        // Create icon image for the collection
        var iconImage = createCollectionIconImage(collection: collection)
        
        // Legacy image fallback for older collections that still use icon URLs.
        if (collection.iconName?.isEmpty ?? true),
           let iconUrl = collection.iconUrl,
           !iconUrl.isEmpty {
            // First check if already loaded in memory
            if let loadedImage = loadedIconImages[collection.id] {
                iconImage = CollectionIconRenderer.makeIconImage(iconName: nil, remoteImage: loadedImage, size: 40)
            } else if let cachedImage = CollectionsViewController.imageCache.object(forKey: iconUrl as NSString) {
                // Use cached image immediately
                loadedIconImages[collection.id] = cachedImage
                iconImage = CollectionIconRenderer.makeIconImage(iconName: nil, remoteImage: cachedImage, size: 40)
            } else {
                // Not cached yet, load it (but don't block the UI)
                loadRemoteIconImage(urlString: iconUrl, collectionId: collection.id)
            }
        }
        
        content.image = iconImage
        content.imageProperties.cornerRadius = 20 // Make it circular (40/2)
        content.imageProperties.maximumSize = CGSize(width: 40, height: 40)
        content.imageProperties.tintColor = nil // Let the image handle its own color
        
        // Count both places and events
        let placesCount = collection.places.count
        let eventsCount = collectionEventCounts[collection.id] ?? 0
        let totalCount = placesCount + eventsCount
        let memberCount = collectionMemberCounts[collection.id] ?? 0
        
        // Places/events count first (matching CollectionPlacesViewController order)
        let placesImageAttachment = NSTextAttachment()
        placesImageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.thirdColor)
        let placesImageString = NSAttributedString(attachment: placesImageAttachment)
        
        let placesTextString = NSAttributedString(string: " \(totalCount)", attributes: [
            .foregroundColor: UIColor.thirdColor,
            .font: UIFont.systemFont(ofSize: 14)
        ])
        
        // Member count second
        let memberImageAttachment = NSTextAttachment()
        memberImageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.thirdColor)
        let memberImageString = NSAttributedString(attachment: memberImageAttachment)
        
        let memberTextString = NSAttributedString(string: " \(memberCount)", attributes: [
            .foregroundColor: UIColor.thirdColor,
            .font: UIFont.systemFont(ofSize: 14)
        ])
        
        // No separator, just space between them
        let spaceString = NSAttributedString(string: "  ", attributes: [
            .foregroundColor: UIColor.thirdColor,
            .font: UIFont.systemFont(ofSize: 14)
        ])
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(placesImageString)
        attributedText.append(placesTextString)
        attributedText.append(spaceString)
        attributedText.append(memberImageString)
        attributedText.append(memberTextString)
        
        content.secondaryAttributedText = attributedText
        
        cell.contentConfiguration = content
        
        return cell
    }
    
    private func createCollectionIconImage(collection: PlaceCollection) -> UIImage? {
        let size: CGFloat = 40
        return CollectionIconRenderer.makeIconImage(
            iconName: collection.iconName,
            remoteImage: loadedIconImages[collection.id],
            size: size
        )
    }
    
    private func createIconImageWithBackground(remoteImage: UIImage, size: CGFloat) -> UIImage? {
        CollectionIconRenderer.makeIconImage(iconName: nil, remoteImage: remoteImage, size: size)
    }
    
    private func loadRemoteIconImage(urlString: String, collectionId: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Check cache first
        if let cachedImage = CollectionsViewController.imageCache.object(forKey: urlString as NSString) {
            loadedIconImages[collectionId] = cachedImage
            return
        }
        
        // Download image
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else {
                return
            }
            
            // Cache the image
            CollectionsViewController.imageCache.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                self.loadedIconImages[collectionId] = image
                // Reload the specific cell if visible
                let collections = self.currentTab == .personal ? self.personalCollections : self.sharedCollections
                if let index = collections.firstIndex(where: { $0.id == collectionId }) {
                    let indexPath = IndexPath(row: index, section: 0)
                    if self.tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                        self.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }
        }.resume()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let collections = currentTab == .personal ? personalCollections : sharedCollections
        let collection = collections[indexPath.row]
        let placesVC = CollectionPlacesViewController(collection: collection)
        if let sheet = placesVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(placesVC, animated: true)
    }
}

// MARK: - UISheetPresentationControllerDelegate
extension CollectionsViewController: UISheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {
        updateEmptyState()
    }
}

// MARK: - NewCollectionModalViewControllerDelegate
extension CollectionsViewController: NewCollectionModalViewControllerDelegate {
    func newCollectionModalViewController(_ controller: NewCollectionModalViewController, didCreateCollection collectionId: String) {
        loadCollections()
    }
}
