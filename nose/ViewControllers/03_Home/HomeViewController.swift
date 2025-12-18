import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth

final class HomeViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let buttonSize: CGFloat = 55
        static let searchResultsHeight: CGFloat = 200
        static let messageViewPadding: CGFloat = 24
        static let messageViewSpacing: CGFloat = 8
    }
    
    // MARK: - Properties
    private var searchResults: [GMSPlace] = []
    private var searchPredictions: [GMSAutocompletePrediction] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var currentDotIndex: Int = 1  // Track current dot index (0: left, 1: middle, 2: right)
    private var collections: [PlaceCollection] = []
    private var events: [Event] = []
    private let locationManager = CLLocationManager()
    
    // Add properties to track dots and line
    private var leftDot: UIView?
    private var middleDot: UIView?
    private var rightDot: UIView?
    private var dotLine: UIView?
    private var containerView: UIView?
    
    var mapManager: GoogleMapManager?
    private var searchManager: SearchManager?
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var dotSlider: TimelineSliderView = {
        let view = TimelineSliderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private lazy var profileButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "person.fill"),
            action: #selector(profileButtonTapped),
            target: self
        )
    }()
    
    private lazy var createEventButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "calendar"),
            action: #selector(createEventButtonTapped),
            target: self
        )
    }()
    
    private lazy var searchButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "magnifyingglass"),
            action: #selector(searchButtonTapped),
            target: self
        )
    }()
    
    private lazy var sparkButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "sparkle"),
            action: #selector(sparkButtonTapped),
            target: self
        )
    }()
    
    private lazy var boxButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "archivebox.fill"),
            action: #selector(boxButtonTapped),
            target: self
        )
    }()
    
    private lazy var mapView: GMSMapView = {
        // Don't set default camera here - we'll set it based on location permission
        // Create map options with Map ID
        let mapOptions = GMSMapViewOptions()
        mapOptions.frame = .zero
        mapOptions.mapID = GMSMapID(identifier: "7f9a1d61a6b1809f")
        
        let mapView = GMSMapView(options: mapOptions)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.settings.myLocationButton = false  // Disable default location button
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.delegate = self
        return mapView
    }()
    
    private var hasSetInitialCamera = false
    
    private lazy var searchResultsTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.isHidden = true
        tableView.layer.cornerRadius = 8
        tableView.layer.masksToBounds = true
        return tableView
    }()
    
    private lazy var currentLocationButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "location.fill"),
            action: #selector(currentLocationButtonTapped),
            target: self,
            size: Constants.buttonSize
        )
    }()
    
    private lazy var messageView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        view.layer.cornerRadius = 12
        view.alpha = 0
        // Add shadow
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .black.withAlphaComponent(0.7)
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = true
        setupUI()
        setupManagers()
        setupLocationManager()
        setupNotificationObservers()
        loadEvents()
        
        // Check location permission and set initial camera accordingly
        // This happens after UI setup so mapView is already created
        checkLocationPermissionForInitialCamera()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkLocationPermissionForInitialCamera() {
        // Check permission status and set camera accordingly
        switch locationManager.authorizationStatus {
        case .restricted, .denied:
            // Location not allowed - show default location immediately
            setDefaultLocationCamera()
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - location manager will handle camera when location arrives
            // Don't set default camera - wait for location update
            break
        case .notDetermined:
            // Permission not determined yet - don't set camera, wait for permission response
            // Default camera will be set if permission is denied, or we'll wait for location if granted
            break
        @unknown default:
            // Fallback to default location
            setDefaultLocationCamera()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh events when view appears
        loadEvents()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        setupSubviews()
        setupConstraints()
        
        // Set initial button visibility based on default selected dot (middle dot, index 1)
        searchButton.isHidden = false
        searchButton.alpha = 1
        sparkButton.isHidden = true
        sparkButton.alpha = 0
        boxButton.isHidden = true
        boxButton.alpha = 0
    }
    
    private func setupSubviews() {
        [mapView, headerView, dotSlider, searchButton, sparkButton, boxButton,
         searchResultsTableView, currentLocationButton, profileButton, createEventButton, messageView].forEach {
            view.addSubview($0)
        }
        
        [titleLabel, subtitleLabel].forEach {
            messageView.addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Map view constraints
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header view constraints
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: dotSlider.bottomAnchor, constant: 16),
            
            // Dot slider constraints
            dotSlider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            dotSlider.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            dotSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dotSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Profile button constraints
            profileButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            profileButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            profileButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            profileButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Create event button constraints
            createEventButton.topAnchor.constraint(equalTo: profileButton.bottomAnchor, constant: 12),
            createEventButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            createEventButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            createEventButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Search button constraints
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            searchButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            searchButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Box button constraints
            boxButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            boxButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            boxButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            boxButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Spark button constraints
            sparkButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            sparkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            sparkButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            sparkButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Search results table view constraints
            searchResultsTableView.topAnchor.constraint(equalTo: searchButton.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            searchResultsTableView.heightAnchor.constraint(equalToConstant: Constants.searchResultsHeight),
            
            // Current location button constraints
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.standardPadding),
            currentLocationButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            currentLocationButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Message view constraints
            messageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -64),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: Constants.messageViewPadding),
            titleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: Constants.messageViewPadding),
            titleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -Constants.messageViewPadding),
            
            // Subtitle label constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Constants.messageViewSpacing),
            subtitleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: Constants.messageViewPadding),
            subtitleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -Constants.messageViewPadding),
            subtitleLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -Constants.messageViewPadding)
        ])
    }
    
    private func setupManagers() {
        sessionToken = GMSAutocompleteSessionToken()
        mapManager = GoogleMapManager(mapView: mapView)
        mapManager?.delegate = self
        searchManager = SearchManager()
        searchManager?.delegate = self
        
        // Load collections
        loadCollections()
    }
    
    private func loadCollections() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        print("🔍 Loading collections for map: \(currentUserId)")
        
        var personalCollections: [PlaceCollection] = []
        var sharedCollections: [PlaceCollection] = []
        let group = DispatchGroup()
        
        // Load owned collections
        group.enter()
        let ownedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
        
        ownedCollectionsRef.whereField("isOwner", isEqualTo: true).getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("❌ Error loading owned collections: \(error.localizedDescription)")
                return
            }
            
            print("📄 Found \(snapshot?.documents.count ?? 0) owned collections")
            
            let collections: [PlaceCollection] = snapshot?.documents.compactMap { document in
                var data = document.data()
                data["id"] = document.documentID
                data["isOwner"] = true
                
                // If status is missing, treat it as active
                if data["status"] == nil {
                    data["status"] = PlaceCollection.Status.active.rawValue
                }
                
                if let collection = PlaceCollection(dictionary: data) {
                    return collection
                }
                return nil
            } ?? []
            
            // Filter to only show active collections
            personalCollections = collections.filter { $0.status == .active }
            print("🎯 Active owned collections: \(personalCollections.count)")
        }
        
        // Load shared collections
        group.enter()
        let sharedCollectionsRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
        
        let sharedGroup = DispatchGroup()
        var sharedLoadedCollections: [PlaceCollection] = []
        
        sharedCollectionsRef.whereField("isOwner", isEqualTo: false).getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("❌ Error loading shared collections: \(error.localizedDescription)")
                return
            }
            
            print("📄 Found \(snapshot?.documents.count ?? 0) shared collections")
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("🎯 Active shared collections: 0")
                // No documents means sharedGroup has no enters, so notify immediately
                sharedGroup.notify(queue: .main) {
                    sharedCollections = []
                }
                return
            }
            
            documents.forEach { document in
                sharedGroup.enter()
                let data = document.data()
                
                // Get the original collection data from the owner's collections
                if let ownerId = data["userId"] as? String,
                   let collectionId = data["id"] as? String {
                    
                    db.collection("users")
                        .document(ownerId)
                        .collection("collections")
                        .document(collectionId)
                        .getDocument { snapshot, error in
                            defer { sharedGroup.leave() }
                            
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
                                
                                if let collection = PlaceCollection(dictionary: collectionData) {
                                    sharedLoadedCollections.append(collection)
                                }
                            }
                        }
                } else {
                    sharedGroup.leave()
                }
            }
        }
        
        // When both personal and shared collections queries complete, wait for shared collections details to load
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Wait for shared collections to finish loading, then update map
            sharedGroup.notify(queue: .main) {
                // Update sharedCollections with loaded data
                sharedCollections = sharedLoadedCollections.filter { $0.status == .active }
                print("🎯 Active shared collections: \(sharedCollections.count)")
                
                // Combine all collections
                self.collections = personalCollections + sharedCollections
                print("✅ Loaded \(self.collections.count) total active collections for map")
                
                // Show all collection places on the map
                self.mapManager?.showCollectionPlacesOnMap(self.collections)
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        // Use reduced accuracy for faster initial location fix
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 10 // Only update if moved 10 meters
        checkLocationPermission()
    }
    
    private func setupNotificationObservers() {
        // Removed appWillEnterForeground observer to prevent repeated permission checks
        // Location permissions are now only checked when actually needed
        
        // Listen for PlaceDetailViewController dismissal to clear search marker
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(placeDetailViewControllerWillDismiss),
            name: NSNotification.Name("PlaceDetailViewControllerWillDismiss"),
            object: nil
        )
    }
    
    @objc private func placeDetailViewControllerWillDismiss() {
        mapManager?.clearSearchPlaceMarker()
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Only request permission if we haven't asked before
            locationManager.requestWhenInUseAuthorization()
            // Don't set camera yet - wait for permission response
        case .restricted, .denied:
            // Location not allowed - show default location if not already set
            print("Location access denied or restricted - showing default location")
            if !hasSetInitialCamera {
                setDefaultLocationCamera()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - wait for current location before setting camera
            print("Location permission granted - waiting for current location")
            locationManager.startUpdatingLocation()
            // Don't set default camera - wait for location update
        @unknown default:
            // Fallback to default location
            if !hasSetInitialCamera {
                setDefaultLocationCamera()
            }
            break
        }
    }
    
    private func setDefaultLocationCamera() {
        guard !hasSetInitialCamera else { return }
        hasSetInitialCamera = true
        
        let camera = GMSCameraPosition.camera(
            withLatitude: 35.6812,  // Tokyo coordinates as default
            longitude: 139.7671,
            zoom: 15
        )
        mapView.camera = camera
    }
    
    @objc private func currentLocationButtonTapped() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            mapManager?.moveToCurrentLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Show a gentle message that location is not available
            showMessage(title: "Location Unavailable", subtitle: "Enable location in Settings to use this feature")
        @unknown default:
            break
        }
    }
    
    @objc private func profileButtonTapped() {
        let settingVC = SettingsViewController()
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    @objc private func createEventButtonTapped() {
        let manageEventVC = ManageEventViewController()
        let navController = UINavigationController(rootViewController: manageEventVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        let searchVC = SearchViewController()
        searchVC.delegate = self
        searchVC.modalPresentationStyle = .fullScreen
        present(searchVC, animated: true)
    }
    
    @objc private func sparkButtonTapped() {
        let collectionsVC = CollectionsViewController()
        collectionsVC.mapManager = mapManager
        present(collectionsVC, animated: true)
    }
    
    @objc private func boxButtonTapped() {
        let boxVC = BoxViewController()
        present(boxVC, animated: true)
    }
    
    private func showMessage(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        // Fade in
        UIView.animate(withDuration: 0.3, animations: {
            self.messageView.alpha = 1
        }) { _ in
            // Fade out after delay
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                self.messageView.alpha = 0
            })
        }
    }
    
    // MARK: - Helper Methods
    private func searchPlaces(query: String) {
        // Use debounced search to prevent rapid-fire API calls
        PlacesAPIManager.shared.debouncedSearch(query: query) { [weak self] (predictions: [GMSAutocompletePrediction]) in
            DispatchQueue.main.async {
                self?.searchPredictions = predictions
                self?.searchResultsTableView.reloadData()
            }
        }
    }
    
    private func loadEvents() {
        print("📍 Loading current and future events for map...")
        EventManager.shared.fetchAllCurrentAndFutureEvents { [weak self] result in
            switch result {
            case .success(let events):
                print("✅ Loaded \(events.count) events")
                self?.events = events
                DispatchQueue.main.async {
                    self?.mapManager?.showEventsOnMap(events)
                }
            case .failure(let error):
                print("❌ Failed to load events: \(error.localizedDescription)")
            }
        }
    }
    
}

