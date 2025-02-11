import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class HomeViewController: UIViewController {
    
    var mapView: GMSMapView!
    var locationManager = CLLocationManager()
    var placesClient: GMSPlacesClient!
    var slider: UISlider!
    var hasShownHalfModal = false
    var searchButton: UIButton!
    var profileButton: UIButton!
    
    let mapID = GMSMapID(identifier: "7f9a1d61a6b1809f")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGooglePlacesClient()
        setupMapView()
        setupLocationManager()
        setupSlider()
        setupSearchButton()
        setupProfileButton()
        setupConstraints()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addDotsToSlider()
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
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func setupSlider() {
        slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.minimumTrackTintColor = .black
        slider.maximumTrackTintColor = .black
        slider.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        slider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        slider.thumbTintColor = UIColor(red: 0.792, green: 1.0, blue: 0.341, alpha: 0.8)
        view.addSubview(slider)
    }
    
    private func setupSearchButton() {
        searchButton = UIButton(type: .system)
        searchButton.backgroundColor = .white
        searchButton.layer.cornerRadius = 20
        searchButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        searchButton.layer.shadowColor = UIColor.black.cgColor
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.tintColor = .black
        searchButton.imageView?.contentMode = .scaleAspectFit
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchButton)
    }
    
    private func setupProfileButton() {
        profileButton = UIButton(type: .system)
        profileButton.backgroundColor = .white
        profileButton.layer.cornerRadius = 20
        profileButton.layer.shadowColor = UIColor.black.cgColor
        profileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        profileButton.tintColor = .black
        profileButton.imageView?.contentMode = .scaleAspectFit
        profileButton.addTarget(self, action: #selector(goToProfile), for: .touchUpInside)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(profileButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Slider constraints
            slider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Search button constraints
            searchButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 10),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchButton.widthAnchor.constraint(equalToConstant: 40),
            searchButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Profile button constraints
            profileButton.topAnchor.constraint(equalTo: searchButton.bottomAnchor, constant: 10),
            profileButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 40),
            profileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func addDotsToSlider() {
        view.subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }
        
        let trackWidth = slider.frame.width - slider.thumbRect(forBounds: slider.bounds, trackRect: slider.bounds, value: 0).width
        let startX = slider.frame.origin.x + (slider.thumbRect(forBounds: slider.bounds, trackRect: slider.bounds, value: 0).width / 2)
        
        addDot(at: startX, for: slider)
        addDot(at: startX + (trackWidth / 2), for: slider)
        addDot(at: startX + trackWidth, for: slider)
    }
    
    @objc private func searchButtonTapped() {
        let searchVC = SearchViewController()
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.mainViewController = self
        present(searchVC, animated: true, completion: nil)
    }
    
    @objc private func goToProfile() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
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
    
    private func addDot(at xPosition: CGFloat, for slider: UISlider) {
        let dotSize: CGFloat = 10
        let trackStart = slider.frame.minX
        let trackEnd = slider.frame.maxX
        
        guard xPosition > trackStart, xPosition < trackEnd else { return }
        
        let dot = UIView(frame: CGRect(x: xPosition - (dotSize / 2),
                                       y: slider.frame.midY - (dotSize / 2),
                                       width: dotSize,
                                       height: dotSize))
        dot.backgroundColor = .black
        dot.layer.cornerRadius = dotSize / 2
        dot.tag = 999
        view.addSubview(dot)
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
            print("POI: \(poi.name) at (\(poi.latitude), \(poi.longitude))")
        }
        
        print("Displayed \(savedPOIs.count) saved POIs on the map.")
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

// MARK: - UISearchBarDelegate
extension HomeViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let query = searchBar.text {
            searchForPlace(query: query)
        }
    }
    
    private func searchForPlace(query: String) {
        let filter = GMSAutocompleteFilter()
        filter.type = .noFilter
        
        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { [weak self] (results, error) in
            if let error = error {
                print("Error finding place: \(error.localizedDescription)")
                return
            }
            
            if let result = results?.first {
                self?.getPlaceDetails(placeID: result.placeID)
            }
        }
    }
    
    private func getPlaceDetails(placeID: String) {
        placesClient.lookUpPlaceID(placeID) { [weak self] (place, error) in
            if let error = error {
                print("Error getting place details: \(error.localizedDescription)")
                return
            }
            
            if let place = place {
                let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 15.0)
                self?.mapView.animate(to: camera)
            }
        }
    }
}

// MARK: - SearchViewController
class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    var searchBar: UISearchBar!
    var tableView: UITableView!
    var placesClient = GMSPlacesClient.shared()
    var predictions: [GMSAutocompletePrediction] = []
    var backButton: UIButton!
    
    weak var mainViewController: HomeViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
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
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchBar.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let filter = GMSAutocompleteFilter()
        placesClient.findAutocompletePredictions(fromQuery: searchText, filter: filter, sessionToken: nil) { [weak self] (results, error) in
            if let error = error {
                print("Autocomplete error: \(error.localizedDescription)")
                return
            }
            self?.predictions = results ?? []
            self?.tableView.reloadData()
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
        dismiss(animated: true) {
            self.mainViewController?.fetchPlaceDetailsAndPresent(placeID: prediction.placeID, name: prediction.attributedPrimaryText.string, location: nil)
        }
    }
}
