import UIKit

class CustomButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        self.setTitleColor(.white, for: .normal)
        // set courner to complete round
        self.layer.cornerRadius = 20
        self.clipsToBounds = true
        self.backgroundColor = UIColor(red: 196/255, green: 150/255, blue: 255/255, alpha: 1)
        self.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil // Allows touches to pass through
    }
}

