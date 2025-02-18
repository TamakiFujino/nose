import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class HomeViewController: UIViewController {
    
    var mapView: GMSMapView!
    var locationManager = CLLocationManager()
    var placesClient: GMSPlacesClient!
    var slider: CustomSlider!
    var hasShownHalfModal = false
    private let shadowBackground = BackShadowView()
    private var profileButton: IconButton!
    private var searchButton: IconButton!
    
    let mapID = GMSMapID(identifier: "7f9a1d61a6b1809f")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGooglePlacesClient()
        setupMapView()
        setupLocationManager()
        
        setupShadowBackground()
        setupSlider()
        
        // Search button
        searchButton = IconButton(image: UIImage(systemName: "magnifyingglass"),
                                  action: #selector(searchButtonTapped),
                                  target: self)
        view.addSubview(searchButton)
        
        // Profile button
        profileButton = IconButton(image: UIImage(systemName: "person.fill"),
                                   action: #selector(profileButtonTapped),
                                   target: self)
        view.addSubview(profileButton)
        
        setupConstraints()
    }
    
    private func setupGooglePlacesClient() {
        placesClient = GMSPlacesClient.shared()
    }
    
    private func setupMapView() {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12.0)
        mapView = GMSMapView(frame: self.view.bounds, mapID: mapID, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        mapView.delegate = self
        view.addSubview(mapView)
        view.sendSubviewToBack(mapView) // Ensure the mapView is at the back
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func setupSlider() {
        slider = CustomSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        view.addSubview(slider)
    }
    
    private func setupShadowBackground() {
        shadowBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shadowBackground)
        
        // Set up constraints to make it cover 1/5 of the screen height
        NSLayoutConstraint.activate([
            shadowBackground.topAnchor.constraint(equalTo: view.topAnchor),
            shadowBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            shadowBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shadowBackground.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // 1/5 of the screen height
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Search button at the top-right corner
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            
            // Profile button closer to the search button
            profileButton.topAnchor.constraint(equalTo: searchButton.topAnchor),
            profileButton.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -10),
            
            // Slider closer to the buttons
            slider.topAnchor.constraint(equalTo: searchButton.bottomAnchor, constant: 10),
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    @objc private func searchButtonTapped() {
        let searchVC = SearchViewController()
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.mainViewController = self
        present(searchVC, animated: true, completion: nil)
    }
    
    @objc private func profileButtonTapped() {
        print("Profile button tapped")
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func sliderValueChanged(_ sender: CustomSlider) {
        let step: Float = 50
        let newValue = round(sender.value / step) * step
        
        UIView.animate(withDuration: 0.3) {
            sender.setValue(newValue, animated: true)
        }
        
        if newValue == 100 && !hasShownHalfModal {
            hasShownHalfModal = true
            showSavedBookmarkLists()
            showSavedPOIMarkers()
            searchButton.isHidden = true
        } else if newValue != 100 {
            hasShownHalfModal = false
            mapView.clear()
            searchButton.isHidden = false
        }
    }
    
    private func showSavedBookmarkLists() {
        let savedBookmarksVC = SavedBookmarksViewController()
        let navController = UINavigationController(rootViewController: savedBookmarksVC)
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navController, animated: true, completion: nil)
    }
    
    // Hide navigation bar including back button
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - GMSMapViewDelegate
extension HomeViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
        fetchPlaceDetailsAndPresent(placeID: placeID, name: name, location: location)
    }
    
    func fetchPlaceDetailsAndPresent(placeID: String, name: String, location: CLLocationCoordinate2D?) {
        placesClient.lookUpPlaceID(placeID) { [weak self] (place, error) in
            if let error = error {
                print("Error getting place details: \(error.localizedDescription)")
                return
            }
            
            if let place = place {
                self?.fetchPhotos(forPlaceID: placeID) { photos in
                    DispatchQueue.main.async {
                        let detailVC = POIDetailViewController()
                        detailVC.placeID = placeID
                        detailVC.placeName = name
                        detailVC.address = place.formattedAddress
                        detailVC.phoneNumber = place.phoneNumber
                        detailVC.website = place.website?.absoluteString
                        detailVC.rating = Double(place.rating)
                        detailVC.openingHours = place.openingHours?.weekdayText
                        detailVC.photos = photos
                        if let location = location {
                            detailVC.latitude = location.latitude
                            detailVC.longitude = location.longitude
                            let camera = GMSCameraPosition.camera(withLatitude: location.latitude, longitude: location.longitude, zoom: 15.0)
                            self?.mapView.animate(to: camera)
                        } else {
                            detailVC.latitude = place.coordinate.latitude
                            detailVC.longitude = place.coordinate.longitude
                            let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 15.0)
                            self?.mapView.animate(to: camera)
                        }
                        detailVC.modalPresentationStyle = .pageSheet
                        if let sheet = detailVC.sheetPresentationController {
                            sheet.detents = [.medium()]
                        }
                        self?.present(detailVC, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    private func fetchPhotos(forPlaceID placeID: String, completion: @escaping ([UIImage]) -> Void) {
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
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension HomeViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude, longitude: location.coordinate.longitude, zoom: 15.0)
            mapView.animate(to: camera)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied {
            print("Location access denied")
        }
    }
}
