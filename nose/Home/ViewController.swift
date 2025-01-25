import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class ViewController: UIViewController, UISearchBarDelegate, GMSMapViewDelegate, CLLocationManagerDelegate {
    
    var mapView: GMSMapView!
    var locationManager = CLLocationManager()
    var placesClient: GMSPlacesClient!
    var slider: UISlider!
    var hasShownHalfModal = false // Flag to track modal presentation
    var searchButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Google Places Client
        placesClient = GMSPlacesClient.shared()
        
        // Set default camera position (San Francisco)
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12.0)
        mapView = GMSMapView(frame: self.view.bounds, camera: camera)
        mapView.settings.myLocationButton = true  // Show "My Location" button
        mapView.isMyLocationEnabled = true        // Enable blue dot for user location
        mapView.delegate = self                   // Set mapView delegate to self
        view.addSubview(mapView)
        
        // Setup Location Manager
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization() // Request permission
        locationManager.startUpdatingLocation()         // Start location tracking
        
        // Add slider
        slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50 // Default value
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        view.addSubview(slider)
        
        // Add search button
        searchButton = UIButton(type: .system)
        // set background color to white and rounc the corners
        searchButton.backgroundColor = .white
        searchButton.layer.cornerRadius = 20
        // add padding to the button
        searchButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        // add drop shadow to the button
        searchButton.layer.shadowColor = UIColor.black.cgColor
        // set the image to magnifying glass, color to black and size to 40
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.tintColor = .black
        searchButton.imageView?.contentMode = .scaleAspectFit
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Slider constraints
            slider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Search button constraints
            searchButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 10),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchButton.widthAnchor.constraint(equalToConstant: 40),
            searchButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc func searchButtonTapped() {
        let searchVC = SearchViewController()
        searchVC.modalPresentationStyle = .fullScreen
        present(searchVC, animated: true, completion: nil)
    }
    
    // Function to handle slider value changes with snapping
    @objc func sliderValueChanged(_ sender: UISlider) {
        let step: Float = 50
        let newValue = round(sender.value / step) * step
        
        // Animate the transition to the new value
        UIView.animate(withDuration: 0.3) {
            sender.setValue(newValue, animated: true)
        }
        
        // Show half modal when the slider value is 100
        if newValue == 100 && !hasShownHalfModal {
            hasShownHalfModal = true
            showSavedBookmarkLists()
            showSavedPOIMarkers()
        } else if newValue != 100 {
            hasShownHalfModal = false
            mapView.clear() // Clear all markers
        }
    }
    
    // Function to show the saved bookmark lists in a half modal
    func showSavedBookmarkLists() {
        let savedBookmarksVC = SavedBookmarksViewController()
        let navController = UINavigationController(rootViewController: savedBookmarksVC)
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()] // Present as a half modal
        }
        present(navController, animated: true, completion: nil)
    }
    
    @objc func bookmarksButtonTapped() {
        let bookmarkedPOIsVC = BookmarkedPOIsViewController()
        bookmarkedPOIsVC.modalPresentationStyle = .fullScreen
        present(bookmarkedPOIsVC, animated: true, completion: nil)
    }
    
    // Handle search input
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Hide keyboard
        if let query = searchBar.text {
            searchForPlace(query: query)
        }
    }
    
    // Search for a place using Google Places API
    func searchForPlace(query: String) {
        let filter = GMSAutocompleteFilter()
        filter.type = .noFilter // You can set type to .geocode for addresses only
        
        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { (results, error) in
            if let error = error {
                print("Error finding place: \(error.localizedDescription)")
                return
            }
            
            if let result = results?.first {
                self.getPlaceDetails(placeID: result.placeID)
            }
        }
    }
    
    // Get place details and move map to that location
    func getPlaceDetails(placeID: String) {
        placesClient.lookUpPlaceID(placeID) { (place, error) in
            if let error = error {
                print("Error getting place details: \(error.localizedDescription)")
                return
            }
            
            if let place = place {
                let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 15.0)
                self.mapView.animate(to: camera)
            }
        }
    }
    
    // Update map to follow user location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude, longitude: location.coordinate.longitude, zoom: 15.0)
            mapView.animate(to: camera) // Move camera to user location
        }
    }
    
    // Handle location permission denied
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied {
            print("Location access denied")
        }
    }
    
    // Delegate method: Handle POI taps
    func mapView(_ mapView: GMSMapView, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
        print("POI Tapped: \(name), Place ID: \(placeID), Location: \(location)")
        
        placesClient.lookUpPlaceID(placeID) { (place, error) in
            if let error = error {
                print("Error getting place details: \(error.localizedDescription)")
                return
            }
            
            if let place = place {
                // Fetch photos for the POI
                self.fetchPhotos(forPlaceID: placeID) { photos in
                    DispatchQueue.main.async {
                        let detailVC = POIDetailViewController()
                        detailVC.placeID = placeID // Ensure placeID is set
                        detailVC.placeName = name
                        detailVC.address = place.formattedAddress
                        detailVC.phoneNumber = place.phoneNumber
                        detailVC.website = place.website?.absoluteString
                        detailVC.rating = Double(place.rating)
                        detailVC.openingHours = place.openingHours?.weekdayText
                        detailVC.photos = photos // Pass the photos to the detail view controller
                        // do the same for latitude and lognitute
                        detailVC.latitude = location.latitude
                        detailVC.longitude = location.longitude
                        detailVC.modalPresentationStyle = .pageSheet
                        if let sheet = detailVC.sheetPresentationController {
                            sheet.detents = [.medium()]
                        }
                        self.present(detailVC, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    // Fetch photos for a place
    func fetchPhotos(forPlaceID placeID: String, completion: @escaping ([UIImage]) -> Void) {
        placesClient.lookUpPhotos(forPlaceID: placeID) { (photosMetadata, error) in
            if let error = error {
                print("Error fetching photos: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let photosMetadata = photosMetadata else {
                completion([])
                return
            }
            
            var photos: [UIImage] = []
            let dispatchGroup = DispatchGroup()
            
            for photoMetadata in photosMetadata.results {
                dispatchGroup.enter()
                self.placesClient.loadPlacePhoto(photoMetadata) { (photo, error) in
                    if let photo = photo {
                        photos.append(photo)
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(photos)
            }
        }
    }
    
    func showSavedPOIMarkers() {
        let savedPOIs = BookmarksManager.shared.bookmarkLists.flatMap { $0.bookmarks }
        
        guard !savedPOIs.isEmpty else {
            print("No saved POIs to display.")
            return
        }
        
        for poi in savedPOIs {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
            marker.title = poi.name
            marker.map = mapView
            print("POI: \(poi.name) at (\(poi.latitude), \(poi.longitude))")
        }
        
        print("Displayed \(savedPOIs.count) saved POIs on the map.")
        
        
    }
    
    class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
        var searchBar: UISearchBar!
        var tableView: UITableView!
        var placesClient = GMSPlacesClient.shared()
        var predictions: [GMSAutocompletePrediction] = []
        var backButton: UIButton!
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            
            backButton = UIButton(type: .system)
                    backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
                    backButton.tintColor = .black
                    backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
                    backButton.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(backButton)
            
            searchBar = UISearchBar()
            searchBar.placeholder = "Search for a place"
            searchBar.delegate = self
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(searchBar)
            
            tableView = UITableView()
            tableView.delegate = self
            tableView.dataSource = self
            tableView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(tableView)
            
            NSLayoutConstraint.activate([
                // set back button on the left corner, above search bar
                backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
                
                // set search bar below back button
                searchBar.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
                searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                
                tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        @objc func backButtonTapped() {
            dismiss(animated: true, completion: nil)
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            let filter = GMSAutocompleteFilter()
            placesClient.findAutocompletePredictions(fromQuery: searchText, filter: filter, sessionToken: nil) { (results, error) in
                if let error = error {
                    print("Autocomplete error: \(error.localizedDescription)")
                    return
                }
                self.predictions = results ?? []
                self.tableView.reloadData()
            }
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return predictions.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
            let prediction = predictions[indexPath.row]
            cell.textLabel?.text = prediction.attributedPrimaryText.string
            cell.detailTextLabel?.text = prediction.attributedSecondaryText?.string
            return cell
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let prediction = predictions[indexPath.row]
            print("Selected POI: \(prediction.attributedPrimaryText.string)")
            navigationController?.popToRootViewController(animated: true)
        }
    }
}
