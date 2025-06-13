import UIKit
import GooglePlaces

protocol SearchManagerDelegate: AnyObject {
    func searchManager(_ manager: SearchManager, didUpdateResults results: [GMSPlace])
    func searchManager(_ manager: SearchManager, didSelectPlace place: GMSPlace)
}

final class SearchManager: NSObject {
    // MARK: - Properties
    private var searchResults: [GMSPlace] = []
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
                
                placesClient.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: self.sessionToken) { [weak self] place, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error fetching place details: \(error.localizedDescription)")
                        return
                    }
                    
                    if let place = place {
                        DispatchQueue.main.async {
                            self.searchResults.append(place)
                            self.delegate?.searchManager(self, didUpdateResults: self.searchResults)
                        }
                    }
                }
            }
        }
    }
    
    func selectPlace(_ place: GMSPlace) {
        delegate?.searchManager(self, didSelectPlace: place)
    }
    
    func clearResults() {
        searchResults = []
        delegate?.searchManager(self, didUpdateResults: searchResults)
    }
} 