import Foundation
import UIKit
import CoreLocation

struct Event {
    let id: String
    let title: String
    let dateTime: EventDateTime
    let location: EventLocation
    let details: String
    let images: [UIImage]
    let createdAt: Date
    let userId: String
}

struct EventDateTime {
    let startDate: Date
    let endDate: Date
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

struct EventLocation {
    let name: String
    let address: String
    let coordinates: CLLocationCoordinate2D?
}
