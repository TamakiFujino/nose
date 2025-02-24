import UIKit

class AvatarUIManager: NSObject {
    
    weak var viewController: UIViewController?
    weak var avatar3DViewController: Avatar3DViewController?
    
    private var bottomSheetView: BottomSheetContentView!
    private var additionalBottomSheetView: UIView!
    private var colorButtons: [UIButton] = []
    
    init(viewController: UIViewController, avatar3DViewController: Avatar3DViewController) {
        self.viewController = viewController
        self.avatar3DViewController = avatar3DViewController
        super.init()
        setupAdditionalBottomSheetView()
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
            bottomSheetView.bottomAnchor.constraint(equalTo: additionalBottomSheetView.topAnchor)
        ])
    }
    
    private func setupAdditionalBottomSheetView() {
        guard let viewController = viewController else { return }
        
        // Create and configure the additional bottom sheet view with white background and no corner radius
        additionalBottomSheetView = UIView()
        additionalBottomSheetView.backgroundColor = UIColor.white
        additionalBottomSheetView.translatesAutoresizingMaskIntoConstraints = false
        
        viewController.view.addSubview(additionalBottomSheetView)
        
        // Add color buttons to the additional bottom sheet view
        let colors: [UIColor] = [.red, .green, .blue, .yellow, .purple]
        let buttonSize: CGFloat = 50
        let padding: CGFloat = 10
        
        for (index, color) in colors.enumerated() {
            let button = UIButton(frame: CGRect(x: padding + CGFloat(index) * (buttonSize + padding), y: padding, width: buttonSize, height: buttonSize))
            button.backgroundColor = color
            button.layer.cornerRadius = buttonSize / 2
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            additionalBottomSheetView.addSubview(button)
            colorButtons.append(button)
        }
        
        // Set up constraints for the additional bottom sheet view
        NSLayoutConstraint.activate([
            additionalBottomSheetView.heightAnchor.constraint(equalTo: viewController.view.heightAnchor, multiplier: 0.10),
            additionalBottomSheetView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            additionalBottomSheetView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            additionalBottomSheetView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }
    
    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        bottomSheetView.changeSelectedCategoryColor(to: color)
    }
}
