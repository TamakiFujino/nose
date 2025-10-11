import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces

protocol GoogleMapManagerDelegate: AnyObject {
    func googleMapManager(_ manager: GoogleMapManager, didFailWithError error: Error)
    func googleMapManager(_ manager: GoogleMapManager, didTapEventMarker event: Event)
}

final class GoogleMapManager: NSObject {
    
    // MARK: - Constants
    private enum Constants {
        static let defaultZoom: Float = 15
        static let defaultLatitude: Double = 35.6812
        static let defaultLongitude: Double = 139.7671
        static let markerSize: CGFloat = 40
    }
    
    // MARK: - Properties
    private let mapView: GMSMapView
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var currentLocationMarker: GMSMarker?
    private var searchResults: [GMSPlace] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var displayLink: CADisplayLink?
    private var markers: [GMSMarker] = []
    private var eventMarkers: [GMSMarker] = []
    private var followUserLocation: Bool = true
    
    weak var delegate: GoogleMapManagerDelegate?
    
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
        // Don't request authorization here - let the delegate handle it based on current status
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
            zoom: Constants.defaultZoom
        )
        mapView.animate(to: camera)
    }
    
    func searchPlaces(query: String, completion: @escaping ([GMSAutocompletePrediction]) -> Void) {
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: sessionToken
        ) { results, error in
            if let error = error {
                print("Error searching places: \(error.localizedDescription)")
                return
            }
            
            guard let results = results else { return }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
    
    func fetchPlaceDetails(for prediction: GMSAutocompletePrediction, completion: @escaping (GMSPlace?) -> Void) {
        PlacesAPIManager.shared.fetchMapPlaceDetails(placeID: prediction.placeID) { place in
            completion(place)
        }
    }
    
    func showPlaceOnMap(_ place: GMSPlace) {
        print("🗺️ GoogleMapManager.showPlaceOnMap called for: \(place.name ?? "Unknown")")
        let marker = MarkerFactory.createPlaceMarker(for: place)
        marker.map = mapView
        
        let camera = GMSCameraPosition.camera(
            withLatitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            zoom: Constants.defaultZoom
        )
        print("🗺️ Animating map to: \(place.coordinate.latitude), \(place.coordinate.longitude)")
        mapView.animate(to: camera)
        
        markers.append(marker)

        // User picked a place – stop auto recentring to current location
        followUserLocation = false
    }
    
    func clearMarkers() {
        markers.forEach { $0.map = nil }
        markers.removeAll()
    }
    
    func clearEventMarkers() {
        eventMarkers.forEach { $0.map = nil }
        eventMarkers.removeAll()
    }
    
    func showEventsOnMap(_ events: [Event]) {
        print("🗺️ GoogleMapManager.showEventsOnMap called with \(events.count) events")
        
        // Clear existing event markers
        clearEventMarkers()
        
        // Create and add markers for each event
        for event in events {
            guard event.location.coordinates != nil else {
                print("⚠️ Skipping event '\(event.title)' - no coordinates")
                continue
            }
            
            let marker = MarkerFactory.createEventMarker(for: event)
            marker.map = mapView
            eventMarkers.append(marker)
            print("✅ Added event marker: \(event.title)")
        }
        
        print("📍 Total event markers on map: \(eventMarkers.count)")
    }
    
    func resetMap() {
        clearMarkers()
        clearEventMarkers()
        followUserLocation = true
        let camera = GMSCameraPosition.camera(
            withLatitude: Constants.defaultLatitude,
            longitude: Constants.defaultLongitude,
            zoom: Constants.defaultZoom
        )
        mapView.animate(to: camera)
    }

    private func updateCurrentLocationMarker(at location: CLLocation) {
        currentLocationMarker?.map = nil
        currentLocationMarker = MarkerFactory.createCurrentLocationMarker(at: location)
        currentLocationMarker?.map = mapView
    }

    @objc private func updateOuterCircleCornerRadius() {
        guard
            let markerView = mapView.subviews.first(where: { $0.tag == 888 }),
            let outerCircle = markerView.viewWithTag(999)
        else { return }

        let currentScale = outerCircle.layer.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat ?? 1.0
        let baseWidth: CGFloat = Constants.markerSize
        let scaledWidth = baseWidth * currentScale
        outerCircle.layer.cornerRadius = scaledWidth / 2
    }
}

// MARK: - CLLocationManagerDelegate
extension GoogleMapManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        if markers.isEmpty && followUserLocation {
            moveToCurrentLocation()
        }
        
        // Update custom marker
        updateCurrentLocationMarker(at: location)
        
        // Stop updating location after first update
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.googleMapManager(self, didFailWithError: error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted, request location
            locationManager.requestLocation()
        case .denied, .restricted:
            delegate?.googleMapManager(self, didFailWithError: NSError(
                domain: "GoogleMapManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access denied"]
            ))
        case .notDetermined:
            // Only request permission if we haven't asked before
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - GMSMapViewDelegate
extension GoogleMapManager: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        // Handle map tap if needed
    }
    
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        // Check if this is an event marker
        if let event = marker.userData as? Event {
            print("🎯 Event marker tapped: \(event.title)")
            delegate?.googleMapManager(self, didTapEventMarker: event)
            return true // Consume the event
        }
        return false // Let default behavior happen for other markers
    }
    
    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        print("Map style successfully loaded")
    }
} 
