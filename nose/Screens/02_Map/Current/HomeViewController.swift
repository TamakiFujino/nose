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

        let navController = UINavigationController(rootViewController: savedBookmarksVC)
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium()]
        }

        present(navController, animated: true, completion: nil)
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
                        guard let self = self else { return }

                        // Create a BookmarkedPOI from the fetched GMSPlace and other details
                        let bookmarkedPOIFromPlace = BookmarkedPOI(
                            placeID: placeID, // Use the original placeID from the tap
                            name: name,       // Use the original name from the tap
                            address: place.formattedAddress,
                            phoneNumber: place.phoneNumber,
                            website: place.website?.absoluteString,
                            rating: Double(place.rating),
                            openingHours: place.openingHours?.weekdayText,
                            latitude: location?.latitude ?? place.coordinate.latitude, // Prioritize location from tap if available
                            longitude: location?.longitude ?? place.coordinate.longitude,
                            visited: false // Default to false, can be updated if necessary elsewhere
                        )

                        // Use the new initializer
                        let detailVC = POIDetailViewController(poi: bookmarkedPOIFromPlace, showBookmarkIcon: true)
                        detailVC.photos = photos // Photos are fetched separately

                        // Camera animation
                        let camLatitude = location?.latitude ?? place.coordinate.latitude
                        let camLongitude = location?.longitude ?? place.coordinate.longitude
                        let camera = GMSCameraPosition.camera(withLatitude: camLatitude, longitude: camLongitude, zoom: 15.0)
                        self.mapContainerViewController.mapView.animate(to: camera)
                        
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
                self.placesClient.loadPlacePhoto(photoMetadata) { (photo, _) in
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
