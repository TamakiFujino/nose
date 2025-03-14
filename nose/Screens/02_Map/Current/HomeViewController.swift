import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class HomeViewController: UIViewController {
    
    var mapContainerViewController: MapContainerViewController!
    var locationManager = CLLocationManager()
    var placesClient: GMSPlacesClient!
    
    var hasShownHalfModal = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGooglePlacesClient()
        setupLocationManager()
        setupMapContainer()
        
        mapContainerViewController.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        mapContainerViewController.searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        mapContainerViewController.profileButton.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
    }
    
    private func setupGooglePlacesClient() {
        placesClient = GMSPlacesClient.shared()
    }
    
    private func setupMapContainer() {
        mapContainerViewController = MapContainerViewController()
        addChild(mapContainerViewController)
        view.addSubview(mapContainerViewController.view)
        mapContainerViewController.view.frame = view.bounds
        mapContainerViewController.didMove(toParent: self)
        view.sendSubviewToBack(mapContainerViewController.view)
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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
    
    // MARK: - Button actions
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
        
        updateUIForSliderValue(newValue)
    }
    
    private func updateUIForSliderValue(_ value: Float) {
        switch value {
        case 0:
            if !hasShownHalfModal {
                presentZeroSliderModal()
            }
            mapContainerViewController.buttonA.isHidden = false
            mapContainerViewController.searchButton.isHidden = true
            mapContainerViewController.savedButton.isHidden = true
            
        case 50:
            mapContainerViewController.buttonA.isHidden = true
            mapContainerViewController.searchButton.isHidden = false
            mapContainerViewController.savedButton.isHidden = true
            
        case 100:
            if !hasShownHalfModal {
                presentSavedBookmarksModal()
            }
            mapContainerViewController.buttonA.isHidden = true
            mapContainerViewController.searchButton.isHidden = true
            mapContainerViewController.savedButton.isHidden = false
            
        default:
            hasShownHalfModal = false
            mapContainerViewController.mapView.clear()
            mapContainerViewController.buttonA.isHidden = true
            mapContainerViewController.searchButton.isHidden = true
            mapContainerViewController.savedButton.isHidden = true
        }
    }
    
    private func presentZeroSliderModal() {
        hasShownHalfModal = true
        let zeroSliderModalVC = PastMapMainViewController()
        zeroSliderModalVC.modalPresentationStyle = .pageSheet
        if let sheet = zeroSliderModalVC.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(zeroSliderModalVC, animated: true, completion: nil)
    }
    
    private func presentSavedBookmarksModal() {
        hasShownHalfModal = true
        let savedBookmarksVC = SavedBookmarksViewController()
        savedBookmarksVC.mapView = mapContainerViewController.mapView
        savedBookmarksVC.modalPresentationStyle = .pageSheet
        if let sheet = savedBookmarksVC.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(savedBookmarksVC, animated: true, completion: nil)
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
                            self?.mapContainerViewController.mapView.animate(to: camera)
                        } else {
                            detailVC.latitude = place.coordinate.latitude
                            detailVC.longitude = place.coordinate.longitude
                            let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 15.0)
                            self?.mapContainerViewController.mapView.animate(to: camera)
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
}

// MARK: - CLLocationManagerDelegate
extension HomeViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude, longitude: location.coordinate.longitude, zoom: 15.0)
            mapContainerViewController.mapView.animate(to: camera)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied {
            print("Location access denied")
        }
    }
}
