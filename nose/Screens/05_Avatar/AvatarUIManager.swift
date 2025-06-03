import UIKit
import FirebaseStorage

class AvatarUIManager: NSObject {
    // MARK: - Properties
    weak var viewController: UIViewController?
    weak var avatar3DViewController: Avatar3DViewController?

    var bottomSheetView: BottomSheetContentView!
    var additionalBottomSheetView: UIView!
    private var colorButtons: [UIButton] = []
    private var availableColors: [UIColor] = []
    private var selectedColorButton: UIButton?
    
    private let storage = Storage.storage()

    // MARK: - Initialization
    init(viewController: UIViewController, avatar3DViewController: Avatar3DViewController) {
        self.viewController = viewController
        self.avatar3DViewController = avatar3DViewController
        super.init()
        
        setupBottomSheetView()
        setupAdditionalBottomSheetView()
        
        Task {
            await loadAvailableColors()
        }
    }

    // MARK: - Setup
    private func setupBottomSheetView() {
        bottomSheetView = BottomSheetContentView()
        bottomSheetView.avatar3DViewController = avatar3DViewController
        bottomSheetView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupAdditionalBottomSheetView() {
        additionalBottomSheetView = UIView()
        additionalBottomSheetView.backgroundColor = .white
        additionalBottomSheetView.translatesAutoresizingMaskIntoConstraints = false
        setupColorScrollView()
    }

    private func loadAvailableColors() async {
        do {
            let jsonRef = storage.reference().child("avatar_assets/json/colors.json")
            let maxSize: Int64 = 1 * 1024 * 1024 // 1MB max size
            let data = try await jsonRef.data(maxSize: maxSize)
            
            print("📦 Downloaded colors.json data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            
            // Try to decode the new JSON format with name and hex properties
            if let colorObjects = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: String]] {
                print("🎨 Found \(colorObjects.count) color objects")
                availableColors = colorObjects.compactMap { colorObject in
                    guard let hexString = colorObject["hex"] else {
                        print("❌ Missing hex value in color object")
                        return nil
                    }
                    let color = UIColor(hex: hexString)
                    print("🎨 Converting hex \(hexString) to color: \(color?.toHexString() ?? "failed")")
                    return color
                }
                print("✅ Successfully loaded \(availableColors.count) colors from colors.json")
            } else {
                print("❌ Failed to parse colors.json in expected format")
            }
            
            // Update UI on main thread
            await MainActor.run {
                if let scrollView = self.additionalBottomSheetView.subviews.first as? UIScrollView {
                    // Clear existing buttons
                    self.colorButtons.forEach { $0.removeFromSuperview() }
                    self.colorButtons.removeAll()
                    
                    // Setup new buttons
                    self.setupColorButtons(in: scrollView)
                    print("🎨 Set up \(self.colorButtons.count) color buttons")
                }
            }
        } catch {
            print("❌ Failed to load or decode colors.json: \(error)")
        }
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

        print("🔄 Setting up color buttons with \(availableColors.count) colors")
        
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
        print("📏 Set scroll view content size to: \(scrollView.contentSize)")
    }

    private func createColorButton(color: UIColor, size: CGFloat, xPosition: CGFloat) -> UIButton {
        let button = UIButton(frame: CGRect(x: xPosition, y: 10, width: size, height: size))
        button.backgroundColor = color
        button.layer.cornerRadius = size / 2
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        print("🎨 Created color button with color: \(color.toHexString())")
        return button
    }

    // MARK: - Actions
    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        let category = bottomSheetView.getCurrentCategory()
        // Call the efficient color change method on the 3D view controller
        updateColor(color, for: category)
        selectColorButton(sender)
        
        // Save the color to the chosenColors dictionary
        avatar3DViewController?.chosenColors[category] = color
        print("Saved color for \(category): \(color.toHexString())")
    }

    private func selectColorButton(_ button: UIButton) {
        selectedColorButton?.layer.borderWidth = 0
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 2
        selectedColorButton = button
    }

    func updateColor(_ color: UIColor, for category: String) {
        if category == AvatarCategory.skin {
            avatar3DViewController?.changeSkinColor(to: color)
        } else {
            avatar3DViewController?.changeAvatarPartColor(for: category, to: color)
        }
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
