import Foundation
import GooglePlaces

class PlacesAPIManager {
    static let shared = PlacesAPIManager()
    
    // MARK: - Configuration
    struct Config {
        static let searchDebounceDelay: TimeInterval = 0.5  // 500ms delay
        static let maxDailyRequests = 1000
        static let maxRequestsPerMinute = 60  // Increased to 60 requests per minute for better UX
        static let burstAllowance = 10  // Allow burst of 10 requests for user interactions
    }
    
    // MARK: - Optimized Field Configurations
    struct FieldConfig {
        // Minimal fields for basic place info (search results, list items)
        static let basic: GMSPlaceField = [
            .name,
            .placeID,
            .coordinate,
            .formattedAddress,
            .rating
        ]
        
        // Fields for place detail view (full details)
        static let detail: GMSPlaceField = [
            .name,
            .placeID,
            .coordinate,
            .formattedAddress,
            .phoneNumber,
            .rating,
            .openingHours,
            .photos
        ]
        
        // Fields for map display (location + basic info)
        static let map: GMSPlaceField = [
            .name,
            .placeID,
            .coordinate,
            .formattedAddress,
            .rating,
            .openingHours,
            .photos
        ]
        
        // Fields for collection items (basic + photos)
        static let collection: GMSPlaceField = [
            .name,
            .placeID,
            .coordinate,
            .formattedAddress,
            .phoneNumber,
            .rating,
            .openingHours,
            .photos
        ]
        
        // Fields for photo loading only
        static let photosOnly: GMSPlaceField = [
            .photos
        ]
        
        // Fields for search results (comprehensive but optimized)
        static let search: GMSPlaceField = [
            .name,
            .placeID,
            .coordinate,
            .formattedAddress,
            .phoneNumber,
            .rating,
            .openingHours,
            .photos,
            .website,
            .priceLevel,
            .userRatingsTotal,
            .types
        ]
    }
    
    // MARK: - Properties
    private var searchTimer: Timer?
    private var dailyRequestCount = 0
    private var lastRequestTime: Date?
    private var recentRequestTimes: [Date] = []
    private let requestQueue = DispatchQueue(label: "places.api.queue")
    private let dateFormatter = DateFormatter()
    
    private init() {
        dateFormatter.dateFormat = "yyyy-MM-dd"
        resetDailyCountIfNeeded()
    }
    
    // MARK: - Request Tracking
    private func resetDailyCountIfNeeded() {
        let today = dateFormatter.string(from: Date())
        let lastResetDate = UserDefaults.standard.string(forKey: "lastAPICountReset") ?? ""
        
        if today != lastResetDate {
            dailyRequestCount = 0
            UserDefaults.standard.set(today, forKey: "lastAPICountReset")
            UserDefaults.standard.set(dailyRequestCount, forKey: "dailyAPICount")
        } else {
            dailyRequestCount = UserDefaults.standard.integer(forKey: "dailyAPICount")
        }
    }
    
    private func incrementRequestCount() {
        dailyRequestCount += 1
        UserDefaults.standard.set(dailyRequestCount, forKey: "dailyAPICount")
        lastRequestTime = Date()
        recentRequestTimes.append(Date())
    }
    
    private func canMakeRequest() -> Bool {
        // Check daily limit
        if dailyRequestCount >= Config.maxDailyRequests {
            print("⚠️ Daily API request limit reached (\(Config.maxDailyRequests))")
            return false
        }
        
        // Clean up old request times (older than 1 minute)
        let oneMinuteAgo = Date().timeIntervalSince1970 - 60
        recentRequestTimes = recentRequestTimes.filter { $0.timeIntervalSince1970 > oneMinuteAgo }
        
        // Check rate limiting with sliding window
        if recentRequestTimes.count >= Config.maxRequestsPerMinute {
            print("⚠️ Rate limit exceeded (\(recentRequestTimes.count) requests in last minute)")
            return false
        }
        
        return true
    }
    
