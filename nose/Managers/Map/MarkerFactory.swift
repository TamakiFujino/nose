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
    
    static func createCollectionPlaceMarker(for place: GMSPlace, collection: PlaceCollection, zoomLevel: Float? = nil) -> GMSMarker {
        let marker = GMSMarker(position: place.coordinate)
        let isZoomedOut = zoomLevel != nil && zoomLevel! < 12 // Smaller when zoomed out below level 12
        marker.iconView = createCollectionPlaceMarkerView(iconName: collection.iconName, iconUrl: collection.iconUrl, isSmall: isZoomedOut)
        marker.title = place.name
        marker.snippet = place.formattedAddress
        marker.userData = collection // Store collection data for later retrieval
        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5) // Anchor at center
        return marker
    }
    
    // Overload: Create marker from Firestore data (no API call needed)
    static func createCollectionPlaceMarker(coordinate: CLLocationCoordinate2D, title: String, snippet: String, collection: PlaceCollection, zoomLevel: Float? = nil) -> GMSMarker {
        let marker = GMSMarker(position: coordinate)
        let isZoomedOut = zoomLevel != nil && zoomLevel! < 12 // Smaller when zoomed out below level 12
        marker.iconView = createCollectionPlaceMarkerView(iconName: collection.iconName, iconUrl: collection.iconUrl, isSmall: isZoomedOut)
        marker.title = title
        marker.snippet = snippet
        marker.userData = collection // Store collection data for later retrieval
        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5) // Anchor at center
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
        backgroundCircle.layer.borderColor = UIColor.firstColor.cgColor
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
        iconImageView.tintColor = .firstColor
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
    
    private static func createCollectionPlaceMarkerView(iconName: String?, iconUrl: String?, isSmall: Bool = false) -> UIView {
        let size: CGFloat = isSmall ? 28 : 40 // Smaller when zoomed out
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        markerView.backgroundColor = .clear
        
        // Background circle - now always pure white
        let backgroundCircle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundCircle.backgroundColor = UIColor.white
        backgroundCircle.layer.cornerRadius = size / 2
        backgroundCircle.layer.masksToBounds = true
        
        // Add white border
        backgroundCircle.layer.borderWidth = 1.5
        backgroundCircle.layer.borderColor = UIColor.white.cgColor
        
        markerView.addSubview(backgroundCircle)
        
        // Priority: iconUrl > iconName
        if let iconUrl = iconUrl, !iconUrl.isEmpty {
            // Load custom image from URL, use tighter padding so icon fills the pin
            let iconSize: CGFloat = size * (isSmall ? 0.55 : 0.7)
            let iconImageView = UIImageView(frame: CGRect(
                x: (size - iconSize) / 2,
                y: (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            ))
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.clipsToBounds = false
            iconImageView.layer.cornerRadius = 0
            iconImageView.layer.masksToBounds = false
            markerView.addSubview(iconImageView)
            
            // Load image asynchronously
            loadMarkerIconImage(urlString: iconUrl, imageView: iconImageView)
        } else if let iconName = iconName, let iconImage = UIImage(systemName: iconName) {
            // Use SF Symbol
            let iconSize: CGFloat = size * (isSmall ? 0.55 : 0.7)
            let iconImageView = UIImageView(frame: CGRect(
                x: (size - iconSize) / 2,
                y: (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            ))
            iconImageView.image = iconImage
            iconImageView.tintColor = .systemGray // Darker color since background is light gray
            iconImageView.contentMode = .scaleAspectFit
            markerView.addSubview(iconImageView)
        }
        
        return markerView
    }
    
    private static func loadMarkerIconImage(urlString: String, imageView: UIImageView) {
        guard let url = URL(string: urlString) else { return }
        
        // Check cache first
        if let cachedImage = MarkerFactory.markerImageCache.object(forKey: urlString as NSString) {
            imageView.image = cachedImage
            imageView.tintColor = nil
            return
        }
        
        // Download image
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let image = UIImage(data: data) else {
                return
            }
            
            // Cache the image
            MarkerFactory.markerImageCache.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                imageView.image = image
                imageView.tintColor = nil
            }
        }.resume()
    }
    
    private static let markerImageCache = NSCache<NSString, UIImage>()
} 