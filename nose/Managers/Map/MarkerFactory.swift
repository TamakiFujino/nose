import UIKit
import MapboxMaps
import CoreLocation
import GooglePlaces

final class MarkerFactory {
    // MARK: - Constants
    private enum Constants {
        static let markerSize: CGFloat = 40
        static let innerCircleSize: CGFloat = 20
        static let innerCircleOffset: CGFloat = 10
    }
    
    // MARK: - Private Methods (View Creation - used by Mapbox annotations)
    private static func createGlassmorphismMarkerView() -> UIView {
        // Original SVG is 16x20, scale up for visibility
        let scale: CGFloat = 2.5
        let width: CGFloat = 16 * scale
        let height: CGFloat = 20 * scale
        
        // Add padding for shadow
        let shadowPadding: CGFloat = 12
        let containerWidth = width + shadowPadding * 2
        let containerHeight = height + shadowPadding * 2
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = false
        
        // Create a sublayer view offset by the padding
        let pinView = UIView(frame: CGRect(x: shadowPadding, y: shadowPadding, width: width, height: height))
        pinView.backgroundColor = .clear
        pinView.clipsToBounds = false
        
        // Create paths
        let outerPinPath = createOuterPinPath(scale: scale)
        let innerCirclePath = createInnerCirclePath(scale: scale)
        
        // Combined path with hole (for fill)
        let combinedPath = UIBezierPath()
        combinedPath.append(outerPinPath)
        combinedPath.append(innerCirclePath.reversing()) // Reverse for even-odd hole
        
        // Create layered shadows like collection markers (no blur, solid colors, centered)
        
        // Outer shadow (larger, more transparent) - centered
        let outerShadowScale = scale + 0.6
        let outerShadowPath = createOuterPinPath(scale: outerShadowScale)
        let outerShadowWidth = 16 * outerShadowScale
        let outerShadowHeight = 20 * outerShadowScale
        let outerShadowX = (width - outerShadowWidth) / 2
        let outerShadowY = (height - outerShadowHeight) / 2
        
        let outerShadowLayer = CAShapeLayer()
        outerShadowLayer.path = outerShadowPath.cgPath
        outerShadowLayer.fillColor = UIColor.black.withAlphaComponent(0.08).cgColor
        outerShadowLayer.frame = CGRect(x: outerShadowX, y: outerShadowY, width: outerShadowWidth, height: outerShadowHeight)
        pinView.layer.insertSublayer(outerShadowLayer, at: 0)
        
        // Inner shadow (smaller, less transparent) - centered
        let innerShadowScale = scale + 0.3
        let innerShadowPath = createOuterPinPath(scale: innerShadowScale)
        let innerShadowWidth = 16 * innerShadowScale
        let innerShadowHeight = 20 * innerShadowScale
        let innerShadowX = (width - innerShadowWidth) / 2
        let innerShadowY = (height - innerShadowHeight) / 2
        
        let innerShadowLayer = CAShapeLayer()
        innerShadowLayer.path = innerShadowPath.cgPath
        innerShadowLayer.fillColor = UIColor.black.withAlphaComponent(0.12).cgColor
        innerShadowLayer.frame = CGRect(x: innerShadowX, y: innerShadowY, width: innerShadowWidth, height: innerShadowHeight)
        pinView.layer.insertSublayer(innerShadowLayer, at: 1)
        
        // Solid white fill (with hole)
        let fillLayer = CAShapeLayer()
        fillLayer.path = combinedPath.cgPath
        fillLayer.fillRule = .evenOdd
        fillLayer.fillColor = UIColor.white.cgColor
        pinView.layer.addSublayer(fillLayer)
        
        containerView.addSubview(pinView)
        
        return containerView
    }
    
