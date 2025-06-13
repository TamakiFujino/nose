import UIKit

extension UIViewController {
    func presentAsSheet(_ viewController: UIViewController, detents: [UISheetPresentationController.Detent] = [.medium()]) {
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
        }
        present(viewController, animated: true)
    }
    
    func presentAsHalfModal(_ viewController: UIViewController) {
        viewController.modalPresentationStyle = .custom
        viewController.transitioningDelegate = self as? UIViewControllerTransitioningDelegate
        present(viewController, animated: true)
    }
} 