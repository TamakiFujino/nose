import Foundation
import FirebaseFirestore

extension PlaceCollection.Place {
    func toFirestoreData() -> [String: Any] {
        return [
            "placeId": placeId,
            "name": name,
            "formattedAddress": formattedAddress,
            "rating": rating,
            "phoneNumber": phoneNumber,
            "addedAt": Timestamp(date: addedAt)
        ]
    }
} 