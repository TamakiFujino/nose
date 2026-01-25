import UIKit
import MapboxMaps
import CoreLocation
import GooglePlaces

protocol MapboxMapManagerDelegate: AnyObject {
    func mapboxMapManager(_ manager: MapboxMapManager, didFailWithError error: Error)
    func mapboxMapManager(_ manager: MapboxMapManager, didTapEventMarker event: Event)
}

final class MapboxMapManager: NSObject {
    
    // MARK: - Constants
    private enum Constants {
        static let defaultZoom: Double = 15
        static let defaultLatitude: Double = 35.6812
        static let defaultLongitude: Double = 139.7671
        static let markerSize: CGFloat = 40
    }
    
    // MARK: - Properties
    private let mapView: MapView
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var currentLocationAnnotation: PointAnnotation?
    private var searchResults: [GMSPlace] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var displayLink: CADisplayLink?
    
    // Annotation managers
    private var placeAnnotationManager: PointAnnotationManager?
    private var eventAnnotationManager: PointAnnotationManager?
    private var collectionPlaceAnnotationManager: PointAnnotationManager?
    private var searchPlaceAnnotationManager: PointAnnotationManager?
    private var currentLocationAnnotationManager: PointAnnotationManager?
    
    // Store annotation IDs and associated data
    private var placeAnnotations: [String: PointAnnotation] = [:]
    private var eventAnnotations: [String: PointAnnotation] = [:]
    private var collectionPlaceAnnotations: [String: PointAnnotation] = [:]
    private var searchPlaceAnnotation: PointAnnotation?
    private var collectionPlacesData: [(place: PlaceCollection.Place, collection: PlaceCollection)] = []
    private var followUserLocation: Bool = true
    private var currentZoom: Double = Constants.defaultZoom
    
    weak var delegate: MapboxMapManagerDelegate?
    
    // MARK: - Initialization
    init(mapView: MapView) {
        self.mapView = mapView
        super.init()
        setupMapView()
        setupLocationManager()
        sessionToken = GMSAutocompleteSessionToken()
    }
    
