import UIKit

class IconButton: UIButton {
    
    init(image: UIImage?, action: Selector, target: Any?) {
        super.init(frame: .zero)
        setupButton(with: image)
        addTarget(target, action: action, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton(with: nil)
    }
    
    private func setupButton(with image: UIImage?) {
        setImage(image, for: .normal)
        tintColor = .sixthColor
        
        imageView?.contentMode = .scaleAspectFit
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        translatesAutoresizingMaskIntoConstraints = false
    }
}
