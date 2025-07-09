import UIKit
import FirebaseStorage

class AvatarCustomizationCoordinator: NSObject {
    // MARK: - Properties
    weak var viewController: UIViewController?
    weak var avatar3DViewController: Avatar3DViewController?

    var partSelectorView: AvatarPartSelectorView!
    var colorPickerView: ColorPickerBottomSheetView!
    
    // MARK: - Initialization
    init(viewController: UIViewController, avatar3DViewController: Avatar3DViewController) {
        self.viewController = viewController
        self.avatar3DViewController = avatar3DViewController
        super.init()
        
        setupPartSelectorView()
        setupColorPickerView()
    }

    // MARK: - Setup
    private func setupPartSelectorView() {
        partSelectorView = AvatarPartSelectorView()
        partSelectorView.avatar3DViewController = avatar3DViewController
        partSelectorView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupColorPickerView() {
        colorPickerView = ColorPickerBottomSheetView()
        colorPickerView.translatesAutoresizingMaskIntoConstraints = false
        colorPickerView.onColorSelected = { [weak self] color in
            self?.handleColorSelection(color)
        }
    }

    // MARK: - Actions
    private func handleColorSelection(_ color: UIColor) {
        let category = partSelectorView.getCurrentCategory()
        updateColor(color, for: category)
        
        // Save the color to the chosenColors dictionary
        avatar3DViewController?.chosenColors[category] = color
        print("Saved color for \(category): \(color.toHexString())")
    }

    func updateColor(_ color: UIColor, for category: String) {
        if category == "skin" {
            avatar3DViewController?.changeSkinColor(to: color)
        } else {
            avatar3DViewController?.changeAvatarPartColor(for: category, to: color)
        }
    }
}
