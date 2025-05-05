import UIKit

class ToastManager {
    static func showToast(message: String, type: ToastType = .info, duration: TimeInterval = 2.0) {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }

        let containerView = UIView()
        containerView.backgroundColor = .white
        containerView.alpha = 0.0
        containerView.layer.cornerRadius = 10
        containerView.clipsToBounds = true

        // Circle icon view
        let iconView = UIView()
        iconView.backgroundColor = circleColor(for: type)
        iconView.layer.cornerRadius = 6
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Message label
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .black
        messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // Stack layout
        let stackView = UIStackView(arrangedSubviews: [iconView, messageLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)
        window.addSubview(containerView)

        // Layout constraints
        let maxWidth = window.frame.width - 40
        let topPadding = window.safeAreaInsets.top + 10

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -20),
            containerView.topAnchor.constraint(equalTo: window.topAnchor, constant: topPadding),

            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
        ])

        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Haptic
        triggerHaptic(for: type)

        // Animate
        UIView.animate(withDuration: 0.3, animations: {
            containerView.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: [], animations: {
                containerView.alpha = 0.0
            }) { _ in
                containerView.removeFromSuperview()
            }
        }
    }

    private static func triggerHaptic(for type: ToastType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type.feedbackStyle)
    }

    private static func circleColor(for type: ToastType) -> UIColor {
        switch type {
        case .success:
            return .systemGreen
        case .error:
            return .systemRed
        case .info:
            return .lightGray
        }
    }
}
