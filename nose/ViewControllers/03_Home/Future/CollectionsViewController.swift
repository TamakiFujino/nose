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
    weak var mapManager: GoogleMapManager?
    private static let imageCache = NSCache<NSString, UIImage>()
    private var loadedIconImages: [String: UIImage] = [:] // collectionId -> loaded image
    
    private enum CollectionTab {
        case personal
        case shared
    }
    
    // MARK: - UI Components
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
        loadCollections()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSheetPresentation()
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
    private func configureSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        
        // Create a small detent identifier (approximately 10% of screen height)
        let smallDetentIdentifier = UISheetPresentationController.Detent.Identifier("small")
        let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallDetentIdentifier) { context in
            return context.maximumDetentValue * 0.1 // 10% of screen
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
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        // Setup constraints
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
    
    @objc private func segmentedControlChanged(_ sender: UISegmentedControl) {
        currentTab = sender.selectedSegmentIndex == 0 ? .personal : .shared
        tableView.reloadData()
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
            print("💾 Cached \(simpleCollections.count) collections for Share Extension")
        }
    }
    
    // MARK: - Data Loading
    private func loadCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        print("🔍 Loading collections for user: \(currentUserId)")
        
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
                    self.tableView.reloadData()
                    // Update map with all collections (personal + shared)
                    self.updateMapWithCollections()
                    // Cache for Share Extension
                    self.cacheCollectionsForExtension()
                }
            }
        }
        
        // Load owned collections
        let ownedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
        
        print("📂 Loading owned collections from path: \(ownedCollectionsRef.path)")
        
        ownedCollectionsRef.whereField("isOwner", isEqualTo: true).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading owned collections: \(error.localizedDescription)")
                ownedCollectionsLoaded = true
                checkAndReload()
                return
            }
            
            print("📄 Found \(snapshot?.documents.count ?? 0) owned collections")
            
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
                    print("✅ Loaded owned collection: '\(collection.name)' (ID: \(collection.id))")
                    // Load member count for this collection
                    memberCountGroup.enter()
                    self?.loadMemberCount(for: collection.id, ownerId: collection.userId, group: memberCountGroup)
                    return collection
                }
                print("❌ Failed to parse owned collection: \(document.documentID)")
                return nil
            } ?? []
            
            // Filter to only show active collections
            self?.personalCollections = self?.personalCollections.filter { $0.status == .active } ?? []
            print("🎯 Active owned collections: \(self?.personalCollections.count ?? 0)")
            
            // Preload icons for owned collections
            self?.preloadCollectionIcons()
            
            ownedCollectionsLoaded = true
            checkAndReload()
        }
        
        // Load shared collections
        let sharedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
        
        print("📂 Loading shared collections from path: \(sharedCollectionsRef.path)")
        
        sharedCollectionsRef.whereField("isOwner", isEqualTo: false).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading shared collections: \(error.localizedDescription)")
                return
            }
            
            print("📄 Found \(snapshot?.documents.count ?? 0) shared collections")
            
            let group = DispatchGroup()
            var loadedCollections: [PlaceCollection] = []
            
            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                
                // Get the original collection data from the owner's collections
                if let ownerId = data["userId"] as? String,
                   let collectionId = data["id"] as? String {
                    print("🔍 Loading original collection from owner: \(ownerId), collection: \(collectionId)")
                    
                    db.collection("users")
                        .document(ownerId)
                        .collection("collections")
                        .document(collectionId)
                        .getDocument { snapshot, error in
                            defer { group.leave() }
                            
                            if let error = error {
                                print("❌ Error loading original collection: \(error.localizedDescription)")
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
                                    print("✅ Loaded shared collection: '\(collection.name)' (ID: \(collection.id))")
                                    // Load member count for this collection
                                    memberCountGroup.enter()
                                    self?.loadMemberCount(for: collection.id, ownerId: ownerId, group: memberCountGroup)
                                    loadedCollections.append(collection)
                                } else {
                                    print("❌ Failed to parse shared collection: \(collectionId)")
                                }
                            } else {
                                print("❌ No data found for shared collection: \(collectionId)")
                            }
                        }
                } else {
                    print("❌ Invalid shared collection data: \(data)")
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self?.sharedCollections = loadedCollections.filter { $0.status == .active }
                print("🎯 Active shared collections: \(self?.sharedCollections.count ?? 0)")
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
            if let iconUrl = collection.iconUrl, !iconUrl.isEmpty {
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
        let db = Firestore.firestore()
        
        // Get blocked users first
        db.collection("users")
            .document(currentUserId)
            .collection("blocked")
            .getDocuments { [weak self] blockedSnapshot, _ in
                let blockedUserIds = blockedSnapshot?.documents.map { $0.documentID } ?? []
                
                // Get the collection document from owner
                db.collection("users")
                    .document(ownerId)
                    .collection("collections")
                    .document(collectionId)
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
        
        var content = cell.defaultContentConfiguration()
        content.text = collection.name
        
        // Create icon image for the collection
        var iconImage = createCollectionIconImage(collection: collection)
        
        // Check if we have a cached or loaded remote icon
        if let iconUrl = collection.iconUrl, !iconUrl.isEmpty {
            // First check if already loaded in memory
            if let loadedImage = loadedIconImages[collection.id] {
                iconImage = createIconImageWithBackground(remoteImage: loadedImage, size: 40)
            } else if let cachedImage = CollectionsViewController.imageCache.object(forKey: iconUrl as NSString) {
                // Use cached image immediately
                loadedIconImages[collection.id] = cachedImage
                iconImage = createIconImageWithBackground(remoteImage: cachedImage, size: 40)
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
        placesImageAttachment.image = UIImage(systemName: "bookmark.fill")?.withTintColor(.secondaryLabel)
        let placesImageString = NSAttributedString(attachment: placesImageAttachment)
        
        let placesTextString = NSAttributedString(string: " \(totalCount)", attributes: [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 14)
        ])
        
        // Member count second
        let memberImageAttachment = NSTextAttachment()
        memberImageAttachment.image = UIImage(systemName: "person.2.fill")?.withTintColor(.secondaryLabel)
        let memberImageString = NSAttributedString(attachment: memberImageAttachment)
        
        let memberTextString = NSAttributedString(string: " \(memberCount)", attributes: [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 14)
        ])
        
        // No separator, just space between them
        let spaceString = NSAttributedString(string: "  ", attributes: [
            .foregroundColor: UIColor.secondaryLabel,
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
        let size: CGFloat = 40 // Close to cell height
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        // Priority: iconUrl > iconName
        let iconUrl = collection.iconUrl
        let iconName = collection.iconName
        
        // Check if we have a loaded custom image
        if let url = iconUrl, let loadedImage = loadedIconImages[collection.id] {
            return createIconImageWithBackground(remoteImage: loadedImage, size: size)
        }
        
        // Check if icon is set - either iconUrl exists (even if not loaded) or iconName exists
        let hasIcon = (iconUrl != nil && !iconUrl!.isEmpty) || (iconName != nil && UIImage(systemName: iconName!) != nil)
        
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
            if let iconName = iconName,
               let iconImage = UIImage(systemName: iconName) {
                let iconSize: CGFloat = 22
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
                    let height = iconRect.width / aspect
                    drawRect = CGRect(
                        x: iconRect.origin.x,
                        y: iconRect.origin.y + (iconRect.height - height) / 2,
                        width: iconRect.width,
                        height: height
                    )
                } else {
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
    
    private func createIconImageWithBackground(remoteImage: UIImage, size: CGFloat) -> UIImage? {
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
                let height = imageRect.width / aspect
                drawRect = CGRect(
                    x: imageRect.origin.x,
                    y: imageRect.origin.y + (imageRect.height - height) / 2,
                    width: imageRect.width,
                    height: height
                )
            } else {
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
