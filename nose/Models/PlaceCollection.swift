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
            "userId": userId,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "isOwner": isOwner,
            "version": version
        ]
    }
    
    public init(id: String, name: String, places: [Place], userId: String, status: Status = .active, isOwner: Bool = true, version: Int = 1) {
        self.id = id
        self.name = name
        self.places = places
        self.userId = userId
        self.status = status
        self.createdAt = Date()
        self.isOwner = isOwner
        self.version = version
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
    
    public func migrate() -> PlaceCollection {
        // For now, just return self since we're at version 1
        // In the future, this method will handle migrations between versions
        return self
    }
} 