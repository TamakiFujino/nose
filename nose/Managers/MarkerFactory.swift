import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces

final class MarkerFactory {
    // MARK: - Constants
    private enum Constants {
        static let markerSize: CGFloat = 40
        static let innerCircleSize: CGFloat = 20
        static let innerCircleOffset: CGFloat = 10
    }
    
    // MARK: - Public Methods
    static func createCurrentLocationMarker(at location: CLLocation) -> GMSMarker {
        let marker = GMSMarker(position: location.coordinate)
        marker.iconView = createCurrentLocationMarkerView()
        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        return marker
    }
    
    static func createPlaceMarker(for place: GMSPlace) -> GMSMarker {
        let marker = GMSMarker(position: place.coordinate)
        marker.title = place.name
        marker.snippet = place.formattedAddress
        return marker
    }
    
    static func createEventMarker(for event: Event) -> GMSMarker {
        guard let coordinates = event.location.coordinates else {
            // Fallback to default coordinates if event has no location
            let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: 0, longitude: 0))
            return marker
        }
        
        let marker = GMSMarker(position: coordinates)
        marker.iconView = createEventMarkerView()
        marker.title = event.title
        marker.snippet = event.location.name
        marker.userData = event // Store event data for later retrieval
        marker.groundAnchor = CGPoint(x: 0.5, y: 1.0) // Anchor at bottom center
        return marker
    }
    
    // MARK: - Private Methods
    private static func createEventMarkerView() -> UIView {
        let size: CGFloat = 40
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        markerView.backgroundColor = .clear
        
        // Background circle
        let backgroundCircle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundCircle.backgroundColor = .fifthColor
        backgroundCircle.layer.cornerRadius = size / 2
        backgroundCircle.layer.masksToBounds = true
        backgroundCircle.layer.borderWidth = 3
        backgroundCircle.layer.borderColor = UIColor.white.cgColor
        markerView.addSubview(backgroundCircle)
        
        // Bolt icon
        let iconSize: CGFloat = 20
        let iconImageView = UIImageView(frame: CGRect(
            x: (size - iconSize) / 2,
            y: (size - iconSize) / 2,
            width: iconSize,
            height: iconSize
        ))
        iconImageView.image = UIImage(systemName: "bolt.fill")
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        markerView.addSubview(iconImageView)
        
        return markerView
    }
    private static func createCurrentLocationMarkerView() -> UIView {
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: Constants.markerSize, height: Constants.markerSize))
        markerView.backgroundColor = .clear
        
        // Outer circle
        let outerCircle = UIView(frame: CGRect(x: 0, y: 0, width: Constants.markerSize, height: Constants.markerSize))
        outerCircle.backgroundColor = UIColor.sixthColor.withAlphaComponent(0.3)
        outerCircle.layer.cornerRadius = Constants.markerSize / 2
        outerCircle.layer.masksToBounds = true
        markerView.addSubview(outerCircle)
        
        // Inner circle
        let innerCircle = UIView(frame: CGRect(
            x: Constants.innerCircleOffset,
            y: Constants.innerCircleOffset,
            width: Constants.innerCircleSize,
            height: Constants.innerCircleSize
        ))
        innerCircle.backgroundColor = UIColor.firstColor
        innerCircle.layer.cornerRadius = Constants.innerCircleSize / 2
        innerCircle.layer.masksToBounds = true
        markerView.addSubview(innerCircle)
        
        return markerView
    }
} 