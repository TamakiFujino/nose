import UIKit
import MapboxMaps
import CoreLocation
import GooglePlaces
import FirebaseAuth

final class HomeViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let buttonSize: CGFloat = 55
        static let searchResultsHeight: CGFloat = 200
        static let messageViewPadding: CGFloat = 24
        static let messageViewSpacing: CGFloat = 8
        static let footerBarHeight: CGFloat = 80
    }
    
    // MARK: - Properties
    private var searchResults: [GMSPlace] = []
    private var searchPredictions: [GMSAutocompletePrediction] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var collections: [PlaceCollection] = []
    private var events: [Event] = []
    private let locationManager = CLLocationManager()
    
    var mapManager: MapboxMapManager?
    private var searchManager: SearchManager?
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    // Larger icon configuration for footer buttons (1.2x)
    private let footerIconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    
    private lazy var profileButton: IconButton = {
        let button = IconButton(
            image: UIImage(systemName: "person.fill", withConfiguration: footerIconConfig),
            action: #selector(profileButtonTapped),
            target: self,
            backgroundColor: .clear
        )
        button.accessibilityIdentifier = "personal_library"
        button.accessibilityLabel = "Personal Library"
        return button
    }()
    
    private lazy var createEventButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "calendar", withConfiguration: footerIconConfig),
            action: #selector(createEventButtonTapped),
            target: self,
            backgroundColor: .clear,
            tintColor: .systemGray
        )
    }()
    
    private lazy var newButton: IconButton = {
        let button = IconButton(
            image: UIImage(systemName: "bookmark", withConfiguration: footerIconConfig),
            action: #selector(newButtonTapped),
            target: self,
            backgroundColor: .clear
        )
        button.accessibilityIdentifier = "sparkle"
        button.accessibilityLabel = "Collections"
        return button
    }()
    
    private lazy var searchButton: IconButton = {
        let button = IconButton(
            image: UIImage(systemName: "magnifyingglass", withConfiguration: footerIconConfig),
            action: #selector(searchButtonTapped),
            target: self,
            backgroundColor: .clear
        )
        button.accessibilityIdentifier = "search_button"
        button.accessibilityLabel = "Search"
        return button
    }()
    
    private lazy var mapView: MapView = {
        // Create map view with default style
        // Mapbox access token is set in AppDelegate as environment variable
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions())
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        // Zoom gestures are enabled by default in Mapbox
        return mapView
    }()
    
    // Blur overlays for focus lens effect
    private lazy var topBlurOverlay: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        return blurView
    }()
    
    private lazy var bottomBlurOverlay: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        return blurView
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
    
    private lazy var toggle3DButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "cube.fill"),
            action: #selector(toggle3DButtonTapped),
            target: self,
            size: Constants.buttonSize
        )
    }()
    
    private var is3DViewEnabled = false
    
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
    
    private lazy var footerBar: UIView = {
        // Semi-transparent view matching button style
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        
        // Shadow
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: -2)
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOpacity = 0.1
        
        // Corner radius - top corners only
        containerView.layer.cornerRadius = 20
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.layer.masksToBounds = true
        
        return containerView
    }()
    
    private lazy var footerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        return stackView
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
        // Hide navigation bar on this screen
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // Refresh events when view appears
        loadEvents()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show navigation bar for other screens (so they have the back button)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Apply gradient masks to blur overlays for focus lens effect
        applyBlurGradientMasks()
    }
    
    private func applyBlurGradientMasks() {
        // Top blur: opaque at top, transparent toward bottom
        let topGradient = CAGradientLayer()
        topGradient.frame = topBlurOverlay.bounds
        topGradient.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        topGradient.locations = [0.0, 1.0]
        topGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        topGradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        topBlurOverlay.layer.mask = topGradient
        
        // Bottom blur: opaque at bottom, transparent toward top
        let bottomGradient = CAGradientLayer()
        bottomGradient.frame = bottomBlurOverlay.bounds
        bottomGradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        bottomGradient.locations = [0.0, 1.0]
        bottomGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        bottomGradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomBlurOverlay.layer.mask = bottomGradient
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        setupSubviews()
        setupConstraints()
    }
    
    private func setupSubviews() {
        // Add main views to the view hierarchy
        // Blur overlays are added right after mapView so they're on top of map but below other UI
        [mapView, topBlurOverlay, bottomBlurOverlay, footerBar, headerView,
         searchResultsTableView, currentLocationButton, toggle3DButton, messageView].forEach {
            view.addSubview($0)
        }
        
        // Add footer stack view to footer bar
        footerBar.addSubview(footerStackView)
        
        // Add buttons to footer stack view (left to right: profile, event, sparkle, search)
        [profileButton, createEventButton, newButton, searchButton].forEach {
            footerStackView.addArrangedSubview($0)
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
            
            // Top blur overlay constraints (focus lens effect)
            topBlurOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            topBlurOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBlurOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBlurOverlay.heightAnchor.constraint(equalToConstant: 250),
            
            // Bottom blur overlay constraints (focus lens effect) - extends under footer
            bottomBlurOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBlurOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurOverlay.heightAnchor.constraint(equalToConstant: 250),
            
            // Header view constraints
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            
            // Search results table view constraints
            searchResultsTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            searchResultsTableView.heightAnchor.constraint(equalToConstant: Constants.searchResultsHeight),
            
            // Footer bar constraints - full width, extends to bottom edge
            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.footerBarHeight),
            
            // Footer stack view constraints - inside footer bar with padding
            footerStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 32),
            footerStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -32),
            footerStackView.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 12),
            footerStackView.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Current location button constraints - positioned above footer bar (right side)
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            currentLocationButton.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -Constants.standardPadding),
            currentLocationButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            currentLocationButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // 3D view toggle button constraints - positioned above footer bar (left side)
            toggle3DButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            toggle3DButton.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -Constants.standardPadding),
            toggle3DButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            toggle3DButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
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
        mapManager = MapboxMapManager(mapView: mapView)
        mapManager?.delegate = self
        searchManager = SearchManager()
        searchManager?.delegate = self
        
        // Load collections
        loadCollections()
    }
    
    private func loadCollections() {
        CollectionLoadingService.shared.loadCollections(status: .active) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let loadResult):
                // Combine all collections
                self.collections = loadResult.owned + loadResult.shared
                
                // Show all collection places on the map
                self.mapManager?.showCollectionPlacesOnMap(self.collections)
                
            case .failure(let error):
                Logger.log("Error loading collections: \(error.localizedDescription)", level: .error, category: "Home")
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
        
        // Listen for collection updates to refresh map
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCollections),
            name: NSNotification.Name("RefreshCollections"),
            object: nil
        )
    }
    
    @objc private func placeDetailViewControllerWillDismiss() {
        mapManager?.clearSearchPlaceMarker()
    }
    
    @objc private func refreshCollections() {
        loadCollections()
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Only request permission if we haven't asked before
            locationManager.requestWhenInUseAuthorization()
            // Don't set camera yet - wait for permission response
        case .restricted, .denied:
            // Location not allowed - show default location if not already set
            if !hasSetInitialCamera {
                setDefaultLocationCamera()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - wait for current location before setting camera
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
        
        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),  // Tokyo coordinates as default
            zoom: 15
        )
        mapView.camera.ease(to: cameraOptions, duration: 0.0)
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
    
    @objc private func toggle3DButtonTapped() {
        is3DViewEnabled.toggle()
        
        // Get current camera state
        let currentCenter = mapView.mapboxMap.cameraState.center
        let currentZoom = mapView.mapboxMap.cameraState.zoom
        
        // Set pitch: 0 for 2D, 50 for 3D view
        let targetPitch: CGFloat = is3DViewEnabled ? 50 : 0
        
        let cameraOptions = CameraOptions(
            center: currentCenter,
            zoom: currentZoom,
            pitch: targetPitch
        )
        
        // Animate the camera transition
        mapView.camera.ease(to: cameraOptions, duration: 0.5)
        
        // Update button appearance to show current state
        let iconName = is3DViewEnabled ? "cube.fill" : "cube"
        toggle3DButton.setImage(UIImage(systemName: iconName), for: .normal)
    }
    
    @objc private func profileButtonTapped() {
        // Dismiss any open modal first
        if let presentedVC = presentedViewController {
            presentedVC.dismiss(animated: true) { [weak self] in
                let settingVC = SettingsViewController()
                self?.navigationController?.pushViewController(settingVC, animated: true)
            }
        } else {
        let settingVC = SettingsViewController()
        navigationController?.pushViewController(settingVC, animated: true)
        }
    }
    
    @objc private func createEventButtonTapped() {
        let messageModal = MessageModalViewController(
            title: "Coming Soon",
            message: "This feature is coming soon!"
        )
        present(messageModal, animated: true)
    }
    
    @objc private func newButtonTapped() {
        let collectionsVC = CollectionsViewController()
        collectionsVC.mapManager = mapManager
        present(collectionsVC, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        let searchVC = SearchViewController()
        searchVC.delegate = self
        searchVC.modalPresentationStyle = .fullScreen
        present(searchVC, animated: true)
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
        EventManager.shared.fetchAllCurrentAndFutureEvents { [weak self] result in
            switch result {
            case .success(let events):
                self?.events = events
                DispatchQueue.main.async {
                    self?.mapManager?.showEventsOnMap(events)
                }
            case .failure(let error):
                Logger.log("Failed to load events: \(error.localizedDescription)", level: .error, category: "Home")
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

// MARK: - Mapbox Map Handling
extension HomeViewController {
    // Handle map taps to hide search results
    // This can be set up via gesture recognizers if needed
    func setupMapTapHandling() {
        // Mapbox handles taps through annotation managers
        // Search results hiding can be handled elsewhere if needed
    }
}

// MARK: - SearchViewControllerDelegate
extension HomeViewController: SearchViewControllerDelegate {
    func searchViewController(_ controller: SearchViewController, didSelectPlace place: GMSPlace) {
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        // modalPresentationStyle is already set to .pageSheet in PlaceDetailViewController init
        
        // Dismiss the search UI first, THEN move camera and present detail
        // (Camera animation only works when map is visible)
        controller.dismiss(animated: true) {
            self.mapManager?.showPlaceOnMap(place)
            self.present(detailViewController, animated: true)
        }
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
        // modalPresentationStyle is already set to .pageSheet in PlaceDetailViewController init
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
        // Reload events to show the new one on the map
        loadEvents()
    }
}

// MARK: - MapboxMapManagerDelegate
extension HomeViewController: MapboxMapManagerDelegate {
    func mapboxMapManager(_ manager: MapboxMapManager, didFailWithError error: Error) {
        // Only log unexpected errors - common location errors are handled silently
        let nsError = error as NSError
        if nsError.domain == "kCLErrorDomain" || (error as? CLError) != nil {
            // CoreLocation errors - silently handle common permission/network errors
            if let cleError = error as? CLError {
                switch cleError.code {
                case .locationUnknown, .denied, .network:
                    // Common errors - map can still function
                    break
                default:
                    Logger.log("Map error: \(error.localizedDescription)", level: .error, category: "Home")
                }
            } else {
                // Check numeric codes as fallback
                switch nsError.code {
                case 0, 1, 2: // Common location errors
                    break
                default:
                    Logger.log("Map error: \(error.localizedDescription)", level: .error, category: "Home")
                }
            }
        } else {
            Logger.log("Map error: \(error.localizedDescription)", level: .error, category: "Home")
        }
    }
    
    func mapboxMapManager(_ manager: MapboxMapManager, didTapEventMarker event: Event) {
        let eventDetailVC = EventDetailViewController(event: event)
        eventDetailVC.modalPresentationStyle = .overCurrentContext
        eventDetailVC.modalTransitionStyle = .crossDissolve
        present(eventDetailVC, animated: true)
    }
    
    func mapboxMapManager(_ manager: MapboxMapManager, didTapCollectionPlace place: GMSPlace) {
        let detailVC = PlaceDetailViewController(place: place, isFromCollection: true)
        present(detailVC, animated: true)
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
        Logger.log("Location manager failed: \(error.localizedDescription)", level: .warn, category: "Home")
        
        // If we haven't set initial camera yet and location fails, show default location
        if !hasSetInitialCamera {
            setDefaultLocationCamera()
        }
    }
}
