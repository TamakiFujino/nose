import UIKit

class AvatarUIManager: NSObject {
    // MARK: - Properties
    weak var viewController: UIViewController?
    weak var avatar3DViewController: Avatar3DViewController?

    private var bottomSheetView: BottomSheetContentView!
    private var additionalBottomSheetView: UIView!
    private var colorButtons: [UIButton] = []
    private var availableColors: [UIColor] = []
    private var selectedColorButton: UIButton?

    // MARK: - Initialization
    init(viewController: UIViewController, avatar3DViewController: Avatar3DViewController) {
        self.viewController = viewController
        self.avatar3DViewController = avatar3DViewController
        super.init()
        loadAvailableColors()
        setupAdditionalBottomSheetView()
        setupBottomSheetView()
        setDefaultColor()
    }

    // MARK: - Setup
    private func loadAvailableColors() {
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("Failed to locate colors.json in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            if let colorStrings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String]] {
                availableColors = colorStrings["colors"]?.compactMap { UIColor(hex: $0) } ?? []
            }
        } catch {
            print("Failed to load or decode colors.json: \(error)")
        }
    }

    private func setupBottomSheetView() {
        guard let viewController = viewController else { return }

        bottomSheetView = BottomSheetContentView()
        bottomSheetView.avatar3DViewController = avatar3DViewController
        bottomSheetView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(bottomSheetView)

        NSLayoutConstraint.activate([
            bottomSheetView.heightAnchor.constraint(equalTo: viewController.view.heightAnchor, multiplier: 0.35),
            bottomSheetView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            bottomSheetView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            bottomSheetView.bottomAnchor.constraint(equalTo: additionalBottomSheetView.topAnchor)
        ])
    }

    private func setupAdditionalBottomSheetView() {
        guard let viewController = viewController else { return }

        setupAdditionalBottomSheetContainer(in: viewController)
        setupColorScrollView()
    }

    private func setupAdditionalBottomSheetContainer(in viewController: UIViewController) {
        additionalBottomSheetView = UIView()
        additionalBottomSheetView.backgroundColor = .white
        additionalBottomSheetView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(additionalBottomSheetView)

        NSLayoutConstraint.activate([
            additionalBottomSheetView.heightAnchor.constraint(equalTo: viewController.view.heightAnchor, multiplier: 0.10),
            additionalBottomSheetView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            additionalBottomSheetView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            additionalBottomSheetView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }

    private func setupColorScrollView() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        additionalBottomSheetView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: additionalBottomSheetView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: additionalBottomSheetView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: additionalBottomSheetView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: additionalBottomSheetView.bottomAnchor)
        ])

        setupColorButtons(in: scrollView)
    }

    private func setupColorButtons(in scrollView: UIScrollView) {
        let buttonSize: CGFloat = 35
        let padding: CGFloat = 10
        var contentWidth: CGFloat = padding

        for (index, color) in availableColors.enumerated() {
            let button = createColorButton(color: color, size: buttonSize, xPosition: contentWidth)
            scrollView.addSubview(button)
            colorButtons.append(button)
            
            if index == 0 {
                selectColorButton(button)
            }
            
            contentWidth += buttonSize + padding
        }

        scrollView.contentSize = CGSize(width: contentWidth, height: buttonSize + 2 * padding)
    }

    private func createColorButton(color: UIColor, size: CGFloat, xPosition: CGFloat) -> UIButton {
        let button = UIButton(frame: CGRect(x: xPosition, y: 10, width: size, height: size))
        button.backgroundColor = color
        button.layer.cornerRadius = size / 2
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    private func setDefaultColor() {
        guard let defaultColor = availableColors.first else { return }
        bottomSheetView.changeSelectedCategoryColor(to: defaultColor)
    }

    // MARK: - Actions
    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        let category = bottomSheetView.getCurrentCategory()
        // Call the efficient color change method on the 3D view controller
        if category == "skin" {
            avatar3DViewController?.changeSkinColor(to: color)
        } else {
            avatar3DViewController?.changeClothingItemColor(for: category, to: color)
        }
        selectColorButton(sender)
        
        // Save the color to the chosenColors dictionary (could be redundant, but for UI sync)
        avatar3DViewController?.chosenColors[category] = color
        print("Saved color for \(category): \(color.toHexString())")
    }

    private func selectColorButton(_ button: UIButton) {
        selectedColorButton?.layer.borderWidth = 0
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 2
        selectedColorButton = button
    }
}

// MARK: - UIColor Extension
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
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