// MARK: - UISearchBarDelegate
extension HomeViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchPredictions = []
            searchResultsTableView.isHidden = true
            return
        }
        
        searchResultsTableView.isHidden = false
        searchPlaces(query: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchPredictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let prediction = searchPredictions[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = prediction.attributedPrimaryText.string
        content.secondaryText = prediction.attributedSecondaryText?.string
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let prediction = searchPredictions[indexPath.row]
        // Fetch place details when user selects a prediction
        mapManager?.fetchPlaceDetails(for: prediction) { [weak self] place in
            if let place = place {
                DispatchQueue.main.async {
                    self?.mapManager?.showPlaceOnMap(place)
                    let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
                    self?.present(detailViewController, animated: true)
                }
            }
        }
    }
}

// MARK: - GMSMapViewDelegate
extension HomeViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        // Hide search results when tapping on the map
        searchResultsTableView.isHidden = true
    }
    
    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        print("Map style successfully loaded")
    }
}

// MARK: - SearchViewControllerDelegate
extension HomeViewController: SearchViewControllerDelegate {
    func searchViewController(_ controller: SearchViewController, didSelectPlace place: GMSPlace) {
        mapManager?.showPlaceOnMap(place)
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        // Dismiss the search UI first, then present the detail over current context so the map stays visible
        controller.dismiss(animated: true) {
            detailViewController.modalPresentationStyle = .overCurrentContext
            self.present(detailViewController, animated: true)
        }
    }
}

