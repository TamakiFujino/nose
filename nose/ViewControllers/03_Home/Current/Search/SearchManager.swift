import UIKit
import GooglePlaces

protocol SearchManagerDelegate: AnyObject {
    func searchManager(_ manager: SearchManager, didUpdateResults results: [GMSAutocompletePrediction])
    func searchManager(_ manager: SearchManager, didSelectPlace place: GMSPlace)
}

final class SearchManager: NSObject {
    // MARK: - Properties
    private var searchResults: [GMSAutocompletePrediction] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    weak var delegate: SearchManagerDelegate?
    
    // MARK: - Initialization
    override init() {
        super.init()
        sessionToken = GMSAutocompleteSessionToken()
    }
    
    // MARK: - Public Methods
    func searchPlaces(query: String) {
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
                Logger.log("Error searching places: \(error.localizedDescription)", level: .error, category: "Search")
                return
            }
            
            guard let results = results else { return }
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.delegate?.searchManager(self, didUpdateResults: results)
            }
        }
    }
    
    func selectPlace(_ prediction: GMSAutocompletePrediction) {
        // Use user interaction priority for search selection
        PlacesAPIManager.shared.fetchPlaceDetailsForUserInteraction(
            placeID: prediction.placeID,
            fields: PlacesAPIManager.FieldConfig.search
        ) { [weak self] place in
            guard let self = self else { return }
            
            if let place = place {
                DispatchQueue.main.async {
                    self.delegate?.searchManager(self, didSelectPlace: place)
                }
            } else {
                Logger.log("Failed to fetch place details for: \(prediction.placeID)", level: .warn, category: "Search")
            }
        }
    }
    
    func clearResults() {
        searchResults = []
        delegate?.searchManager(self, didUpdateResults: searchResults)
    }
} 