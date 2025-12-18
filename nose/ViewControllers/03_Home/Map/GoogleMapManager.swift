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
    private var collectionPlaceMarkers: [GMSMarker] = []
    private var collectionPlacesData: [(place: PlaceCollection.Place, collection: PlaceCollection)] = [] // Store for zoom updates
    private var searchPlaceMarker: GMSMarker? // Marker for searched place (shown when PlaceDetailViewController is open)
    private var followUserLocation: Bool = true
    private var currentZoom: Float = Constants.defaultZoom
    
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
        // Use reduced accuracy for faster initial location fix
        // We can refine accuracy later if needed, but this gets us on the map quickly
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 10 // Only update if moved 10 meters (reduces battery usage)
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
        Logger.log("showPlaceOnMap: \(place.name ?? "Unknown")", level: .debug, category: "Map")
        
        // Remove previous search marker if exists
        searchPlaceMarker?.map = nil
        
        let marker = MarkerFactory.createPlaceMarker(for: place)
        marker.map = mapView
        searchPlaceMarker = marker
        
        // Adjust camera position to account for modal
        // Modal starts at 60% from top and has height 40% (from code: y: 0.6, height: 0.4)
        // Pin should be positioned higher - about 30% of screen height down from top of modal
        // So pin position = 60% (modal start) - 30% = 30% from top of screen
        let screenHeight = mapView.bounds.height
        let modalStartFromTop = 0.6 // Modal starts at 60% from top
        let pinOffsetFromModalTop = 0.3 // Pin is 30% of screen height down from top of modal (increased from 0.2)
        let targetPositionFromTop = modalStartFromTop - pinOffsetFromModalTop // 30% from top of screen
        let currentPositionFromTop = 0.5 // Center of screen (50% from top)
        let offsetFromTop = screenHeight * (currentPositionFromTop - targetPositionFromTop) // 20% of screen height
        
        // Calculate latitude offset based on zoom level and screen dimensions
        // Formula: degrees per pixel = (156543.03392 * cos(lat * π/180)) / (2^zoom)
        let zoom = Double(Constants.defaultZoom)
        let latRad = place.coordinate.latitude * .pi / 180.0
        let metersPerPixel = 156543.03392 * cos(latRad) / pow(2.0, zoom)
        let offsetMeters = Double(offsetFromTop) * metersPerPixel
        let metersPerDegreeLat = 111000.0 // Approximate meters per degree latitude
        let offsetLatitude = offsetMeters / metersPerDegreeLat
        
        // Calculate adjusted coordinate (move camera south so pin appears higher on screen)
        let adjustedLatitude = place.coordinate.latitude - offsetLatitude
        
        let camera = GMSCameraPosition.camera(
            withLatitude: adjustedLatitude,
            longitude: place.coordinate.longitude,
            zoom: Constants.defaultZoom
        )
        Logger.log("Animating map to: \(adjustedLatitude), \(place.coordinate.longitude) (adjusted for modal - pin higher)", level: .debug, category: "Map")
        mapView.animate(to: camera)

        // User picked a place – stop auto recentring to current location
        followUserLocation = false
    }
    
    func clearSearchPlaceMarker() {
        searchPlaceMarker?.map = nil
        searchPlaceMarker = nil
    }
    
    func clearMarkers() {
        // Animate fade out before removing
        let markersToRemove = markers
        markers.removeAll()
        
        for marker in markersToRemove {
            if let iconView = marker.iconView {
                UIView.animate(withDuration: 0.3, animations: {
                    iconView.alpha = 0
                }, completion: { _ in
                    marker.map = nil
                })
            } else {
                marker.map = nil
            }
        }
    }
    
    func clearEventMarkers() {
        eventMarkers.forEach { $0.map = nil }
        eventMarkers.removeAll()
    }
    
    func clearCollectionPlaceMarkers() {
        collectionPlaceMarkers.forEach { $0.map = nil }
        collectionPlaceMarkers.removeAll()
        collectionPlacesData.removeAll()
    }
    
    private func updateCollectionPlaceMarkers() {
        // Clear existing markers
        collectionPlaceMarkers.forEach { $0.map = nil }
        collectionPlaceMarkers.removeAll()
        
        // Get current zoom level
        currentZoom = mapView.camera.zoom
        
        // Recreate markers with current zoom level using Firestore data
        for (place, collection) in collectionPlacesData {
            let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let marker = MarkerFactory.createCollectionPlaceMarker(
                coordinate: coordinate,
                title: place.name,
                snippet: place.formattedAddress,
                collection: collection,
                zoomLevel: currentZoom
            )
            marker.map = mapView
            collectionPlaceMarkers.append(marker)
        }
    }
    
    func showEventsOnMap(_ events: [Event]) {
        Logger.log("showEventsOnMap with \(events.count) events", level: .debug, category: "Map")
        
        // Clear existing event markers
        clearEventMarkers()
        
        // Create and add markers for each event
        for event in events {
            guard event.location.coordinates != nil else {
                Logger.log("Skipping event '\(event.title)' - no coordinates", level: .warn, category: "Map")
                continue
            }
            
            let marker = MarkerFactory.createEventMarker(for: event)
            marker.map = mapView
            eventMarkers.append(marker)
            Logger.log("Added event marker: \(event.title)", level: .debug, category: "Map")
        }
        
        Logger.log("Total event markers on map: \(eventMarkers.count)", level: .debug, category: "Map")
    }
    
    func resetMap() {
        clearMarkers()
        clearEventMarkers()
        clearCollectionPlaceMarkers()
        followUserLocation = true
        let camera = GMSCameraPosition.camera(
            withLatitude: Constants.defaultLatitude,
            longitude: Constants.defaultLongitude,
            zoom: Constants.defaultZoom
        )
        mapView.animate(to: camera)
    }
    
    func showCollectionPlacesOnMap(_ collections: [PlaceCollection]) {
        Logger.log("showCollectionPlacesOnMap with \(collections.count) collections", level: .debug, category: "Map")
        
        // Clear existing collection place markers
        clearCollectionPlaceMarkers()
        
        // Track which collection each place belongs to (use first collection if place appears in multiple)
        var placeToCollectionMap: [String: (place: PlaceCollection.Place, collection: PlaceCollection)] = [:]
        
        for collection in collections {
            for place in collection.places {
                // Only add if we haven't seen this place yet (first collection wins)
                if placeToCollectionMap[place.placeId] == nil {
                    placeToCollectionMap[place.placeId] = (place: place, collection: collection)
                }
            }
        }
        
        Logger.log("Found \(placeToCollectionMap.count) unique places across all collections", level: .debug, category: "Map")
        
        // Use Firestore data directly - no API calls needed!
        let placesData: [(PlaceCollection.Place, PlaceCollection)] = Array(placeToCollectionMap.values).map { ($0.place, $0.collection) }
        
        // Filter out places with invalid coordinates (0,0)
        let validPlacesData = placesData.filter { $0.0.latitude != 0.0 || $0.0.longitude != 0.0 }
        
        // Store places data for zoom updates
        self.collectionPlacesData = validPlacesData
        
        // Remove red place markers that are at the same location as collection places
        removeRedMarkersForCollectionPlaces(validPlacesData)
        
        // Create markers for all places with their collection icons
        self.updateCollectionPlaceMarkers()
        
        Logger.log("Total collection place markers on map: \(self.collectionPlaceMarkers.count)", level: .debug, category: "Map")
    }
    
    private func removeRedMarkersForCollectionPlaces(_ collectionPlaces: [(place: PlaceCollection.Place, collection: PlaceCollection)]) {
        // Count how many markers we'll remove
        var removedCount = 0
        let tolerance: Double = 0.0001 // Small tolerance for floating point comparison
        
        // Remove red markers that are at the same location as collection places
        markers.removeAll { marker in
            let markerLat = marker.position.latitude
            let markerLng = marker.position.longitude
            
            // Check if this marker is at the same location as any collection place
            for collectionPlace in collectionPlaces {
                let placeLat = collectionPlace.place.latitude
                let placeLng = collectionPlace.place.longitude
                
                // Check if coordinates match (within tolerance)
                if abs(placeLat - markerLat) < tolerance && abs(placeLng - markerLng) < tolerance {
                    // Remove the marker from the map
                    marker.map = nil
                    removedCount += 1
                    return true
                }
            }
            return false
        }
        
        if removedCount > 0 {
            Logger.log("Removed \(removedCount) red marker(s) that overlap with collection places", level: .debug, category: "Map")
        }
    }

    // Convenience to move camera to arbitrary coordinate (for deep links)
    func moveToCoordinate(_ latitude: Double, _ longitude: Double, zoom: Float = Constants.defaultZoom) {
        let camera = GMSCameraPosition.camera(withLatitude: latitude, longitude: longitude, zoom: zoom)
        mapView.animate(to: camera)
        followUserLocation = false
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
        
        // Move to current location immediately if we're following user location
        // Don't wait for markers to be empty - get user on map quickly
        if followUserLocation {
            moveToCurrentLocation()
        }
        
        // Update custom marker
        updateCurrentLocationMarker(at: location)
        
        // Stop updating location after first update to save battery
        // We got what we need for initial map positioning
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.googleMapManager(self, didFailWithError: error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted, start location updates for faster response
            // startUpdatingLocation() is faster than requestLocation() for initial fix
            locationManager.startUpdatingLocation()
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
    
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        // Detect zoom changes and update marker sizes
        let newZoom = position.zoom
        let zoomThreshold: Float = 12.0
        
        // Only update if zoom crosses the threshold
        let wasZoomedOut = currentZoom < zoomThreshold
        let isZoomedOut = newZoom < zoomThreshold
        
        if wasZoomedOut != isZoomedOut && !collectionPlacesData.isEmpty {
            currentZoom = newZoom
            updateCollectionPlaceMarkers()
        } else {
            currentZoom = newZoom
        }
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
