// This button is only used for the login screen
import UIKit

class CustomGlassButton: UIButton {

    // MARK: - Properties
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true
        insertSubview(blurView, at: 0)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        layer.cornerCurve = .continuous
        clipsToBounds = true
        backgroundColor = .clear
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        layer.borderWidth = 1.0

        setTitleColor(.white, for: .normal)
        titleLabel?.font = AppFonts.bodyBold(18)

        addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchCancel, .touchDragExit])

        translatesAutoresizingMaskIntoConstraints = false
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
        let radius = min(bounds.width, bounds.height) / 2
        layer.cornerRadius = radius
        blurView.layer.cornerRadius = radius
    }
}
