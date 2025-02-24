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
        self.setTitleColor(.firstColor, for: .normal)
        self.layer.cornerRadius = 8
        self.clipsToBounds = true
        self.backgroundColor = UIColor.fourthColor
        self.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    }
}
