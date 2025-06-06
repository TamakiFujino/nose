import UIKit

class CustomGlassButton: UIButton {

    // MARK: - Properties
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let buttonSize: CGFloat = 55  // Standard size for circular buttons
    private let cornerRadius: CGFloat = 27.5  // Half of buttonSize for perfect round

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        // Insert blur background
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = cornerRadius
        blurView.clipsToBounds = true
        insertSubview(blurView, at: 0)

        // Base styles
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
        backgroundColor = UIColor.white.withAlphaComponent(0.1) // glass background
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        layer.borderWidth = 1.0

        setTitleColor(.firstColor, for: .normal)
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)

        // Enable press animation
        addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
        
        // Setup size constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: buttonSize),
            heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }

    // MARK: - Press Animation

    @objc private func pressDown() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.alpha = 0.85
        }
    }

    @objc private func pressUp() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }

    // MARK: - Support Auto Layout Resizing

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
    }
}
