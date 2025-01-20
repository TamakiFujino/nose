import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class ViewController: UIViewController, UISearchBarDelegate, GMSMapViewDelegate, CLLocationManagerDelegate {
    
    var mapView: GMSMapView!
    var locationManager = CLLocationManager()
    var placesClient: GMSPlacesClient!

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

        // Add search bar
        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 50, width: view.frame.width, height: 50))
        searchBar.placeholder = "Search for a place"
        searchBar.delegate = self
        view.addSubview(searchBar)
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
                let detailVC = POIDetailViewController()
                detailVC.placeName = name
                detailVC.placeID = placeID
                detailVC.address = place.formattedAddress
                detailVC.phoneNumber = place.phoneNumber
                detailVC.website = place.website?.absoluteString
                detailVC.rating = Double(place.rating)
                detailVC.openingHours = place.openingHours?.weekdayText
                detailVC.modalPresentationStyle = .pageSheet
                if let sheet = detailVC.sheetPresentationController {
                    sheet.detents = [.medium()]
                }
                self.present(detailVC, animated: true, completion: nil)
            }
        }
    }
}
