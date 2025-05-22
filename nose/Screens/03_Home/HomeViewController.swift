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
    private lazy var dotSlider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        
        // Create the line
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .thirdColor
        view.addSubview(line)
        
        // Create the dots - middle one selected by default
        let dot1 = createDot(isSelected: false)
        let dot2 = createDot(isSelected: true)  // Middle dot selected
        let dot3 = createDot(isSelected: false)
        
        view.addSubview(dot1)
        view.addSubview(dot2)
        view.addSubview(dot3)
        
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
    
    private func createDot(isSelected: Bool) -> UIView {
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = isSelected ? .fifthColor : .thirdColor
        dot.layer.cornerRadius = 6
        return dot
    }
    
    private lazy var profileButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "person.fill"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var sparkButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "sparkle"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(sparkButtonTapped), for: .touchUpInside)
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
        button.tintColor = .fourthColor
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.sixthColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(currentLocationButtonTapped), for: .touchUpInside)
        return button
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
        title = "Home"
        
        // Add subviews
        view.addSubview(mapView)
        view.addSubview(searchButton)
        view.addSubview(sparkButton)
        view.addSubview(searchResultsTableView)
        view.addSubview(currentLocationButton)
        view.addSubview(profileButton)
        view.addSubview(dotSlider)
        
        // Setup constraints
        NSLayoutConstraint.activate([
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
            
            // Map view constraints
            mapView.topAnchor.constraint(equalTo: dotSlider.bottomAnchor, constant: 16),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Search results table view constraints
            searchResultsTableView.topAnchor.constraint(equalTo: searchButton.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchResultsTableView.heightAnchor.constraint(equalToConstant: 200),
            
            // Current location button constraints
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            currentLocationButton.widthAnchor.constraint(equalToConstant: 50),
            currentLocationButton.heightAnchor.constraint(equalToConstant: 50)
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
    
    @objc private func dotSliderTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: dotSlider)
        let width = dotSlider.bounds.width
        let segmentWidth = width / 3
        
        // Determine which segment was tapped
        let segment = Int(location.x / segmentWidth)
        
        // Update dots - skip the first subview (line) and update the next three (dots)
        for (index, subview) in dotSlider.subviews.enumerated() {
            if index > 0 && index <= 3 { // Skip the line view (index 0) and only process dots
                subview.backgroundColor = (index - 1) == segment ? .fifthColor : .thirdColor
            }
        }
        
        // Always show the map view
        mapView.isHidden = false
        
        // Handle different dot selections
        switch segment {
        case 0: // Left dot
            print("Left dot selected")
            searchButton.isHidden = true
            sparkButton.isHidden = true
        case 1: // Middle dot - show search
            print("Middle dot selected")
            searchButton.isHidden = false
            sparkButton.isHidden = true
        case 2: // Right dot - show collections
            print("Right dot selected")
            searchButton.isHidden = true
            sparkButton.isHidden = false
        default:
            break
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
        let detailViewController = PlaceDetailViewController(place: place)
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