    // MARK: - Debounced Search
    func debouncedSearch(query: String, completion: @escaping ([GMSAutocompletePrediction]) -> Void) {
        // Cancel any existing timer
        searchTimer?.invalidate()
        
        // Check if we can make a request
        guard canMakeRequest() else {
            completion([])
            return
        }
        
        // Create a new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: Config.searchDebounceDelay, repeats: false) { [weak self] _ in
            self?.performSearch(query: query, completion: completion)
        }
    }
    
    private func performSearch(query: String, completion: @escaping ([GMSAutocompletePrediction]) -> Void) {
        // Double-check rate limiting before making the actual request
        guard canMakeRequest() else {
            completion([])
            return
        }
        
        print("🔍 Performing search for: '\(query)' (Request #\(dailyRequestCount + 1))")
        
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: nil
        ) { [weak self] results, error in
            if let error = error {
                print("❌ Search error: \(error.localizedDescription)")
                completion([])
                return
            }
            
            // Increment request count on successful request
            self?.incrementRequestCount()
            
            guard let results = results else {
                completion([])
                return
            }
            
            print("✅ Search completed: \(results.count) results found")
            completion(results)
        }
    }
    
    // MARK: - Optimized Place Details Fetching
    func fetchPlaceDetails(placeID: String, fields: GMSPlaceField, completion: @escaping (GMSPlace?) -> Void) {
        // Check cache first
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: placeID) {
            print("📋 Using cached place details for: \(placeID)")
            completion(cachedPlace)
            return
        }
        
        // Check rate limiting
        guard canMakeRequest() else {
            print("⚠️ Cannot fetch place details due to rate limiting")
            completion(nil)
            return
        }
        
        print("🔍 Fetching place details for: \(placeID) (Request #\(dailyRequestCount + 1))")
        print("🔍 Requested fields: \(fields)")
        
        let placesClient = GMSPlacesClient.shared()
        placesClient.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { [weak self] place, error in
            if let error = error {
                print("❌ Place details error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // Increment request count on successful request
            self?.incrementRequestCount()
            
            if let place = place {
                // Cache the place
                PlacesCacheManager.shared.cachePlace(place)
                print("✅ Place details fetched and cached")
            }
            
            completion(place)
        }
    }
    
    // MARK: - Convenience Methods for Different Use Cases
    func fetchBasicPlaceDetails(placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        fetchPlaceDetails(placeID: placeID, fields: FieldConfig.basic, completion: completion)
    }
    
    func fetchDetailPlaceDetails(placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        fetchPlaceDetails(placeID: placeID, fields: FieldConfig.detail, completion: completion)
    }
    
    func fetchMapPlaceDetails(placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        fetchPlaceDetails(placeID: placeID, fields: FieldConfig.map, completion: completion)
    }
    
    func fetchCollectionPlaceDetails(placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        fetchPlaceDetails(placeID: placeID, fields: FieldConfig.collection, completion: completion)
    }
    
    func fetchPhotosOnly(placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        fetchPlaceDetails(placeID: placeID, fields: FieldConfig.photosOnly, completion: completion)
    }
    
    func fetchSearchPlaceDetails(placeID: String, completion: @escaping (GMSPlace?) -> Void) {
        fetchPlaceDetails(placeID: placeID, fields: FieldConfig.search, completion: completion)
    }
    
    // MARK: - User Interaction Priority Methods
    func fetchPlaceDetailsForUserInteraction(placeID: String, fields: GMSPlaceField, completion: @escaping (GMSPlace?) -> Void) {
        // For user interactions, we're more lenient with rate limiting
        // Check cache first
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: placeID) {
            print("📋 Using cached place details for user interaction: \(placeID)")
            completion(cachedPlace)
            return
        }
        
        // Check daily limit only (more lenient for user interactions)
        if dailyRequestCount >= Config.maxDailyRequests {
            print("⚠️ Daily API request limit reached (\(Config.maxDailyRequests))")
            completion(nil)
            return
        }
        
        // For user interactions, allow more requests per minute
        let userInteractionLimit = Config.maxRequestsPerMinute * 2 // Double the limit for user interactions
        
        // Clean up old request times (older than 1 minute)
        let oneMinuteAgo = Date().timeIntervalSince1970 - 60
        recentRequestTimes = recentRequestTimes.filter { $0.timeIntervalSince1970 > oneMinuteAgo }
        
        // Check rate limiting with higher limit for user interactions
        if recentRequestTimes.count >= userInteractionLimit {
            print("⚠️ Rate limit exceeded for user interaction (\(recentRequestTimes.count) requests in last minute)")
            completion(nil)
            return
        }
        
        print("🔍 Fetching place details for user interaction: \(placeID) (Request #\(dailyRequestCount + 1))")
        print("🔍 Requested fields: \(fields)")
        
        let placesClient = GMSPlacesClient.shared()
        placesClient.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { [weak self] place, error in
            if let error = error {
                print("❌ Place details error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // Increment request count on successful request
            self?.incrementRequestCount()
            
            if let place = place {
                // Cache the place
                PlacesCacheManager.shared.cachePlace(place)
                print("✅ Place details fetched and cached for user interaction")
            }
            
            completion(place)
        }
    }
    
    // MARK: - Photo Loading with Optimization
    func loadPlacePhoto(photo: GMSPlacePhotoMetadata, placeID: String, photoIndex: Int, completion: @escaping (UIImage?) -> Void) {
        let photoID = "\(placeID)_\(photoIndex)"
        
        print("🖼️ Starting photo load for: \(photoID)")
        
        // Check cache first
        if let cachedImage = PlacesCacheManager.shared.getCachedPhoto(for: photoID) {
            print("📋 Using cached photo for: \(photoID)")
            completion(cachedImage)
            return
        }
        
        // Check rate limiting
        guard canMakeRequest() else {
            print("⚠️ Cannot load photo due to rate limiting")
            completion(nil)
            return
        }
        
        print("🖼️ Loading photo for: \(photoID) (Request #\(dailyRequestCount + 1))")
        
        let placesClient = GMSPlacesClient.shared()
        placesClient.loadPlacePhoto(photo) { [weak self] image, error in
            if let error = error {
                print("❌ Photo loading error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                completion(nil)
                return
            }
            
            // Increment request count on successful request
            self?.incrementRequestCount()
            
            if let image = image {
                // Cache the photo
                PlacesCacheManager.shared.cachePhoto(image, for: photoID)
                print("✅ Photo loaded and cached for: \(photoID)")
                print("✅ Image size: \(image.size)")
            } else {
                print("❌ No image returned for: \(photoID)")
            }
            
            completion(image)
        }
    }
    
    // MARK: - Usage Statistics
    func getUsageStatistics() -> (daily: Int, remaining: Int, resetDate: String) {
        resetDailyCountIfNeeded()
        let remaining = max(0, Config.maxDailyRequests - dailyRequestCount)
        let resetDate = UserDefaults.standard.string(forKey: "lastAPICountReset") ?? "Unknown"
        return (daily: dailyRequestCount, remaining: remaining, resetDate: resetDate)
    }
    
    func resetUsageStatistics() {
        dailyRequestCount = 0
        UserDefaults.standard.set(dailyRequestCount, forKey: "dailyAPICount")
        UserDefaults.standard.set(dateFormatter.string(from: Date()), forKey: "lastAPICountReset")
        print("🔄 API usage statistics reset")
    }
    
    // MARK: - Cleanup
    func cleanup() {
        searchTimer?.invalidate()
        searchTimer = nil
    }
} 