    // MARK: - Setup
    private func setupMapView() {
        // Configure map settings
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        // Enable pitch gestures for 3D map view (users can tilt map with two-finger gestures)
        mapView.gestures.options.pitchEnabled = true
        // Zoom gestures are enabled by default in Mapbox
        
        // Set up annotation managers with unique IDs
        placeAnnotationManager = mapView.annotations.makePointAnnotationManager(id: "place-annotations")
        eventAnnotationManager = mapView.annotations.makePointAnnotationManager(id: "event-annotations")
        collectionPlaceAnnotationManager = mapView.annotations.makePointAnnotationManager(id: "collection-annotations")
        searchPlaceAnnotationManager = mapView.annotations.makePointAnnotationManager(id: "search-annotations")
        currentLocationAnnotationManager = mapView.annotations.makePointAnnotationManager(id: "current-location-annotations")
        
        // Set up annotation tap handling using gesture recognizer
        // Mapbox v11 uses gesture recognizers for annotation taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Observe camera changes for zoom updates
        mapView.mapboxMap.onEvery(event: .cameraChanged) { [weak self] _ in
            guard let self = self else { return }
            let newZoom = self.mapView.cameraState.zoom
            let zoomThreshold: Double = 12.0
            
            let wasZoomedOut = self.currentZoom < zoomThreshold
            let isZoomedOut = newZoom < zoomThreshold
            
            if wasZoomedOut != isZoomedOut && !self.collectionPlacesData.isEmpty {
                self.currentZoom = newZoom
                self.updateCollectionPlaceMarkers()
            } else {
                self.currentZoom = newZoom
            }
        }
        
        // Set up map loaded event
        mapView.mapboxMap.onNext(event: .mapLoaded) { [weak self] _ in
            // Map style loaded
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 10
    }
    
    // MARK: - Public Methods
    func moveToCurrentLocation() {
        guard let location = currentLocation else {
            locationManager.requestLocation()
            return
        }
        
        let cameraOptions = CameraOptions(
            center: location.coordinate,
            zoom: Constants.defaultZoom
        )
        mapView.camera.ease(to: cameraOptions, duration: 0.5)
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
                Logger.log("Error searching places: \(error.localizedDescription)", level: .error, category: "Map")
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
        // Remove previous search marker if exists
        if let existingAnnotation = searchPlaceAnnotation {
            searchPlaceAnnotationManager?.annotations.removeAll(where: { $0.id == existingAnnotation.id })
        }
        
        let annotation = MarkerFactory.createPlaceAnnotation(for: place)
        searchPlaceAnnotation = annotation
        searchPlaceAnnotationManager?.annotations.append(annotation)
        
        // Calculate offset to position pin above the detail sheet
        // Shift camera center south so the pin appears in upper 1/3 of screen
        let screenHeight = mapView.bounds.height
        let offsetPixels = screenHeight * 0.2  // Move center down by 20% of screen height
        
        // Convert pixel offset to latitude offset based on zoom level
        let zoom = Constants.defaultZoom
        let latRad = place.coordinate.latitude * .pi / 180.0
        let metersPerPixel = 156543.03392 * cos(latRad) / pow(2.0, zoom)
        let offsetMeters = Double(offsetPixels) * metersPerPixel
        let metersPerDegreeLat = 111000.0
        let latitudeOffset = offsetMeters / metersPerDegreeLat
        
        // Adjusted center (south of actual location so pin appears higher)
        let adjustedCenter = CLLocationCoordinate2D(
            latitude: place.coordinate.latitude - latitudeOffset,
            longitude: place.coordinate.longitude
        )
        
        // Move camera with 3D view (pitch) and offset center
        let cameraOptions = CameraOptions(
            center: adjustedCenter,
            zoom: Constants.defaultZoom,
            pitch: 50  // Enable 3D view for searched places
        )
        
        mapView.camera.fly(to: cameraOptions, duration: 1.0)
        followUserLocation = false
    }
    
    func clearSearchPlaceMarker() {
        if let annotation = searchPlaceAnnotation {
            searchPlaceAnnotationManager?.annotations.removeAll(where: { $0.id == annotation.id })
            searchPlaceAnnotation = nil
        }
    }
    
    func clearMarkers() {
        let annotationsToRemove = Array(placeAnnotations.values)
        placeAnnotations.removeAll()
        
        // Remove all annotations from manager
        placeAnnotationManager?.annotations.removeAll()
    }
    
    func clearEventMarkers() {
        let annotationsToRemove = Array(eventAnnotations.values)
        eventAnnotations.removeAll()
        eventAnnotationManager?.annotations.removeAll()
    }
    
    func clearCollectionPlaceMarkers() {
        let annotationsToRemove = Array(collectionPlaceAnnotations.values)
        collectionPlaceAnnotations.removeAll()
        collectionPlacesData.removeAll()
        collectionPlaceAnnotationManager?.annotations.removeAll()
    }
    
    private func updateCollectionPlaceMarkers() {
        // Clear existing markers
        collectionPlaceAnnotationManager?.annotations.removeAll()
        collectionPlaceAnnotations.removeAll()
        
        // Get current zoom level
        currentZoom = mapView.cameraState.zoom
        
        // Recreate markers with current zoom level using Firestore data
        var newAnnotations: [PointAnnotation] = []
        for (place, collection) in collectionPlacesData {
            let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let annotation = MarkerFactory.createCollectionPlaceAnnotation(
                coordinate: coordinate,
                title: place.name,
                snippet: place.formattedAddress,
                collection: collection,
                zoomLevel: Float(currentZoom)
            )
            let annotationId = place.placeId
            collectionPlaceAnnotations[annotationId] = annotation
            newAnnotations.append(annotation)
        }
        collectionPlaceAnnotationManager?.annotations = newAnnotations
    }
    
    func showEventsOnMap(_ events: [Event]) {
        Logger.log("showEventsOnMap with \(events.count) events", level: .debug, category: "Map")
        
        // Clear existing event markers
        clearEventMarkers()
        
        // Create and add markers for each event
        var newAnnotations: [PointAnnotation] = []
        for event in events {
            guard event.location.coordinates != nil else {
                Logger.log("Skipping event '\(event.title)' - no coordinates", level: .warn, category: "Map")
                continue
            }
            
            let annotation = MarkerFactory.createEventAnnotation(for: event)
            let annotationId = event.id
            eventAnnotations[annotationId] = annotation
            newAnnotations.append(annotation)
            Logger.log("Added event marker: \(event.title)", level: .debug, category: "Map")
        }
        
        eventAnnotationManager?.annotations = newAnnotations
        Logger.log("Total event markers on map: \(eventAnnotations.count)", level: .debug, category: "Map")
    }
    
    func resetMap() {
        clearMarkers()
        clearEventMarkers()
        clearCollectionPlaceMarkers()
        followUserLocation = true
        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(latitude: Constants.defaultLatitude, longitude: Constants.defaultLongitude),
            zoom: Constants.defaultZoom
        )
        mapView.camera.ease(to: cameraOptions, duration: 0.5)
    }
    
