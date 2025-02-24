import UIKit

class CustomSlider: UISlider {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSlider()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSlider()
    }
    
    private func setupSlider() {
        // Default Swift slider appearance
        minimumTrackTintColor = .firstColor
        maximumTrackTintColor = .firstColor
        thumbTintColor = .fourthColor
        // add a shadow to track
        layer.shadowColor = UIColor.fourthColor.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.3
        
        // Set a custom thumb image with a smaller size
        let thumbImage = createThumbImage(diameter: 20.0) // Customize diameter as needed
        setThumbImage(thumbImage, for: .normal)
    }
    
    // Override the trackRect(forBounds:) method to customize the track height
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        // Call the super method to get the default track rect
        var trackRect = super.trackRect(forBounds: bounds)
        // Set your desired track height (e.g., 10 points)
        let customTrackHeight: CGFloat = 25.0
        trackRect.size.height = customTrackHeight
        return trackRect
    }
    
    // Helper method to create a custom thumb image with the specified diameter
    private func createThumbImage(diameter: CGFloat) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
            UIColor.fourthColor.setFill()
            context.cgContext.fillEllipse(in: rect)
        }
        return image
    }
}
