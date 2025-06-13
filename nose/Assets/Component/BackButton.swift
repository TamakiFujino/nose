import UIKit

class BackButton: UIButton {
    
    // MARK: - Properties
    private let buttonSize: CGFloat = 44  // Standard touch target size
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    // MARK: - Setup
    private func setupButton() {
        // Set button icon
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let backImage = UIImage(systemName: "chevron.left", withConfiguration: configuration)
        setImage(backImage, for: .normal)
        
        // Set colors
        tintColor = .label
        
        // Setup size constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: buttonSize),
            heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        
        // Add press animation
        addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
    }
    
    // MARK: - Press Animation
    @objc private func pressDown() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.alpha = 0.8
        }
    }
    
    @objc private func pressUp() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
} 