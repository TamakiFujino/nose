import UIKit

// MARK: - Model
struct ColorModel: Codable {
    let name: String
    let hex: String
}

class ColorPickerBottomSheetView: UIView {
    // MARK: - Properties
    var onColorSelected: ((UIColor) -> Void)?
    private var colors: [ColorModel] = []
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
    private func loadColors() {
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("Failed to locate colors.json in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            colors = try JSONDecoder().decode([ColorModel].self, from: data)
            setupColorButtons()
        } catch {
            print("Failed to load or decode colors.json: \(error)")
        }
    }

    // MARK: - UI Setup
    private func setupColorButtons() {
        let buttonSize: CGFloat = 40
        let padding: CGFloat = 16
        var lastButton: UIButton?

        for (index, colorModel) in colors.enumerated() {
            guard let color = UIColor(hex: colorModel.hex) else { continue }
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
        let selectedColor = colors[sender.tag]
        if let color = UIColor(hex: selectedColor.hex) {
            onColorSelected?(color)
        }
    }
}
