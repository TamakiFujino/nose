import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces

final class MapManager: NSObject {
    // MARK: - Properties
    private var mapView: GMSMapView
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var currentLocationMarker: GMSMarker?
    private var searchResults: [GMSPlace] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    
    // MARK: - Initialization
    init(mapView: GMSMapView) {
        self.mapView = mapView
        super.init()
        setupMapView()
        setupLocationManager()
        sessionToken = GMSAutocompleteSessionToken()
    }
    
    // MARK: - Setup
    private func setupMapView() {
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.delegate = self
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Public Methods
    func moveToCurrentLocation() {
        guard let location = currentLocation else {
            locationManager.requestLocation()
            return
        }
        
        let camera = GMSCameraPosition.camera(
            withLatitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            zoom: 15
        )
        mapView.animate(to: camera)
    }
    
    func searchPlaces(query: String, completion: @escaping ([GMSPlace]) -> Void) {
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]
        
        // Clear previous results
        searchResults = []
        
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
                        DispatchQueue.main.async {
                            self.searchResults.append(place)
                            completion(self.searchResults)
                        }
                    }
                }
            }
        }
    }
    
    func showPlaceOnMap(_ place: GMSPlace) {
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
    }
    
    private func updateCurrentLocationMarker(at location: CLLocation) {
        // Remove existing marker if any
        currentLocationMarker?.map = nil
        
        // Create custom marker
        let marker = GMSMarker(position: location.coordinate)
        
        // Create custom marker view
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        markerView.backgroundColor = .clear
        
        // Create outer circle (pulse effect)
        let outerCircle = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        outerCircle.backgroundColor = UIColor.firstColor.withAlphaComponent(0.2)
        outerCircle.layer.cornerRadius = 20
        outerCircle.layer.masksToBounds = true
        markerView.addSubview(outerCircle)
        
        // Create inner circle (solid)
        let innerCircle = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        innerCircle.backgroundColor = .firstColor
        innerCircle.layer.cornerRadius = 10
        innerCircle.layer.masksToBounds = true
        markerView.addSubview(innerCircle)
        
        // Add pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.2
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        // Ensure the animation maintains the circular shape
        outerCircle.layer.add(pulseAnimation, forKey: "pulse")
        outerCircle.layer.allowsEdgeAntialiasing = true
        
        // Set the custom marker view
        marker.iconView = markerView
        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        marker.map = mapView
        
        // Store reference to marker
        currentLocationMarker = marker
    }
}

// MARK: - CLLocationManagerDelegate
extension MapManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            mapView.isMyLocationEnabled = true
        case .denied, .restricted:
            // Show alert to enable location services
            if let topVC = UIApplication.shared.windows.first?.rootViewController {
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
                topVC.present(alert, animated: true)
            }
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Update custom marker
        updateCurrentLocationMarker(at: location)
        
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
extension MapManager: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        // Handle map tap if needed
    }
    
    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        print("Map style successfully loaded")
    }
} 