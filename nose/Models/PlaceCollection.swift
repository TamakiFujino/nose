import Foundation
import FirebaseFirestore

public struct PlaceCollection: Codable {
    // MARK: - Constants
    public static let currentVersion: Int = 1
    
    // MARK: - Properties
    public let id: String
    public let name: String
    public var places: [Place]
    public let userId: String
    public var status: Status
    public let createdAt: Date
    public let isOwner: Bool
    public let version: Int
    public let iconName: String? // SF Symbol name or icon identifier (for backward compatibility)
    public let iconUrl: String? // URL for custom icon image (new approach)
    
    public enum Status: String, Codable {
        case active
        case completed
    }
    
    public struct Place: Codable {
        public let placeId: String
        public let name: String
        public let formattedAddress: String
        public let rating: Float
        public let phoneNumber: String
        public let addedAt: Date
        public var visited: Bool
        public let latitude: Double
        public let longitude: Double
        
        public var dictionary: [String: Any] {
            [
                "placeId": placeId,
                "name": name,
                "formattedAddress": formattedAddress,
                "rating": rating,
                "phoneNumber": phoneNumber,
                "addedAt": Timestamp(date: addedAt),
                "visited": visited,
                "latitude": latitude,
                "longitude": longitude
            ]
        }
    }
    
    public var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "places": places.map { $0.dictionary },
            "userId": userId,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "isOwner": isOwner,
            "version": version
        ]
        if let iconName = iconName {
            dict["iconName"] = iconName
        }
        if let iconUrl = iconUrl {
            dict["iconUrl"] = iconUrl
        }
        return dict
    }
    
    public init(id: String, name: String, places: [Place], userId: String, status: Status = .active, isOwner: Bool = true, version: Int = 1, iconName: String? = nil, iconUrl: String? = nil) {
        self.id = id
        self.name = name
        self.places = places
        self.userId = userId
        self.status = status
        self.createdAt = Date()
        self.isOwner = isOwner
        self.version = version
        self.iconName = iconName
        self.iconUrl = iconUrl
    }
    
    public init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let userId = dictionary["userId"] as? String else {
            Logger.log("Failed to parse basic collection data", level: .error, category: "PlaceCollection")
            return nil
        }
        
        self.id = id
        self.name = name
        self.userId = userId
        
        // Parse status, default to active if not found
        if let statusString = dictionary["status"] as? String,
           let status = Status(rawValue: statusString) {
            self.status = status
        } else {
            self.status = .active
        }
        
        // Parse createdAt, default to current date if not found
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        // Parse isOwner, default to true if not found
        if let isOwner = dictionary["isOwner"] as? Bool {
            self.isOwner = isOwner
        } else {
            self.isOwner = true
        }
        
        // Parse version, default to 1 if not found
        if let version = dictionary["version"] as? Int {
            self.version = version
        } else {
            self.version = 1
        }
        
        // Parse iconName, optional (for backward compatibility)
        self.iconName = dictionary["iconName"] as? String
        
        // Parse iconUrl, optional (new approach for custom images)
        self.iconUrl = dictionary["iconUrl"] as? String
        
        if let placesData = dictionary["places"] as? [[String: Any]] {
            Logger.log("Parsing \(placesData.count) places", level: .debug, category: "PlaceCollection")
            self.places = placesData.compactMap { placeDict in
                guard let placeId = placeDict["placeId"] as? String,
                      let name = placeDict["name"] as? String,
                      let formattedAddress = placeDict["formattedAddress"] as? String,
                      let phoneNumber = placeDict["phoneNumber"] as? String else {
                    Logger.log("Failed to parse place basic data", level: .error, category: "PlaceCollection")
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
                    Logger.log("Failed to parse rating", level: .error, category: "PlaceCollection")
                    return nil
                }
                
                // Handle timestamp
                let addedAt: Date
                if let timestamp = placeDict["addedAt"] as? Timestamp {
                    addedAt = timestamp.dateValue()
                } else {
                    Logger.log("Failed to parse timestamp", level: .error, category: "PlaceCollection")
                    return nil
                }
                
                // Handle visited status, default to false if not found
                let visited = placeDict["visited"] as? Bool ?? false
                
                // Handle coordinates - required for map display
                let latitude: Double
                let longitude: Double
                if let lat = placeDict["latitude"] as? Double,
                   let lng = placeDict["longitude"] as? Double {
                    latitude = lat
                    longitude = lng
                } else {
                    Logger.log("Place missing coordinates, using default (0,0)", level: .warn, category: "PlaceCollection")
                    latitude = 0.0
                    longitude = 0.0
                }
                
                return Place(placeId: placeId,
                           name: name,
                           formattedAddress: formattedAddress,
                           rating: rating,
                           phoneNumber: phoneNumber,
                           addedAt: addedAt,
                           visited: visited,
                           latitude: latitude,
                           longitude: longitude)
            }
            Logger.log("Successfully parsed \(self.places.count) places", level: .info, category: "PlaceCollection")
        } else {
            Logger.log("No places data found or invalid format", level: .error, category: "PlaceCollection")
            self.places = []
        }
    }
    
    public func migrate() -> PlaceCollection {
        // For now, just return self since we're at version 1
        // In the future, this method will handle migrations between versions
        return self
    }
} 