    // Creates outer pin path from pin.svg
    private static func createOuterPinPath(scale: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        
        // Pin shape from SVG
        path.move(to: CGPoint(x: 8 * scale, y: 0))
        
        path.addCurve(
            to: CGPoint(x: 2.37124 * scale, y: 2.31479 * scale),
            controlPoint1: CGPoint(x: 5.89206 * scale, y: 0),
            controlPoint2: CGPoint(x: 3.86926 * scale, y: 0.831759 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 0, y: 7.92 * scale),
            controlPoint1: CGPoint(x: 0.873231 * scale, y: 3.79782 * scale),
            controlPoint2: CGPoint(x: 0.0210794 * scale, y: 5.81216 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 7.35 * scale, y: 19.76 * scale),
            controlPoint1: CGPoint(x: 0, y: 13.4 * scale),
            controlPoint2: CGPoint(x: 7.05 * scale, y: 19.5 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 8 * scale, y: 20 * scale),
            controlPoint1: CGPoint(x: 7.53113 * scale, y: 19.9149 * scale),
            controlPoint2: CGPoint(x: 7.76165 * scale, y: 20 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 8.65 * scale, y: 19.76 * scale),
            controlPoint1: CGPoint(x: 8.23835 * scale, y: 20 * scale),
            controlPoint2: CGPoint(x: 8.46887 * scale, y: 19.9149 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 16 * scale, y: 7.92 * scale),
            controlPoint1: CGPoint(x: 9 * scale, y: 19.5 * scale),
            controlPoint2: CGPoint(x: 16 * scale, y: 13.4 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 13.6288 * scale, y: 2.31479 * scale),
            controlPoint1: CGPoint(x: 15.9789 * scale, y: 5.81216 * scale),
            controlPoint2: CGPoint(x: 15.1268 * scale, y: 3.79782 * scale)
        )
        
        path.addCurve(
            to: CGPoint(x: 8 * scale, y: 0),
            controlPoint1: CGPoint(x: 12.1307 * scale, y: 0.831759 * scale),
            controlPoint2: CGPoint(x: 10.1079 * scale, y: 0)
        )
        
        path.close()
        return path
    }
    
