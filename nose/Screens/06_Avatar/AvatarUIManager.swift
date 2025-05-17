import UIKit

class AvatarUIManager: NSObject {

    weak var viewController: UIViewController?
    weak var avatar3DViewController: Avatar3DViewController?

    private var bottomSheetView: BottomSheetContentView!
    private var additionalBottomSheetView: UIView!
    private var colorButtons: [UIButton] = []
    private var availableColors: [UIColor] = []
    private var selectedColorButton: UIButton?

    init(viewController: UIViewController, avatar3DViewController: Avatar3DViewController) {
        self.viewController = viewController
        self.avatar3DViewController = avatar3DViewController
        super.init()
        loadAvailableColors()
        setupAdditionalBottomSheetView()
        setupBottomSheetView()
        setDefaultColor()
        displayInitialCategory()
    }

    func displayInitialCategory() {
        // 1. Determine the category to select.
        var initialCategoryName: String = "tops" // Default to "tops"

        if let avatarVC = self.avatar3DViewController {
            // Sync BottomSheetContentView's internal selectedModels with the actual state
            bottomSheetView.syncSelectedModels(with: avatarVC.chosenModels)

            // Example: if an outfit was loaded, pick the first category from it that has an item.
            if let firstChosenCategoryWithItem = avatarVC.chosenModels.first(where: { !$0.value.isEmpty })?.key {
                initialCategoryName = firstChosenCategoryWithItem
            }
        } else {
            // Fallback if avatar3DViewController is not available, though it should be.
            // Sync with an empty dictionary or handle appropriately.
            bottomSheetView.syncSelectedModels(with: [:])
        }
        
        print("AvatarUIManager: Attempting to display initial category: \(initialCategoryName)")

        // 2. Instruct BottomSheetContentView to select this category and display its items.
        bottomSheetView.selectCategoryAndDisplayItems(named: initialCategoryName)

        // Ensure the color selection UI is also updated if needed, 
        // though setDefaultColor() already runs in init.
        // If the initial category has a specific color, you might want to update the color UI too.
        if let initialColor = avatar3DViewController?.chosenColors[initialCategoryName] {
            bottomSheetView.changeSelectedCategoryColor(to: initialColor)
            if let buttonIndex = availableColors.firstIndex(of: initialColor), buttonIndex < colorButtons.count {
                selectColorButton(colorButtons[buttonIndex])
            }
        } else {
            setDefaultColor() // Or apply the default color if the category has no specific color saved
        }
    }

    private func loadAvailableColors() {
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("Failed to locate colors.json in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            print("Successfully loaded data from colors.json")
            if let colorStrings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String]] {
                availableColors = colorStrings["colors"]?.compactMap { UIColor(hexString: $0) } ?? []
                print("Parsed colors: \(availableColors)")
            }
        } catch {
            print("Failed to load or decode colors.json: \(error)")
        }
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

        // Create a horizontally scrollable area
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        additionalBottomSheetView.addSubview(scrollView)

        viewController.view.addSubview(additionalBottomSheetView)

        // Add color buttons to the scroll view
        let buttonSize: CGFloat = 35 // 70% of the original size (50 * 0.7)
        let padding: CGFloat = 10
        var contentWidth: CGFloat = padding

        for (index, color) in availableColors.enumerated() {
            let button = UIButton(frame: CGRect(x: contentWidth, y: padding, width: buttonSize, height: buttonSize))
            button.backgroundColor = color
            button.layer.cornerRadius = buttonSize / 2
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            scrollView.addSubview(button)
            colorButtons.append(button)
            if index == 0 {
                selectColorButton(button)
            }
            contentWidth += buttonSize + padding
        }

        scrollView.contentSize = CGSize(width: contentWidth, height: buttonSize + 2 * padding)

        // Set up constraints for the scroll view and additional bottom sheet view
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: additionalBottomSheetView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: additionalBottomSheetView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: additionalBottomSheetView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: additionalBottomSheetView.bottomAnchor),

            additionalBottomSheetView.heightAnchor.constraint(equalTo: viewController.view.heightAnchor, multiplier: 0.10),
            additionalBottomSheetView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            additionalBottomSheetView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            additionalBottomSheetView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }

    private func setDefaultColor() {
        guard let defaultColor = availableColors.first else { return }
        bottomSheetView.changeSelectedCategoryColor(to: defaultColor)
        // Also select the first color button if it exists
        if let firstColorButton = colorButtons.first {
            selectColorButton(firstColorButton)
        }
    }

    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        bottomSheetView.changeSelectedCategoryColor(to: color)
        selectColorButton(sender)
    }

    private func selectColorButton(_ button: UIButton) {
        selectedColorButton?.layer.borderWidth = 0
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 2
        selectedColorButton = button
    }
}

extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: CGFloat

        switch hex.count {
        case 6: // Format: RRGGBB
            r = CGFloat((int >> 16) & 0xFF) / 255.0
            g = CGFloat((int >> 8) & 0xFF) / 255.0
            b = CGFloat(int & 0xFF) / 255.0
            a = 1.0
        case 8: // Format: AARRGGBB
            a = CGFloat((int >> 24) & 0xFF) / 255.0
            r = CGFloat((int >> 16) & 0xFF) / 255.0
            g = CGFloat((int >> 8) & 0xFF) / 255.0
            b = CGFloat(int & 0xFF) / 255.0
        default:
            return nil
        }

        print("Parsed Color - R: \(r), G: \(g), B: \(b), A: \(a)")
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
