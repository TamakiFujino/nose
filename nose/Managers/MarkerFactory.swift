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
    
    // MARK: - Private Methods
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