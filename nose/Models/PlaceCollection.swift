import Foundation
import FirebaseFirestore

public struct PlaceCollection: Codable {
    public let id: String
    public let name: String
    public var places: [Place]
    public let userId: String
    
    public struct Place: Codable {
        public let placeId: String
        public let name: String
        public let formattedAddress: String
        public let rating: Float
        public let phoneNumber: String
        public let addedAt: Date
        
        public var dictionary: [String: Any] {
            [
                "placeId": placeId,
                "name": name,
                "formattedAddress": formattedAddress,
                "rating": rating,
                "phoneNumber": phoneNumber,
                "addedAt": Timestamp(date: addedAt)
            ]
        }
    }
    
    public var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "places": places.map { $0.dictionary },
            "userId": userId
        ]
    }
    
    public init(id: String, name: String, places: [Place], userId: String) {
        self.id = id
        self.name = name
        self.places = places
        self.userId = userId
    }
    
    public init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let userId = dictionary["userId"] as? String else {
            print("❌ Failed to parse basic collection data")
            return nil
        }
        
        self.id = id
        self.name = name
        self.userId = userId
        
        if let placesData = dictionary["places"] as? [[String: Any]] {
            print("📦 Parsing \(placesData.count) places")
            self.places = placesData.compactMap { placeDict in
                guard let placeId = placeDict["placeId"] as? String,
                      let name = placeDict["name"] as? String,
                      let formattedAddress = placeDict["formattedAddress"] as? String,
                      let phoneNumber = placeDict["phoneNumber"] as? String else {
                    print("❌ Failed to parse place basic data")
                    return nil
                }
                
                // Handle rating which could be String or Float
                let rating: Float
                if let ratingFloat = placeDict["rating"] as? Float {
                    rating = ratingFloat
                } else if let ratingString = placeDict["rating"] as? String,
                          let ratingFloat = Float(ratingString) {
                    rating = ratingFloat
                } else {
                    print("❌ Failed to parse rating")
                    return nil
                }
                
                // Handle timestamp
                let addedAt: Date
                if let timestamp = placeDict["addedAt"] as? Timestamp {
                    addedAt = timestamp.dateValue()
                } else {
                    print("❌ Failed to parse timestamp")
                    return nil
                }
                
                return Place(placeId: placeId,
                           name: name,
                           formattedAddress: formattedAddress,
                           rating: rating,
                           phoneNumber: phoneNumber,
                           addedAt: addedAt)
            }
            print("✅ Successfully parsed \(self.places.count) places")
        } else {
            print("❌ No places data found or invalid format")
            self.places = []
        }
    }
} 