import UIKit

class BackShadowView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupShadow()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupShadow()
    }

    private func setupShadow() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.firstColor.withAlphaComponent(1.0).cgColor, // Darker shadow at top
            UIColor.firstColor.withAlphaComponent(0.0).cgColor  // Fully transparent at bottom
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.4) // Starts from the top
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)   // Fades to the bottom
        gradientLayer.frame = bounds
        gradientLayer.masksToBounds = false

        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds // Ensure gradient resizes properly
    }
}
