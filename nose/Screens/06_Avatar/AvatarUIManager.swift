import UIKit

class AvatarUIManager: NSObject {
    
    weak var viewController: UIViewController?
    weak var avatar3DViewController: Avatar3DViewController?
    
    private var bottomSheetView: BottomSheetContentView!
    
    init(viewController: UIViewController, avatar3DViewController: Avatar3DViewController) {
        self.viewController = viewController
        self.avatar3DViewController = avatar3DViewController
        super.init()
        setupBottomSheetView()
    }

    private func setupBottomSheetView() {
        guard let viewController = viewController else { return }
        
        // Create and configure the bottom sheet view
        bottomSheetView = BottomSheetContentView()
        bottomSheetView.avatar3DViewController = avatar3DViewController
        bottomSheetView.translatesAutoresizingMaskIntoConstraints = false
        
        viewController.view.addSubview(bottomSheetView)
        
        // Set up constraints for the bottom sheet view
        NSLayoutConstraint.activate([
            bottomSheetView.heightAnchor.constraint(equalTo: viewController.view.heightAnchor, multiplier: 0.35),
            bottomSheetView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            bottomSheetView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            bottomSheetView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }
}