// MARK: - TimelineSliderViewDelegate
extension HomeViewController: TimelineSliderViewDelegate {
    func timelineSliderView(_ view: TimelineSliderView, didSelectDotAt index: Int) {
        // Check if a modal is minimized and should be dismissed
        if let presentedVC = presentedViewController {
            // Check if it's a sheet presentation controller
            if let sheet = presentedVC.sheetPresentationController {
                // Check if modal is minimized (at small detent, not large)
                let smallDetentIdentifier = UISheetPresentationController.Detent.Identifier("small")
                let isMinimized = sheet.selectedDetentIdentifier == smallDetentIdentifier
                
                if isMinimized {
                    // Check which dot corresponds to which modal
                    let isCollectionsModal = presentedVC is CollectionsViewController && index != 2
                    let isBoxModal = presentedVC is BoxViewController && index != 0
                    
                    // If the new dot selection doesn't match the current modal, dismiss it
                    if isCollectionsModal || isBoxModal {
                        presentedVC.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
        
        currentDotIndex = index
        
        // Always show the map view
        mapView.isHidden = false
        
        // Show message based on selected dot
        switch index {
        case 0:
            showMessage(title: "Past", subtitle: "relive the moments")
        case 1:
            showMessage(title: "Current", subtitle: "explore what's happening")
        case 2:
            showMessage(title: "Future", subtitle: "plan and get ready")
        default:
            break
        }
        
        // First hide all buttons
        searchButton.isHidden = true
        sparkButton.isHidden = true
        boxButton.isHidden = true
        
        // Then show and animate the appropriate button
        UIView.animate(withDuration: 0.3, animations: {
            switch index {
            case 0: // Left dot - show box
                self.boxButton.alpha = 1
                self.boxButton.isHidden = false
                self.searchButton.alpha = 0
                self.sparkButton.alpha = 0
            case 1: // Middle dot - show search
                self.searchButton.alpha = 1
                self.searchButton.isHidden = false
                self.sparkButton.alpha = 0
                self.boxButton.alpha = 0
            case 2: // Right dot - show collections
                self.sparkButton.alpha = 1
                self.sparkButton.isHidden = false
                self.searchButton.alpha = 0
                self.boxButton.alpha = 0
            default:
                break
            }
        })
    }
}

// MARK: - SearchManagerDelegate
extension HomeViewController: SearchManagerDelegate {
    func searchManager(_ manager: SearchManager, didUpdateResults results: [GMSAutocompletePrediction]) {
        searchPredictions = results
        searchResultsTableView.reloadData()
    }
    
    func searchManager(_ manager: SearchManager, didSelectPlace place: GMSPlace) {
        mapManager?.showPlaceOnMap(place)
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        detailViewController.modalPresentationStyle = .overCurrentContext
        // If a SearchViewController is currently presented, dismiss it before presenting details
        if let presented = self.presentedViewController as? SearchViewController {
            presented.dismiss(animated: true) {
                self.present(detailViewController, animated: true)
            }
        } else {
            self.present(detailViewController, animated: true)
        }
    }
}

// MARK: - CreateEventViewControllerDelegate
extension HomeViewController: CreateEventViewControllerDelegate {
    func createEventViewController(_ controller: CreateEventViewController, didCreateEvent event: Event) {
        // Handle the created event
        print("Event created: \(event.title)")
        // Reload events to show the new one on the map
        loadEvents()
    }
}

// MARK: - GoogleMapManagerDelegate
extension HomeViewController: GoogleMapManagerDelegate {
    func googleMapManager(_ manager: GoogleMapManager, didFailWithError error: Error) {
        // Only log errors that are not common/expected (like permission denied, network issues)
        let nsError = error as NSError
        if nsError.domain == "kCLErrorDomain" || (error as? CLError) != nil {
            // CoreLocation errors - only log if not a common permission/network error
            if let cleError = error as? CLError {
                switch cleError.code {
                case .locationUnknown:
                    // Common when location services are disabled or unavailable
                    // Don't show error to user - map can still function
                    print("⚠️ Location unavailable: \(error.localizedDescription)")
                case .denied, .network:
                    // Permission denied or network error - user can still use map
                    print("⚠️ Location access: \(error.localizedDescription)")
                default:
                    print("❌ Map error: \(error.localizedDescription)")
                }
            } else {
                // Check numeric codes as fallback
                switch nsError.code {
                case 0: // kCLErrorLocationUnknown
                    print("⚠️ Location unavailable: \(error.localizedDescription)")
                case 1: // kCLErrorDenied
                    print("⚠️ Location access denied: \(error.localizedDescription)")
                case 2: // kCLErrorNetwork
                    print("⚠️ Location network error: \(error.localizedDescription)")
                default:
                    print("❌ Map error: \(error.localizedDescription)")
                }
            }
        } else {
            print("❌ Map error: \(error.localizedDescription)")
        }
    }
    
    func googleMapManager(_ manager: GoogleMapManager, didTapEventMarker event: Event) {
        print("🎯 Showing event detail: \(event.title)")
        let eventDetailVC = EventDetailViewController(event: event)
        eventDetailVC.modalPresentationStyle = .overCurrentContext
        eventDetailVC.modalTransitionStyle = .crossDissolve
        present(eventDetailVC, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate
extension HomeViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only move to current location if we haven't set initial camera yet
        // This prevents the jarring movement from default to current location
        if !hasSetInitialCamera {
            hasSetInitialCamera = true
            mapManager?.moveToCurrentLocation()
        }
        
        locationManager.stopUpdatingLocation() // Stop updating after getting the first location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        // If we haven't set initial camera yet and location fails, show default location
        if !hasSetInitialCamera {
            print("Location failed - falling back to default location")
            setDefaultLocationCamera()
        }
    }
}
