import UIKit

class CustomGradientView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            UIColor(red: 221/255, green: 195/255, blue: 255/255, alpha: 1).cgColor, // Light Purple
            UIColor(red: 195/255, green: 216/255, blue: 253/255, alpha: 1).cgColor // Light Blue
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }
}

