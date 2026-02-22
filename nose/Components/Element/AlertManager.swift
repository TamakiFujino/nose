import UIKit

enum AlertStyle {
    case info
    case success
    case error
}

final class AlertManager {
    static func present(
        on presenter: UIViewController,
        title: String,
        message: String? = nil,
        style: AlertStyle = .info,
        preferredStyle: UIAlertController.Style = .alert,
        actions: [UIAlertAction] = [UIAlertAction(title: "OK", style: .default)]
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        actions.forEach { alert.addAction($0) }
        // Tint color by style
        switch style {
        case .info:
            alert.view.tintColor = .fourthColor
        case .success:
            alert.view.tintColor = .statusSuccess
        case .error:
            alert.view.tintColor = .statusError
        }
        presenter.present(alert, animated: true)
    }
}