    func showCollectionPlacesOnMap(_ collections: [PlaceCollection]) {
        Logger.log("showCollectionPlacesOnMap with \(collections.count) collections", level: .debug, category: "Map")
        
        // Clear existing collection place markers
        clearCollectionPlaceMarkers()
        
        // Track which collection each place belongs to
        var placeToCollectionMap: [String: (place: PlaceCollection.Place, collection: PlaceCollection)] = [:]
        
        for collection in collections {
            for place in collection.places {
                if placeToCollectionMap[place.placeId] == nil {
                    placeToCollectionMap[place.placeId] = (place: place, collection: collection)
                }
            }
        }
        
        Logger.log("Found \(placeToCollectionMap.count) unique places across all collections", level: .debug, category: "Map")
        
        let placesData: [(PlaceCollection.Place, PlaceCollection)] = Array(placeToCollectionMap.values).map { ($0.place, $0.collection) }
        let validPlacesData = placesData.filter { $0.0.latitude != 0.0 || $0.0.longitude != 0.0 }
        
        self.collectionPlacesData = validPlacesData
        
        removeRedMarkersForCollectionPlaces(validPlacesData)
        self.updateCollectionPlaceMarkers()
        
        Logger.log("Total collection place markers on map: \(self.collectionPlaceAnnotations.count)", level: .debug, category: "Map")
    }
    
    private func removeRedMarkersForCollectionPlaces(_ collectionPlaces: [(place: PlaceCollection.Place, collection: PlaceCollection)]) {
        var removedCount = 0
        let tolerance: Double = 0.0001
        
        var annotationsToKeep: [String: PointAnnotation] = [:]
        for (id, annotation) in placeAnnotations {
            let markerLat = annotation.point.coordinates.latitude
            let markerLng = annotation.point.coordinates.longitude
            
            var shouldRemove = false
            for collectionPlace in collectionPlaces {
                let placeLat = collectionPlace.place.latitude
                let placeLng = collectionPlace.place.longitude
                
                if abs(placeLat - markerLat) < tolerance && abs(placeLng - markerLng) < tolerance {
                    shouldRemove = true
                    removedCount += 1
                    break
                }
            }
            
            if !shouldRemove {
                annotationsToKeep[id] = annotation
            }
        }
        
        placeAnnotations = annotationsToKeep
        placeAnnotationManager?.annotations = Array(placeAnnotations.values)
        
        if removedCount > 0 {
            Logger.log("Removed \(removedCount) red marker(s) that overlap with collection places", level: .debug, category: "Map")
        }
    }
    
    func moveToCoordinate(_ latitude: Double, _ longitude: Double, zoom: Double = Constants.defaultZoom) {
        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            zoom: zoom
        )
        mapView.camera.ease(to: cameraOptions, duration: 0.5)
        followUserLocation = false
    }
    
    private func updateCurrentLocationMarker(at location: CLLocation) {
        // Remove existing current location marker
        if let existingAnnotation = currentLocationAnnotation {
            currentLocationAnnotationManager?.annotations.removeAll(where: { $0.id == existingAnnotation.id })
        }
        
        // Create new current location annotation
        let annotation = MarkerFactory.createCurrentLocationAnnotation(at: location)
        currentLocationAnnotation = annotation
        currentLocationAnnotationManager?.annotations = [annotation]
    }
    
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.mapboxMap.coordinate(for: point)
        
        // Check if tap is near any event annotation
        for (_, annotation) in eventAnnotations {
            let annotationPoint = mapView.mapboxMap.point(for: annotation.point.coordinates)
            let distance = sqrt(pow(point.x - annotationPoint.x, 2) + pow(point.y - annotationPoint.y, 2))
            
            // If tap is within 30 points of annotation
            if distance < 30 {
                if let userInfo = annotation.userInfo,
                   let event = userInfo["event"] as? Event {
                    delegate?.mapboxMapManager(self, didTapEventMarker: event)
                    return
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension MapboxMapManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        if followUserLocation {
            moveToCurrentLocation()
        }
        
        updateCurrentLocationMarker(at: location)
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.mapboxMapManager(self, didFailWithError: error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            delegate?.mapboxMapManager(self, didFailWithError: NSError(
                domain: "MapboxMapManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access denied"]
            ))
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}
