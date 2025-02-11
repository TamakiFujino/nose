// This struct represents a bookmarked point of interest (POI)
struct BookmarkedPOI {
    var placeID: String
    var name: String
    var address: String?
    var phoneNumber: String?
    var website: String?
    var rating: Double?
    var openingHours: [String]?
    // longitude and latitude properties
    var latitude: Double
    var longitude: Double
}
