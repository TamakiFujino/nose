import UIKit

struct ColorModel: Codable {
    let name: String
    let hex: String
}

class ColorPickerBottomSheetView: UIView {

    var onColorSelected: ((UIColor) -> Void)?
    private var colors: [ColorModel] = []
    private var scrollView: UIScrollView!
    private var contentView: UIView!

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

    private func setupView() {
        self.backgroundColor = .white
        self.clipsToBounds = true

        setupScrollView()
        setupContentView()
    }

    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        self.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
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

    private func setupColorButtons() {
        let buttonSize: CGFloat = 40
        let padding: CGFloat = 16

        var lastButton: UIButton?

        for (index, colorModel) in colors.enumerated() {
            guard let color = UIColor(hex: colorModel.hex) else { continue }

            let button = UIButton(type: .system)
            button.backgroundColor = color
            button.tag = index
            button.layer.cornerRadius = buttonSize / 2
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(button)

            // Set up constraints for the color buttons
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: buttonSize),
                button.heightAnchor.constraint(equalToConstant: buttonSize),
                button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding + CGFloat(index) * (buttonSize + padding))
            ])

            lastButton = button
        }

        if let lastButton = lastButton {
            contentView.trailingAnchor.constraint(equalTo: lastButton.trailingAnchor, constant: padding).isActive = true
        }
    }

    @objc private func colorButtonTapped(_ sender: UIButton) {
        let selectedColor = colors[sender.tag]
        if let color = UIColor(hex: selectedColor.hex) {
            onColorSelected?(color)
        }
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 else {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
