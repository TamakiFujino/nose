import UIKit

class IconButton: UIButton {
    // MARK: - Properties
    private let buttonSize: CGFloat
    private let buttonBackgroundColor: UIColor
    private let buttonTintColor: UIColor
    
    // MARK: - Initialization
    init(
        image: UIImage?,
        action: Selector,
        target: Any?,
        size: CGFloat = 55,
        backgroundColor: UIColor = UIColor.fourthColor.withAlphaComponent(0.3),
        tintColor: UIColor = .firstColor
    ) {
        self.buttonSize = size
        self.buttonBackgroundColor = backgroundColor
        self.buttonTintColor = tintColor
        super.init(frame: .zero)
        setupButton(with: image)
        addTarget(target, action: action, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupButton(with image: UIImage?) {
        setImage(image, for: .normal)
        self.tintColor = buttonTintColor
        self.backgroundColor = buttonBackgroundColor
        
        // Configure appearance
        layer.cornerRadius = buttonSize / 2
        imageView?.contentMode = .scaleAspectFit
        
        // Setup constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: buttonSize),
            heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }
}
