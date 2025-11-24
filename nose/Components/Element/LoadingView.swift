import UIKit

class LoadingView {
    static let shared = LoadingView()
    
    private var alertController: UIAlertController?
    private var overlayView: UIView?
    private var activityIndicator: UIActivityIndicatorView?
    
    private init() {}
    
    // MARK: - Alert Style Loading
    func showAlertLoading(title: String, message: String = "Please wait...", on viewController: UIViewController) {
        print("🔄 LoadingView: Showing alert loading with title: \(title)")
        DispatchQueue.main.async {
            // If already showing, just update or return
            if let existingAlert = self.alertController {
                print("⚠️ LoadingView: Alert already exists, updating/ignoring")
                // Update message if needed
                existingAlert.message = message
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = .medium
            loadingIndicator.startAnimating()
            alert.view.addSubview(loadingIndicator)
            self.alertController = alert
            
            viewController.present(alert, animated: true) {
                print("✅ LoadingView: Alert presented")
            }
        }
    }
    
    func hideAlertLoading() {
        print("🔄 LoadingView: Hiding alert loading")
        DispatchQueue.main.async {
            guard let alert = self.alertController else {
                print("⚠️ LoadingView: No alert to hide (alertController is nil)")
                // Try to find if there is a presented alert controller on top that matches our style
                // This is a fallback in case reference was lost
                if let topVC = UIApplication.shared.windows.first?.rootViewController?.presentedViewController as? UIAlertController {
                    print("⚠️ LoadingView: Found an alert presented, attempting to dismiss it as fallback")
                    topVC.dismiss(animated: true, completion: nil)
                }
                return
            }
            
            alert.dismiss(animated: true) {
                print("✅ LoadingView: Alert dismissed")
                // Only clear if it matches the one we just dismissed
                if self.alertController == alert {
                    self.alertController = nil
                }
            }
        }
    }
    
    // MARK: - Overlay Style Loading
    func showOverlayLoading(on view: UIView, message: String? = nil, backgroundColor: UIColor = .backgroundPrimary) {
        DispatchQueue.main.async {
            // Create overlay view
            let overlayView = UIView(frame: view.bounds)
            overlayView.backgroundColor = backgroundColor
            overlayView.alpha = 0
            
            // Create activity indicator
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.color = .fourthColor
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            
            // Add views
            overlayView.addSubview(activityIndicator)
            view.addSubview(overlayView)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
            ])
            
            // Add message label if provided
            if let message = message {
                let label = UILabel()
                label.text = message
                label.font = .systemFont(ofSize: 16, weight: .medium)
                label.textColor = .fourthColor
                label.textAlignment = .center
                label.translatesAutoresizingMaskIntoConstraints = false
                overlayView.addSubview(label)
                
                NSLayoutConstraint.activate([
                    label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
                    label.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
                    label.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
                    label.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16)
                ])
            }
            
            // Start animating and show
            activityIndicator.startAnimating()
            UIView.animate(withDuration: 0.3) {
                overlayView.alpha = 1
            }
            
            self.overlayView = overlayView
            self.activityIndicator = activityIndicator
        }
    }
    
    func hideOverlayLoading() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.overlayView?.alpha = 0
            } completion: { _ in
                self.activityIndicator?.stopAnimating()
                self.overlayView?.removeFromSuperview()
                self.overlayView = nil
                self.activityIndicator = nil
            }
        }
    }
} 