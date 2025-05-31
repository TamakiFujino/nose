import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces

final class HomeViewController: UIViewController {
    
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var searchResults: [GMSPlace] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = GradientHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var dotSlider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        
        // Create the line
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .sixthColor
        view.addSubview(line)
        
        // Create the dots - middle one selected by default
        let dot1 = createDot(isSelected: false)
        let dot2 = createDot(isSelected: true)  // Middle dot selected
        let dot3 = createDot(isSelected: false)
        
        view.addSubview(dot1)
        view.addSubview(dot2)
        view.addSubview(dot3)
        
        // Store references to dots
        self.leftDot = dot1
        self.middleDot = dot2
        self.rightDot = dot3
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Line constraints
            line.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            line.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 2),
            
            // Dot constraints
            dot1.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            dot1.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dot1.widthAnchor.constraint(equalToConstant: 12),
            dot1.heightAnchor.constraint(equalToConstant: 12),
            
            dot2.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            dot2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dot2.widthAnchor.constraint(equalToConstant: 12),
            dot2.heightAnchor.constraint(equalToConstant: 12),
            
            dot3.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            dot3.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dot3.widthAnchor.constraint(equalToConstant: 12),
            dot3.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dotSliderTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }()
    
    // Add properties to track dots
    private var leftDot: UIView?
    private var middleDot: UIView?
    private var rightDot: UIView?
    
    private func createDot(isSelected: Bool) -> UIView {
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = isSelected ? .firstColor : .sixthColor
        dot.layer.cornerRadius = 6
        return dot
    }
    
    private lazy var profileButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "person.fill"), for: .normal)
        button.tintColor = .sixthColor
        button.backgroundColor = .clear
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        button.tintColor = .sixthColor
        button.backgroundColor = .clear
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var sparkButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "sparkle"), for: .normal)
        button.tintColor = .sixthColor
        button.backgroundColor = .clear
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(sparkButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private lazy var boxButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "archivebox.fill"), for: .normal)
        button.tintColor = .sixthColor
        button.backgroundColor = .clear
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(boxButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private lazy var mapView: GMSMapView = {
        let camera = GMSCameraPosition.camera(
            withLatitude: 35.6812,  // Tokyo coordinates as default
            longitude: 139.7671,
            zoom: 15
        )
        
        // Create map options with Map ID
        let mapOptions = GMSMapViewOptions()
        mapOptions.camera = camera
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
    
    private lazy var currentLocationButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "location.fill"), for: .normal)
        button.backgroundColor = .white
        button.tintColor = .sixthColor
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.sixthColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(currentLocationButtonTapped), for: .touchUpInside)
        return button
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
        setupUI()
        setupLocationManager()
        sessionToken = GMSAutocompleteSessionToken()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        // Remove title
        navigationItem.title = nil
        navigationController?.navigationBar.isHidden = true
        
        // Add subviews in correct order
        view.addSubview(mapView)
        view.addSubview(headerView)
        view.addSubview(searchButton)
        view.addSubview(sparkButton)
        view.addSubview(boxButton)
        view.addSubview(searchResultsTableView)
        view.addSubview(currentLocationButton)
        view.addSubview(profileButton)
        view.addSubview(dotSlider)
        view.addSubview(messageView)
        messageView.addSubview(titleLabel)
        messageView.addSubview(subtitleLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Map view constraints - now extends to top of screen
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header view constraints - now overlaps with map
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: dotSlider.bottomAnchor, constant: 16),
            
            // Profile button constraints
            profileButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            profileButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            profileButton.widthAnchor.constraint(equalToConstant: 40),
            profileButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Search button constraints
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchButton.widthAnchor.constraint(equalToConstant: 40),
            searchButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Box button constraints (same position as search button)
            boxButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            boxButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            boxButton.widthAnchor.constraint(equalToConstant: 40),
            boxButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Spark button constraints (same position as search button)
            sparkButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            sparkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sparkButton.widthAnchor.constraint(equalToConstant: 40),
            sparkButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Dot slider constraints
            dotSlider.topAnchor.constraint(equalTo: profileButton.bottomAnchor, constant: 8),
            dotSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            dotSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            dotSlider.heightAnchor.constraint(equalToConstant: 20),
            
            // Search results table view constraints
            searchResultsTableView.topAnchor.constraint(equalTo: searchButton.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchResultsTableView.heightAnchor.constraint(equalToConstant: 200),
            
            // Current location button constraints
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            currentLocationButton.widthAnchor.constraint(equalToConstant: 50),
            currentLocationButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Message view constraints
            messageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -64),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -24),
            
            // Subtitle label constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -24),
            subtitleLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Actions
    @objc private func currentLocationButtonTapped() {
        guard let location = currentLocation else {
            // Request location update if not available
            locationManager.requestLocation()
            return
        }
        
        // Animate to current location
        let camera = GMSCameraPosition.camera(
            withLatitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            zoom: 15
        )
        mapView.animate(to: camera)
    }
    
    @objc private func profileButtonTapped() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        let searchViewController = SearchViewController()
        searchViewController.delegate = self
        searchViewController.modalPresentationStyle = .fullScreen
        present(searchViewController, animated: true)
    }
    
    @objc private func sparkButtonTapped() {
        let collectionsVC = CollectionsViewController()
        if let sheet = collectionsVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(collectionsVC, animated: true)
    }
    
    @objc private func boxButtonTapped() {
        let boxVC = BoxViewController()
        if let sheet = boxVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
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
    
    @objc private func dotSliderTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: dotSlider)
        let width = dotSlider.bounds.width
        let segmentWidth = width / 3
        
        // Determine which segment was tapped
        let segment = Int(location.x / segmentWidth)
        
        // Update dots using stored references
        leftDot?.backgroundColor = segment == 0 ? .firstColor : .sixthColor
        middleDot?.backgroundColor = segment == 1 ? .firstColor : .sixthColor
        rightDot?.backgroundColor = segment == 2 ? .firstColor : .sixthColor
        
        // Always show the map view
        mapView.isHidden = false
        
        // Update gradient colors
        (headerView as? GradientHeaderView)?.updateGradient(for: segment)
        
        // Show message based on selected dot
        switch segment {
        case 0:
            showMessage(title: "Past", subtitle: "relive the moments")
        case 1:
            showMessage(title: "Current", subtitle: "explore what's happening")
        case 2:
            showMessage(title: "Future", subtitle: "plan and get ready")
        default:
            break
        }
        
        // Handle different dot selections with fade animation
        UIView.animate(withDuration: 0.3, animations: {
            switch segment {
            case 0: // Left dot - show box
                self.searchButton.alpha = 0
                self.sparkButton.alpha = 0
                self.boxButton.alpha = 1
            case 1: // Middle dot - show search
                self.searchButton.alpha = 1
                self.sparkButton.alpha = 0
                self.boxButton.alpha = 0
            case 2: // Right dot - show collections
                self.searchButton.alpha = 0
                self.sparkButton.alpha = 1
                self.boxButton.alpha = 0
            default:
                break
            }
        }) { _ in
            // Update visibility after fade
            self.searchButton.isHidden = segment != 1
            self.sparkButton.isHidden = segment != 2
            self.boxButton.isHidden = segment != 0
        }
    }
    
    // MARK: - Helper Methods
    private func searchPlaces(query: String) {
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]
        
        // Clear previous results
        searchResults = []
        searchResultsTableView.reloadData()
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: sessionToken
        ) { [weak self] results, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error searching places: \(error.localizedDescription)")
                return
            }
            
            guard let results = results else { return }
            
            // Get place details for each prediction
            for prediction in results {
                let placeID = prediction.placeID
                let fields: GMSPlaceField = [
                    .name,
                    .coordinate,
                    .formattedAddress,
                    .phoneNumber,
                    .rating,
                    .openingHours,
                    .photos,
                    .placeID,
                    .website,
                    .priceLevel,
                    .userRatingsTotal,
                    .types
                ]
                
                placesClient.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: self.sessionToken) { place, error in
                    if let error = error {
                        print("Error fetching place details: \(error.localizedDescription)")
                        return
                    }
                    
                    if let place = place {
                        print("Successfully fetched place: \(place.name ?? "Unknown")")
                        print("Place ID: \(place.placeID ?? "nil")")
                        print("Has photos: \(place.photos?.count ?? 0)")
                        print("Has rating: \(place.rating)")
                        print("Has phone: \(place.phoneNumber != nil)")
                        print("Has opening hours: \(place.openingHours != nil)")
                        
                        DispatchQueue.main.async {
                            self.searchResults.append(place)
                            self.searchResultsTableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    private func showPlaceOnMap(_ place: GMSPlace) {
        print("Showing place on map: \(place.name ?? "Unknown")")
        print("Place ID: \(place.placeID ?? "nil")")
        print("Has photos: \(place.photos?.count ?? 0)")
        print("Has rating: \(place.rating)")
        print("Has phone: \(place.phoneNumber != nil)")
        print("Has opening hours: \(place.openingHours != nil)")
        
        // Clear existing markers
        mapView.clear()
        
        // Create marker for the place
        let marker = GMSMarker(position: place.coordinate)
        marker.title = place.name
        marker.snippet = place.formattedAddress
        marker.map = mapView
        
        // Animate camera to the place
        let camera = GMSCameraPosition.camera(
            withLatitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            zoom: 15
        )
        mapView.animate(to: camera)
        
        // Present place detail view controller
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        print("Presenting detail view controller")
        
        // Add a slight delay to ensure proper presentation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            print("Attempting to present detail view controller")
            self.present(detailViewController, animated: true) {
                print("Detail view controller presentation completed")
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension HomeViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults = []
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
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let place = searchResults[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = place.name
        content.secondaryText = place.formattedAddress
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let place = searchResults[indexPath.row]
        showPlaceOnMap(place)
    }
}

// MARK: - CLLocationManagerDelegate
extension HomeViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            mapView.isMyLocationEnabled = true
        case .denied, .restricted:
            // Show alert to enable location services
            let alert = UIAlertController(
                title: "Location Access Required",
                message: "Please enable location access in Settings to use this feature.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Update camera position to user's location
        let camera = GMSCameraPosition.camera(
            withLatitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            zoom: 15
        )
        mapView.animate(to: camera)
        
        // Stop updating location after first update
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
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
        showPlaceOnMap(place)
    }
}

class GradientHeaderView: UIView {
    private var gradientLayer: CAGradientLayer?
    private var maskLayer: CAGradientLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        setupGradient()
    }
    
    private func setupGradient() {
        // Color gradient
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(hex: "C49ED9")?.cgColor ?? UIColor.yellow.cgColor,     // Gold
            UIColor(hex: "E287B2")?.cgColor ?? UIColor.green.cgColor      // Lime green
        ]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradient.opacity = 0.8  // Make the entire gradient slightly transparent
        layer.insertSublayer(gradient, at: 0)
        self.gradientLayer = gradient
        
        // Vertical fade mask
        let mask = CAGradientLayer()
        mask.colors = [
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        mask.locations = [0.0, 0.0, 1.0]  // Start fade at 70% of height
        mask.startPoint = CGPoint(x: 0.5, y: 0.0)
        mask.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.mask = mask
        self.maskLayer = mask
    }
    
    func updateGradient(for segment: Int) {
        let colors: [CGColor]
        switch segment {
        case 0:
            colors = [
                UIColor(hex: "A7B5FF")?.cgColor ?? UIColor.firstColor.cgColor,
                UIColor(hex: "C49ED9")?.cgColor ?? UIColor.secondColor.cgColor
            ]
        case 1: // Middle dot - Yellow to Green
            colors = [
                UIColor(hex: "C49ED9")?.cgColor ?? UIColor.secondColor.cgColor,     // Gold
                UIColor(hex: "E287B2")?.cgColor ?? UIColor.thirdColor.cgColor      // Lime green
            ]
        case 2: // Right dot - Green to Blue
            colors = [
                UIColor(hex: "E287B2")?.cgColor ?? UIColor.thirdColor.cgColor,     // Lime green
                UIColor(hex: "FF708C")?.cgColor ?? UIColor.fourthColor.cgColor       // Dodger blue
            ]
        default:
            return
        }
        
        // Animate the gradient color change
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer?.colors
        animation.toValue = colors
        animation.duration = 0.3
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        gradientLayer?.colors = colors
        gradientLayer?.add(animation, forKey: "colors")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
        maskLayer?.frame = bounds
    }
} 
