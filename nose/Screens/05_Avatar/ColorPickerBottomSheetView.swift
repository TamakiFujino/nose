import UIKit

// MARK: - Model
struct ColorModel: Codable {
    let name: String
    let hex: String
}

class ColorPickerBottomSheetView: UIView {
    // MARK: - Properties
    var onColorSelected: ((UIColor) -> Void)?
    private var colors: [String] = [] // Store hex strings directly
    private var scrollView: UIScrollView!
    private var contentView: UIView!

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        loadColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        loadColors()
    }

    // MARK: - Setup
    private func setupView() {
        backgroundColor = .white
        clipsToBounds = true
        setupScrollView()
        setupContentView()
    }

    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func setupContentView() {
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    // MARK: - Data Loading
    @MainActor
    private func loadColors() {
        Task {
            do {
                // Get colors from AvatarResourceManager
                colors = AvatarResourceManager.shared.colorModels
                
                // If colors are empty, try to preload resources
                if colors.isEmpty {
                    try await AvatarResourceManager.shared.preloadAllResources()
                    colors = AvatarResourceManager.shared.colorModels
                }
                
                // Setup UI with loaded colors
                setupColorButtons()
            } catch {
                print("❌ Failed to load colors: \(error)")
            }
        }
    }

    // MARK: - UI Setup
    private func setupColorButtons() {
        // Clear existing buttons
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let buttonSize: CGFloat = 40
        let padding: CGFloat = 16
        var lastButton: UIButton?

        for (index, hexColor) in colors.enumerated() {
            guard let color = UIColor(hex: hexColor) else { 
                print("⚠️ Failed to create color from hex: \(hexColor)")
                continue 
            }
            let button = createColorButton(color: color, size: buttonSize, index: index)
            contentView.addSubview(button)
            lastButton = button
        }

        if let lastButton = lastButton {
            contentView.trailingAnchor.constraint(equalTo: lastButton.trailingAnchor, constant: padding).isActive = true
        }
    }

    private func createColorButton(color: UIColor, size: CGFloat, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = color
        button.tag = index
        button.layer.cornerRadius = size / 2
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + CGFloat(index) * (size + 16))
        ])

        return button
    }

    // MARK: - Actions
    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard sender.tag >= 0 && sender.tag < colors.count else { return }
        let hexColor = colors[sender.tag]
        if let color = UIColor(hex: hexColor) {
            onColorSelected?(color)
        }
    }
}