    // Creates inner circle path (the hole) from pin.svg
    private static func createInnerCirclePath(scale: CGFloat) -> UIBezierPath {
        // The inner circle is centered at (8, 7.5) with radius 3.5 based on SVG
        let centerX = 8 * scale
        let centerY = 7.5 * scale
        let radius = 3.5 * scale
        
        return UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY), 
                           radius: radius, 
                           startAngle: 0, 
                           endAngle: .pi * 2, 
                           clockwise: true)
    }
    
    private static func createEventMarkerView() -> UIView {
        let size: CGFloat = 40
        let shadowRadius: CGFloat = 3
        
        // Create container with extra space for shadow (centered, so need padding on all sides)
        // Need enough padding to contain the full shadow which extends shadowRadius * 4 beyond the circle
        let shadowPadding: CGFloat = shadowRadius * 3 // Extra padding to prevent clipping
        let totalSize = size + shadowPadding * 2
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: totalSize, height: totalSize))
        markerView.backgroundColor = .clear
        
        // Create circular shadow using multiple layers for soft blur effect
        let shadowSize = size + shadowRadius * 4
        let shadowCenter = totalSize / 2 // Center of the container
        
        // Outer shadow (larger, more transparent) - centered
        let outerShadow = UIView(frame: CGRect(
            x: shadowCenter - shadowSize / 2,
            y: shadowCenter - shadowSize / 2,
            width: shadowSize,
            height: shadowSize
        ))
        outerShadow.backgroundColor = UIColor.black.withAlphaComponent(0.08) // Lighter
        outerShadow.layer.cornerRadius = shadowSize / 2
        outerShadow.layer.masksToBounds = true
        markerView.insertSubview(outerShadow, at: 0)
        
        // Inner shadow (smaller, less transparent) for depth - centered
        let innerShadowSize = size + shadowRadius * 2
        let innerShadow = UIView(frame: CGRect(
            x: shadowCenter - innerShadowSize / 2,
            y: shadowCenter - innerShadowSize / 2,
            width: innerShadowSize,
            height: innerShadowSize
        ))
        innerShadow.backgroundColor = UIColor.black.withAlphaComponent(0.12) // Lighter
        innerShadow.layer.cornerRadius = innerShadowSize / 2
        innerShadow.layer.masksToBounds = true
        markerView.insertSubview(innerShadow, at: 1)
        
        // Background circle (centered)
        let circleRect = CGRect(x: shadowPadding, y: shadowPadding, width: size, height: size)
        let backgroundCircle = UIView(frame: circleRect)
        backgroundCircle.backgroundColor = .fourthColor
        backgroundCircle.layer.cornerRadius = size / 2
        backgroundCircle.layer.masksToBounds = true
        backgroundCircle.layer.borderWidth = 3
        backgroundCircle.layer.borderColor = UIColor.firstColor.cgColor
        
        markerView.addSubview(backgroundCircle)
        
        // Bolt icon
        let iconSize: CGFloat = 20
        let iconImageView = UIImageView(frame: CGRect(
            x: shadowPadding + (size - iconSize) / 2,
            y: shadowPadding + (size - iconSize) / 2,
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
        outerCircle.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
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
        let shadowRadius: CGFloat = isSmall ? 2 : 3
        
        // Create container with extra space for shadow (centered, so need padding on all sides)
        // Need enough padding to contain the full shadow which extends shadowRadius * 4 beyond the circle
        let shadowPadding: CGFloat = shadowRadius * 3 // Extra padding to prevent clipping
        let totalSize = size + shadowPadding * 2
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: totalSize, height: totalSize))
        markerView.backgroundColor = .clear
        
        // Check if icon is set
        let hasIcon = (iconUrl != nil && !iconUrl!.isEmpty) || (iconName != nil && UIImage(systemName: iconName!) != nil)
        
        // Create circular shadow using multiple layers for soft blur effect
        let shadowSize = size + shadowRadius * 4
        let shadowCenter = totalSize / 2 // Center of the container
        
        // Outer shadow (larger, more transparent) - centered
        let outerShadow = UIView(frame: CGRect(
            x: shadowCenter - shadowSize / 2,
            y: shadowCenter - shadowSize / 2,
            width: shadowSize,
            height: shadowSize
        ))
        outerShadow.backgroundColor = UIColor.black.withAlphaComponent(0.08) // Lighter
        outerShadow.layer.cornerRadius = shadowSize / 2
        outerShadow.layer.masksToBounds = true
        markerView.insertSubview(outerShadow, at: 0)
        
        // Inner shadow (smaller, less transparent) for depth - centered
        let innerShadowSize = size + shadowRadius * 2
        let innerShadow = UIView(frame: CGRect(
            x: shadowCenter - innerShadowSize / 2,
            y: shadowCenter - innerShadowSize / 2,
            width: innerShadowSize,
            height: innerShadowSize
        ))
        innerShadow.backgroundColor = UIColor.black.withAlphaComponent(0.12) // Lighter
        innerShadow.layer.cornerRadius = innerShadowSize / 2
        innerShadow.layer.masksToBounds = true
        markerView.insertSubview(innerShadow, at: 1)
        
        // Background circle - white if icon is set, light gray if no icon (centered)
        let circleRect = CGRect(x: shadowPadding, y: shadowPadding, width: size, height: size)
        let backgroundCircle = UIView(frame: circleRect)
        backgroundCircle.backgroundColor = hasIcon ? UIColor.white : UIColor.systemGray5
        backgroundCircle.layer.cornerRadius = size / 2
        backgroundCircle.layer.masksToBounds = true
        
        // Add white border
        backgroundCircle.layer.borderWidth = 1.5
        backgroundCircle.layer.borderColor = UIColor.white.cgColor
        
        markerView.addSubview(backgroundCircle)
        
        // Priority: iconUrl > iconName (with fallback)
        var iconAdded = false
        
        if let iconUrl = iconUrl, !iconUrl.isEmpty {
            // Load custom image from URL synchronously (for annotation creation)
            // This ensures the image is loaded before the view is converted to an image
            if let iconImage = loadMarkerIconImageSync(urlString: iconUrl) {
                let iconSize: CGFloat = size * (isSmall ? 0.55 : 0.7)
                let iconImageView = UIImageView(frame: CGRect(
                    x: shadowPadding + (size - iconSize) / 2,
                    y: shadowPadding + (size - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                ))
                iconImageView.image = iconImage
                iconImageView.contentMode = .scaleAspectFit
                iconImageView.clipsToBounds = false
                iconImageView.layer.cornerRadius = 0
                iconImageView.layer.masksToBounds = false
                iconImageView.tintColor = nil
                markerView.addSubview(iconImageView)
                iconAdded = true
                Logger.log("Successfully loaded icon from URL: \(iconUrl)", level: .debug, category: "MarkerFactory")
            } else {
                Logger.log("Failed to load icon from URL (timeout or error): \(iconUrl)", level: .warn, category: "MarkerFactory")
            }
        }
        
        // Fallback to SF Symbol if iconUrl failed or not available
        if !iconAdded, let iconName = iconName, let iconImage = UIImage(systemName: iconName) {
            // Use SF Symbol
            let iconSize: CGFloat = size * (isSmall ? 0.55 : 0.7)
            let iconImageView = UIImageView(frame: CGRect(
                x: shadowPadding + (size - iconSize) / 2,
                y: shadowPadding + (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            ))
            iconImageView.image = iconImage
            iconImageView.tintColor = .systemGray // Darker color since background is light gray
            iconImageView.contentMode = .scaleAspectFit
            markerView.addSubview(iconImageView)
            iconAdded = true
        }
        
        // Ensure view layout is complete before returning
        markerView.setNeedsLayout()
        markerView.layoutIfNeeded()
        
        // Force a render pass to ensure all subviews are properly rendered
        markerView.setNeedsDisplay()
        
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
    
    /// Synchronously loads an image from URL, checking cache first
    /// Returns the image if available (from cache or downloaded), nil otherwise
    /// Uses a shorter timeout to avoid long blocking
    private static func loadMarkerIconImageSync(urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Check cache first (fast path - no blocking)
        if let cachedImage = MarkerFactory.markerImageCache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        // For uncached images, use a shorter timeout to avoid long blocking
        // If on main thread, this will block briefly but with a short timeout it's acceptable
        let semaphore = DispatchSemaphore(value: 0)
        var loadedImage: UIImage?
        
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data,
                  let image = UIImage(data: data) else {
                return
            }
            
            // Cache the image
            MarkerFactory.markerImageCache.setObject(image, forKey: urlString as NSString)
            loadedImage = image
        }.resume()
        
        // Wait for image to load with timeout (3 seconds for better reliability)
        // This minimizes blocking time while allowing enough time for network requests
        let result = semaphore.wait(timeout: .now() + 3.0)
        
        // If timeout occurred, return nil (caller should have fallback)
        if result == .timedOut {
            Logger.log("Image load timeout for URL: \(urlString)", level: .debug, category: "MarkerFactory")
            return nil
        }
        
        if loadedImage == nil {
            Logger.log("Failed to load image from URL: \(urlString)", level: .debug, category: "MarkerFactory")
        }
        
        return loadedImage
    }
    
    private static let markerImageCache = NSCache<NSString, UIImage>()
    
    // MARK: - Mapbox Annotation Methods
    static func createCurrentLocationAnnotation(at location: CLLocation) -> PointAnnotation {
        let view = createCurrentLocationMarkerView()
        guard let image = viewToImage(view) else {
            var annotation = PointAnnotation(point: Point(location.coordinate))
            return annotation
        }
        var annotation = PointAnnotation(point: Point(location.coordinate))
        annotation.image = PointAnnotation.Image(image: image, name: "current-location-marker")
        annotation.iconAnchor = .center
        return annotation
    }
    
    static func createPlaceAnnotation(for place: GMSPlace) -> PointAnnotation {
        // Use pin.svg from asset catalog (place_pin) when available; otherwise fall back to programmatic pin
        let image: UIImage? = loadPlacePinImage() ?? {
            let view = createGlassmorphismMarkerView()
            return viewToImage(view)
        }()
        guard let image = image else {
            var annotation = PointAnnotation(point: Point(place.coordinate))
            return annotation
        }
        var annotation = PointAnnotation(point: Point(place.coordinate))
        annotation.image = PointAnnotation.Image(image: image, name: "place-marker")
        annotation.iconAnchor = .bottom
        let shadowOffsetY = image.size.height - placePinContentHeight
        annotation.iconOffset = [0, Double(shadowOffsetY)]
        annotation.userInfo = ["name": place.name ?? "", "address": place.formattedAddress ?? ""]
        return annotation
    }
    
    /// Height of the pin graphic (excluding shadow) in the place pin image. Use when positioning so the pin tip is at the coordinate.
    static let placePinContentHeight: CGFloat = 74
    
    /// Loads and scales the place pin from Assets (pin.svg in place_pin.imageset) with drop shadow.
    /// Pin is drawn at the top; extra space below allows the shadow to render without clipping.
    private static func loadPlacePinImage() -> UIImage? {
        guard let image = UIImage(named: "place_pin") else { return nil }
        let pinSize = CGSize(width: 64, height: 74)
        let shadowPadding: CGFloat = 10
        let shadowOffset = CGSize(width: 0, height: 4)
        let shadowBlur: CGFloat = 8
        let shadowBottomSpace = shadowOffset.height + shadowBlur + 4
        let canvasSize = CGSize(
            width: pinSize.width + shadowPadding * 2,
            height: pinSize.height + shadowBottomSpace
        )
        let pinRect = CGRect(x: shadowPadding, y: 0, width: pinSize.width, height: pinSize.height)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            image.draw(in: pinRect)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }
    
    /// Returns the place pin image (with drop shadow) for use in animations. Same image as the annotation.
    static func placePinImage() -> UIImage? {
        loadPlacePinImage()
    }
    
    static func createEventAnnotation(for event: Event) -> PointAnnotation {
        guard let coordinates = event.location.coordinates else {
            var annotation = PointAnnotation(point: Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))
            return annotation
        }
        
        let view = createEventMarkerView()
        guard let image = viewToImage(view) else {
            var annotation = PointAnnotation(point: Point(coordinates))
            return annotation
        }
        var annotation = PointAnnotation(point: Point(coordinates))
        annotation.image = PointAnnotation.Image(image: image, name: "event-marker")
        annotation.iconAnchor = .bottom
        // Store event in userInfo for tap handling
        annotation.userInfo = ["event": event]
        return annotation
    }
    
    static func createCollectionPlaceAnnotation(for place: GMSPlace, collection: PlaceCollection, zoomLevel: Float? = nil) -> PointAnnotation {
        let isZoomedOut = zoomLevel != nil && zoomLevel! < 12
        let view = createCollectionPlaceMarkerView(iconName: collection.iconName, iconUrl: collection.iconUrl, isSmall: isZoomedOut)
        
        // Ensure view is properly laid out before converting to image
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        guard let image = viewToImage(view) else {
            Logger.log("Failed to convert view to image for collection: \(collection.name)", level: .warn, category: "MarkerFactory")
            var annotation = PointAnnotation(point: Point(place.coordinate))
            annotation.userInfo = ["collection": collection, "name": place.name ?? "", "address": place.formattedAddress ?? "", "placeId": place.placeID ?? ""]
            return annotation
        }
        var annotation = PointAnnotation(point: Point(place.coordinate))
        annotation.image = PointAnnotation.Image(image: image, name: "collection-place-marker")
        annotation.iconAnchor = .center
        annotation.userInfo = ["collection": collection, "name": place.name ?? "", "address": place.formattedAddress ?? "", "placeId": place.placeID ?? ""]
        return annotation
    }
    
    static func createCollectionPlaceAnnotation(coordinate: CLLocationCoordinate2D, title: String, snippet: String, collection: PlaceCollection, placeId: String, zoomLevel: Float? = nil) -> PointAnnotation {
        let isZoomedOut = zoomLevel != nil && zoomLevel! < 12
        let view = createCollectionPlaceMarkerView(iconName: collection.iconName, iconUrl: collection.iconUrl, isSmall: isZoomedOut)
        
        // Ensure view is properly laid out before converting to image
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        guard let image = viewToImage(view) else {
            Logger.log("Failed to convert view to image for collection: \(collection.name)", level: .warn, category: "MarkerFactory")
            var annotation = PointAnnotation(point: Point(coordinate))
            return annotation
        }
        var annotation = PointAnnotation(point: Point(coordinate))
        annotation.image = PointAnnotation.Image(image: image, name: "collection-place-marker")
        annotation.iconAnchor = .center
        annotation.userInfo = ["collection": collection, "name": title, "address": snippet, "placeId": placeId]
        return annotation
    }
    
    // Helper to convert UIView to UIImage
    private static func viewToImage(_ view: UIView) -> UIImage? {
        // Ensure view and all subviews are properly laid out
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Force a render pass
        view.setNeedsDisplay()
        
        // Ensure all image views have their images loaded
        for subview in view.subviews {
            if let imageView = subview as? UIImageView {
                imageView.setNeedsDisplay()
            }
            // Recursively check nested subviews
            for nestedSubview in subview.subviews {
                if let imageView = nestedSubview as? UIImageView {
                    imageView.setNeedsDisplay()
                }
            }
        }
        
        // Small delay to ensure rendering is complete (runs synchronously on main thread)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        view.layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
} 
