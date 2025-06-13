import UIKit

class AvatarCustomizationCoordinator {
    // MARK: - Properties
    private weak var viewController: AvatarCustomizationViewController?
    private weak var avatar3DView: Avatar3DView?
    
    var partSelectorView: AvatarPartSelectorView?
    var colorPickerView: ColorPickerBottomSheetView?
    
    // MARK: - Initialization
    init(viewController: AvatarCustomizationViewController, avatar3DView: Avatar3DView) {
        self.viewController = viewController
        self.avatar3DView = avatar3DView
        setupViews()
    }
    
    // MARK: - Setup
    private func setupViews() {
        setupPartSelectorView()
        setupColorPickerView()
    }
    
    private func setupPartSelectorView() {
        partSelectorView = AvatarPartSelectorView()
        partSelectorView?.delegate = self
        partSelectorView?.setAvatar3DView(avatar3DView!)
    }
    
    private func setupColorPickerView() {
        colorPickerView = ColorPickerBottomSheetView()
        colorPickerView?.delegate = self
    }
}

// MARK: - AvatarPartSelectorViewDelegate
extension AvatarCustomizationCoordinator: AvatarPartSelectorViewDelegate {
    func avatarPartSelectorView(_ view: AvatarPartSelectorView, didSelectPart partName: String, forCategory category: String) {
        avatar3DView?.loadAvatarPart(named: partName, category: category)
    }
}

// MARK: - ColorPickerBottomSheetViewDelegate
extension AvatarCustomizationCoordinator: ColorPickerBottomSheetViewDelegate {
    func colorPickerBottomSheetView(_ view: ColorPickerBottomSheetView, didSelectColor color: UIColor, forCategory category: String) {
        if category == "skin" {
            avatar3DView?.changeSkinColor(to: color)
        } else {
            avatar3DView?.changeAvatarPartColor(for: category, to: color)
        }
    }
}
