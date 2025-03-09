import Foundation

// This struct represents a bookmarked point of interest (POI)
struct BookmarkedPOI: Codable {
    var placeID: String
    var name: String
    var address: String?
    var phoneNumber: String?
    var website: String?
    var rating: Double?
    var openingHours: [String]?
    var latitude: Double
    var longitude: Double
    var visited: Bool = false // New property to track if the POI is visited
}
