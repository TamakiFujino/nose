import UIKit

class FloatingUIController: UIViewController {
    weak var delegate: ContentViewController?
    private var currentTopIndex = 0
    private var topOptionsCount = 4

    // Category data
    private let parentCategories = ["Base", "Hair", "Clothes", "Accessories"]
    private let childCategories = [
        ["Eye", "Eyebrow", "Body"],
        ["Base", "Front", "Side", "Back"],
        ["Tops", "Bottoms", "Jacket", "Socks"],
        ["Headwear", "Eyewear", "Neckwear"]
    ]

    private var selectedParentIndex = 0
    private var selectedChildIndex = 0

    // Asset management
    private var assetData: [String: [String: [AssetItem]]] = [:]
    private var currentAssets: [AssetItem] = []

    // Color picker
    private let colorSwatches: [String] = [
        "#FFFFFF", "#000000", "#FF5252", "#FF9800", "#FFEB3B",
        "#4CAF50", "#2196F3", "#9C27B0", "#795548", "#9E9E9E"
    ]
    private var colorButton: UIButton = UIButton(type: .system)
    private var colorOverlayView: UIView?
    private var colorSheetView: UIView?

    private lazy var bottomPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var parentCategoryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var childCategoryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var thumbnailStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAssetData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
        colorButton.layer.cornerRadius = colorButton.bounds.height / 2
        colorButton.clipsToBounds = true
    }

    private func setupUI() {
        view.backgroundColor = .clear
        view.addSubview(bottomPanel)
        bottomPanel.addSubview(parentCategoryStackView)
        bottomPanel.addSubview(childCategoryStackView)
        bottomPanel.addSubview(thumbnailStackView)
        setupColorButton()
        createThumbnailRows()
        createCategoryButtons()

        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomPanel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),

            parentCategoryStackView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 20),
            parentCategoryStackView.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -20),
            parentCategoryStackView.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 10),
            parentCategoryStackView.heightAnchor.constraint(equalToConstant: 30),

            childCategoryStackView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 20),
            childCategoryStackView.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -20),
            childCategoryStackView.topAnchor.constraint(equalTo: parentCategoryStackView.bottomAnchor, constant: 10),
            childCategoryStackView.heightAnchor.constraint(equalToConstant: 30),

            thumbnailStackView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 20),
            thumbnailStackView.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -20),
            thumbnailStackView.centerYAnchor.constraint(equalTo: bottomPanel.centerYAnchor)
        ])
    }

    private func setupColorButton() {
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        if let paintIcon = UIImage(systemName: "paintpalette.fill") {
            colorButton.setImage(paintIcon, for: .normal)
            colorButton.tintColor = .white
        } else {
            colorButton.setTitle("Color", for: .normal)
        }
        colorButton.backgroundColor = UIColor.systemBlue
        colorButton.layer.cornerRadius = 28
        colorButton.layer.shadowColor = UIColor.black.cgColor
        colorButton.layer.shadowOpacity = 0.25
        colorButton.layer.shadowRadius = 6
        colorButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        colorButton.addTarget(self, action: #selector(didTapColorButton), for: .touchUpInside)

        view.addSubview(colorButton)
        view.bringSubviewToFront(colorButton)

        NSLayoutConstraint.activate([
            colorButton.widthAnchor.constraint(equalToConstant: 56),
            colorButton.heightAnchor.constraint(equalToConstant: 56),
            colorButton.widthAnchor.constraint(equalTo: colorButton.heightAnchor),
            colorButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            colorButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        colorButton.setContentHuggingPriority(.required, for: .horizontal)
        colorButton.setContentHuggingPriority(.required, for: .vertical)
        colorButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        colorButton.setContentCompressionResistancePriority(.required, for: .vertical)
        colorButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    }

    @objc private func didTapColorButton() { showColorPicker() }

    private func showColorPicker() {
        if colorOverlayView != nil { return }
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.alpha = 0
        view.addSubview(overlay)
        colorOverlayView = overlay

        let sheetHeight = view.bounds.height * 0.4
        let sheet = UIView(frame: CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: sheetHeight))
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 16
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(sheet)
        colorSheetView = sheet

        let title = UILabel()
        title.text = "Colors"
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(title)

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .lightGray
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(hideColorPicker), for: .touchUpInside)
        sheet.addSubview(closeBtn)

        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(scroll)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 12),
            title.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 16),
            closeBtn.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -12),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),
            closeBtn.heightAnchor.constraint(equalToConstant: 24),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])

        let columns = 7
        let buttonSize: CGFloat = 40
        var currentRow: UIStackView?

        for (i, hex) in colorSwatches.enumerated() {
            if i % columns == 0 {
                currentRow = UIStackView()
                currentRow?.axis = .horizontal
                currentRow?.spacing = 12
                currentRow?.distribution = .fillEqually
                currentRow?.translatesAutoresizingMaskIntoConstraints = false
                if let row = currentRow { grid.addArrangedSubview(row) }
            }
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.backgroundColor = UIColor(hex: hex) ?? .lightGray
            btn.layer.cornerRadius = buttonSize / 2
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
            btn.tag = i
            btn.accessibilityLabel = hex
            btn.addTarget(self, action: #selector(didSelectColor(_:)), for: .touchUpInside)
            btn.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: buttonSize).isActive = true
            currentRow?.addArrangedSubview(btn)
        }

        if let row = currentRow {
            let remainder = colorSwatches.count % columns
            if remainder != 0 {
                for _ in 0..<(columns - remainder) {
                    let spacer = UIView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(spacer)
                }
            }
        }

        UIView.animate(withDuration: 0.24) {
            overlay.alpha = 1
            sheet.frame.origin.y = self.view.bounds.height - sheetHeight
        }
    }

    @objc private func hideColorPicker() {
        guard let overlay = colorOverlayView, let sheet = colorSheetView else { return }
        let endY = view.bounds.height
        UIView.animate(withDuration: 0.22, animations: {
            overlay.alpha = 0
            sheet.frame.origin.y = endY
        }, completion: { _ in
            overlay.removeFromSuperview()
            sheet.removeFromSuperview()
            self.colorOverlayView = nil
            self.colorSheetView = nil
        })
    }

    @objc private func didSelectColor(_ sender: UIButton) {
        let index = sender.tag
        guard index >= 0 && index < colorSwatches.count else { return }
        let hex = colorSwatches[index]
        sendSelectedColorToUnity(hex: hex)
        hideColorPicker()
    }

    private func sendSelectedColorToUnity(hex: String) {
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        let payload: [String: Any] = [
            "category": parent,
            "subcategory": child,
            "colorHex": hex
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ChangeColor", message: json)
        }
    }

    private func createThumbnailRows() {
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.spacing = 16
        rowStackView.distribution = .fillEqually
        for i in 0..<currentAssets.count {
            let thumbnailButton = createThumbnailButton(for: i)
            rowStackView.addArrangedSubview(thumbnailButton)
        }
        thumbnailStackView.addArrangedSubview(rowStackView)
    }

    private func createThumbnailButton(for index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        let asset = currentAssets[index]
        if let thumbnailPath = asset.thumbnailPath,
           let thumbnailImage = UIImage(contentsOfFile: thumbnailPath) {
            button.setImage(thumbnailImage, for: .normal)
        } else {
            let iconNames = ["tshirt", "person.crop.circle", "person.fill", "person.2.fill"]
            let iconIndex = index % iconNames.count
            if let systemImage = UIImage(systemName: iconNames[iconIndex]) {
                button.setImage(systemImage, for: .normal)
                button.tintColor = .black
            }
        }
        button.imageView?.contentMode = .scaleAspectFit
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = index == currentTopIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 80).isActive = true
        button.heightAnchor.constraint(equalToConstant: 80).isActive = true
        return button
    }

    @objc private func thumbnailTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        let asset = currentAssets[newIndex]
        currentTopIndex = newIndex
        updateThumbnailBorders()
        changeAssetInUnity(asset: asset)
    }

    private func updateThumbnailBorders() {
        for subview in thumbnailStackView.arrangedSubviews {
            if let rowStackView = subview as? UIStackView {
                for arrangedSubview in rowStackView.arrangedSubviews {
                    if let button = arrangedSubview as? UIButton {
                        button.layer.borderColor = button.tag == currentTopIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                    }
                }
            }
        }
    }

    private func changeAssetInUnity(asset: AssetItem) {
        let assetInfo: [String: Any] = [
            "id": asset.id,
            "name": asset.name,
            "modelPath": asset.modelPath,
            "category": asset.category,
            "subcategory": asset.subcategory
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: assetInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ChangeAsset", message: jsonString)
        }
    }

    private func createCategoryButtons() {
        for (index, title) in parentCategories.enumerated() {
            let button = createCategoryButton(title: title, tag: index, isParent: true)
            parentCategoryStackView.addArrangedSubview(button)
        }
        updateChildCategories()
    }

    private func createCategoryButton(title: String, tag: Int, isParent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = tag
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        if isParent {
            button.addTarget(self, action: #selector(parentCategoryTapped(_:)), for: .touchUpInside)
        } else {
            button.addTarget(self, action: #selector(childCategoryTapped(_:)), for: .touchUpInside)
        }
        return button
    }

    @objc private func parentCategoryTapped(_ sender: UIButton) {
        selectedParentIndex = sender.tag
        updateChildCategories()
    }

    @objc private func childCategoryTapped(_ sender: UIButton) {
        selectedChildIndex = sender.tag
        updateCategoryButtonStates()
        updateThumbnailsForCategory()
    }

    private func updateChildCategories() {
        childCategoryStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let currentChildCategories = childCategories[selectedParentIndex]
        for (index, title) in currentChildCategories.enumerated() {
            let button = createCategoryButton(title: title, tag: index, isParent: false)
            childCategoryStackView.addArrangedSubview(button)
        }
        selectedChildIndex = 0
        updateCategoryButtonStates()
        updateThumbnailsForCategory()
    }

    private func updateCategoryButtonStates() {
        for (index, subview) in parentCategoryStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                button.layer.borderColor = index == selectedParentIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                button.backgroundColor = index == selectedParentIndex ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.black.withAlphaComponent(0.1)
            }
        }
        for (index, subview) in childCategoryStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                button.layer.borderColor = index == selectedChildIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                button.backgroundColor = index == selectedChildIndex ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.black.withAlphaComponent(0.1)
            }
        }
    }

    private func loadAssetData() {
        loadAssetsForCategory("Base")
        loadAssetsForCategory("Hair")
        loadAssetsForCategory("Clothes_Tops")
        loadAssetsForCategory("Clothes_Socks")
        loadAssetsForCategory("Accessories")
    }

    private func loadAssetsForCategory(_ category: String) {
        guard let url = Bundle.main.url(forResource: "assets_\(category.lowercased())", withExtension: "json") else {
            print("Could not find assets JSON for category: \(category)")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let categoryAssets = try JSONDecoder().decode(CategoryAssets.self, from: data)
            let mainCategory = categoryAssets.category
            if assetData[mainCategory] == nil { assetData[mainCategory] = [:] }
            for asset in categoryAssets.assets {
                if assetData[mainCategory]![asset.subcategory] == nil { assetData[mainCategory]![asset.subcategory] = [] }
                assetData[mainCategory]![asset.subcategory]?.append(asset)
            }
        } catch {
            print("Error loading assets for \(category): \(error)")
        }
    }

    private func updateThumbnailsForCategory() {
        let parentCategory = parentCategories[selectedParentIndex]
        let childCategory = childCategories[selectedParentIndex][selectedChildIndex]
        currentAssets = assetData[parentCategory]?[childCategory] ?? []
        topOptionsCount = currentAssets.count
        updateThumbnailDisplay()
    }

    private func updateThumbnailDisplay() {
        thumbnailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if !currentAssets.isEmpty { createThumbnailRows() }
        else {
            let noAssetsLabel = UILabel()
            noAssetsLabel.text = "No assets available"
            noAssetsLabel.textAlignment = .center
            noAssetsLabel.textColor = .black
            noAssetsLabel.font = .systemFont(ofSize: 16, weight: .medium)
            noAssetsLabel.translatesAutoresizingMaskIntoConstraints = false
            thumbnailStackView.addArrangedSubview(noAssetsLabel)
        }
        currentTopIndex = 0
        updateThumbnailBorders()
    }
}
