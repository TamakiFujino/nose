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
        backgroundColor = .white
        layer.cornerRadius = 20
        layer.shadowColor = UIColor.black.cgColor
        setImage(image, for: .normal)
        tintColor = .black
        imageView?.contentMode = .scaleAspectFit
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        translatesAutoresizingMaskIntoConstraints = false
    }
}
