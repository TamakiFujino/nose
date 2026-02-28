import UIKit
import FirebaseCore

class FloatingUIController: UIViewController {
    weak var delegate: ContentViewControllerDelegate?
    var currentTopIndex = 0
    private var rotateOverlayView: UIView?
    private var rotatePan: UIPanGestureRecognizer?
    private var lastPanTranslationX: CGFloat = 0

    // Category data - organized by tab
    var parentCategories: [String] {
        switch selectedCategoryTab {
        case .face:
            return ["Base", "Hair", "Make Up"]
        case .clothes:
            return ["Clothes", "Accessories"]
        }
    }
    
    var childCategories: [[String]] {
        switch selectedCategoryTab {
        case .face:
            return [
                ["Body", "Eye", "Eyebrow"],  // Base
                ["Base", "Front", "Side", "Back", "Arrange"],  // Hair
                ["Eyeshadow", "Blush"]  // Make Up
            ]
        case .clothes:
            return [
                ["Tops", "Bottoms", "Socks"],  // Clothes
                ["Headwear", "Neckwear"]  // Accessories
            ]
        }
    }
    
    var selectedParentIndex = 0
    var selectedChildIndex = 0

    // MARK: - Make Up toggles (Blush / Eyeshadow)
    private func isMakeupSlot(parent: String, child: String) -> Bool {
        return parent == "Make Up" && (child == "Blush" || child == "Eyeshadow")
    }

    private func isMakeupEnabled(parent: String, child: String) -> Bool {
        let key = "\(parent)_\(child)"
        let enabled = selections[key]?["enabled"]?.lowercased()
        // Default to OFF if not set
        return enabled == "true"
    }

    private func setMakeupEnabled(parent: String, child: String, enabled: Bool) {
        let key = "\(parent)_\(child)"
        var entry = selections[key] ?? [:]
        entry["enabled"] = enabled ? "true" : "false"
        selections[key] = entry
    }

    // Asset management
    var assetData: [String: [String: [AssetItem]]] = [:]
    var currentAssets: [AssetItem] = []
    var imageCache: NSCache<NSString, UIImage> = NSCache()
    var initialSelections: [String: [String: String]] = [:]
    var selections: [String: [String: String]] = [:]
    

    // Color picker (loaded from Hosting palette; falls back to white when needed)
    var colorSwatches: [String] = []
    private var colorButton: UIButton = UIButton(type: .system)
    private var colorOverlayView: UIView?
    private var colorSheetView: UIView?
    private var colorButtons: [UIButton] = []
    
    // New category tab buttons
    private lazy var categoryTabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var faceTabButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        if let faceIcon = UIImage(systemName: "face.smiling.fill") {
            button.setImage(faceIcon, for: .normal)
        }
        button.tintColor = .black
        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(didTapFaceTab), for: .touchUpInside)
        return button
    }()
    
    private lazy var clothesTabButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        if let clothesIcon = UIImage(systemName: "tshirt.fill") {
            button.setImage(clothesIcon, for: .normal)
        }
        button.tintColor = .black
        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(didTapClothesTab), for: .touchUpInside)
        return button
    }()

    private lazy var bottomPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        if let chevron = UIImage(systemName: "chevron.backward") {
            button.setImage(chevron, for: .normal)
            button.tintColor = .black
            button.setTitle("  Back", for: .normal)
        } else {
            button.setTitle("Back", for: .normal)
        }
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 12)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        return button
    }()

    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Save", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
        return button
    }()

    private lazy var parentCategoryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill // Allow tabs to size to content
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var childCategoryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill // Changed from fillEqually to allow content-based sizing
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var childCategoryScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        return scrollView
    }()

    private lazy var thumbnailStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var thumbnailScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()

    private lazy var thumbnailContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        LoadingView.shared.showOverlayLoading(on: view, message: "Loading avatar...")
        // Initialize with initial selections (from Firestore if provided)
        selections = initialSelections
        // Load color palette from Hosting (optional), fallback to built-in
        loadColorPalette()
        setupUI()
        loadAssetData()
        // Set initial tab state to clothes (t-shirt)
        updateTabButtonStates(selectedTab: .clothes)
        UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "SetAvatarCameraFocus", message: "clothes")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
        colorButton.layer.cornerRadius = colorButton.bounds.height / 2
        colorButton.clipsToBounds = true
        // Ensure tabs have fully rounded (pill) corners
        parentCategoryStackView.arrangedSubviews.forEach { subview in
            if let button = subview as? UIButton {
                button.layer.cornerRadius = button.bounds.height / 2
                button.clipsToBounds = true
            }
        }
        childCategoryStackView.arrangedSubviews.forEach { subview in
            if let button = subview as? UIButton {
                button.layer.cornerRadius = button.bounds.height / 2
                button.clipsToBounds = true
            }
        }
        // Make top buttons perfectly pill-shaped
        backButton.layer.cornerRadius = backButton.bounds.height / 2
        backButton.clipsToBounds = true
        saveButton.layer.cornerRadius = saveButton.bounds.height / 2
        saveButton.clipsToBounds = true
    }

    private func setupUI() {
        view.backgroundColor = .clear
        setupRotateOverlay()
        view.addSubview(backButton)
        view.addSubview(saveButton)
        view.addSubview(bottomPanel)
        bottomPanel.addSubview(parentCategoryStackView)
        bottomPanel.addSubview(childCategoryScrollView)
        childCategoryScrollView.addSubview(childCategoryStackView)
        bottomPanel.addSubview(thumbnailScrollView)
        thumbnailScrollView.addSubview(thumbnailContentView)
        thumbnailContentView.addSubview(thumbnailStackView)
        setupColorButton()
        setupCategoryTabs()
        createThumbnailRows()
        createCategoryButtons()

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            saveButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            saveButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomPanel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),

            parentCategoryStackView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 20),
            parentCategoryStackView.trailingAnchor.constraint(lessThanOrEqualTo: bottomPanel.trailingAnchor, constant: -20),
            parentCategoryStackView.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 10),
            parentCategoryStackView.heightAnchor.constraint(equalToConstant: 30),

            childCategoryScrollView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 20),
            childCategoryScrollView.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -20),
            childCategoryScrollView.topAnchor.constraint(equalTo: parentCategoryStackView.bottomAnchor, constant: 10),
            childCategoryScrollView.heightAnchor.constraint(equalToConstant: 30),

            // Stack inside horizontal scroll view
            childCategoryStackView.leadingAnchor.constraint(equalTo: childCategoryScrollView.contentLayoutGuide.leadingAnchor),
            childCategoryStackView.trailingAnchor.constraint(equalTo: childCategoryScrollView.contentLayoutGuide.trailingAnchor),
            childCategoryStackView.topAnchor.constraint(equalTo: childCategoryScrollView.contentLayoutGuide.topAnchor),
            childCategoryStackView.bottomAnchor.constraint(equalTo: childCategoryScrollView.contentLayoutGuide.bottomAnchor),
            childCategoryStackView.heightAnchor.constraint(equalTo: childCategoryScrollView.frameLayoutGuide.heightAnchor),

            // Thumbnails scroll view fills remaining space
            thumbnailScrollView.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor),
            thumbnailScrollView.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor),
            thumbnailScrollView.topAnchor.constraint(equalTo: childCategoryScrollView.bottomAnchor, constant: 10),
            thumbnailScrollView.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -10),

            // Content view anchors to scroll contentLayoutGuide and matches scroll width
            thumbnailContentView.leadingAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.leadingAnchor),
            thumbnailContentView.trailingAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.trailingAnchor),
            thumbnailContentView.topAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.topAnchor),
            thumbnailContentView.bottomAnchor.constraint(equalTo: thumbnailScrollView.contentLayoutGuide.bottomAnchor),
            thumbnailContentView.widthAnchor.constraint(equalTo: thumbnailScrollView.frameLayoutGuide.widthAnchor),

            // Stack view inside content with horizontal padding
            thumbnailStackView.leadingAnchor.constraint(equalTo: thumbnailContentView.leadingAnchor, constant: 20),
            thumbnailStackView.trailingAnchor.constraint(equalTo: thumbnailContentView.trailingAnchor, constant: -20),
            thumbnailStackView.topAnchor.constraint(equalTo: thumbnailContentView.topAnchor),
            thumbnailStackView.bottomAnchor.constraint(equalTo: thumbnailContentView.bottomAnchor)
        ])
    }

    @objc private func didTapBack() {
        Logger.log("[FloatingUIController] Back button tapped. Delegate is \(delegate == nil ? "nil" : "set").", level: .debug, category: "FloatingUI")
        delegate?.didRequestClose()
    }

    @objc private func didTapSave() {
        Logger.log("[FloatingUIController] Save button tapped", level: .debug, category: "FloatingUI")
        ToastManager.showToast(message: ToastMessages.avatarSaved, type: .success)
        // Ensure Unity reflects removals before saving
        syncUnityRemovalsWithSelections()
        // Send accumulated selections
        delegate?.didRequestSave(selections: selections)
    }

    // MARK: - Convenience
    private func isSelectedParent(_ index: Int) -> Bool { index == selectedParentIndex }
    private func isSelectedChild(_ index: Int) -> Bool { index == selectedChildIndex }

    private func setupColorButton() {
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        if let paintIcon = UIImage(systemName: "paintpalette.fill") {
            colorButton.setImage(paintIcon, for: .normal)
            colorButton.tintColor = .white
        } else {
            colorButton.setTitle("Color", for: .normal)
        }
        colorButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
    
    private func setupCategoryTabs() {
        categoryTabStackView.addArrangedSubview(faceTabButton)
        categoryTabStackView.addArrangedSubview(clothesTabButton)
        
        view.addSubview(categoryTabStackView)
        view.bringSubviewToFront(categoryTabStackView)
        
        // Set minimum width and allow buttons to size to content
        let minWidth: CGFloat = 56
        NSLayoutConstraint.activate([
            faceTabButton.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
            clothesTabButton.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
            
            categoryTabStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            categoryTabStackView.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -20)
        ])
        
        // Allow buttons to size to content
        faceTabButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        faceTabButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        clothesTabButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        clothesTabButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
    
    @objc private func didTapFaceTab() {
        Logger.log("[FloatingUIController] Face tab tapped", level: .debug, category: "FloatingUI")
        updateTabButtonStates(selectedTab: .face)
        refreshCategoriesForTab()
        UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "SetAvatarCameraFocus", message: "face")
    }
    
    @objc private func didTapClothesTab() {
        Logger.log("[FloatingUIController] Clothes tab tapped", level: .debug, category: "FloatingUI")
        updateTabButtonStates(selectedTab: .clothes)
        refreshCategoriesForTab()
        // Return to the default (original) camera view
        UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "SetAvatarCameraFocus", message: "clothes")
    }
    
    private func refreshCategoriesForTab() {
        // Reset selections
        selectedParentIndex = 0
        selectedChildIndex = 0
        
        // Recreate category buttons
        parentCategoryStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, title) in parentCategories.enumerated() {
            let button = createCategoryButton(title: title, tag: index, isParent: true)
            parentCategoryStackView.addArrangedSubview(button)
        }
        
        // Update child categories
        updateChildCategories()
        
        // Refresh thumbnails
        refetchAssetsForSelectedCategory()
    }
    
    enum CategoryTab {
        case face
        case clothes
    }
    
    var selectedCategoryTab: CategoryTab = .clothes
    
    private func updateTabButtonStates(selectedTab: CategoryTab) {
        selectedCategoryTab = selectedTab
        
        // Update button appearances - use same color as active tabs
        faceTabButton.backgroundColor = selectedTab == .face ? 
            .fourthColor : 
            UIColor.white.withAlphaComponent(0.9)
        
        faceTabButton.tintColor = selectedTab == .face ? .white : .black
        
        clothesTabButton.backgroundColor = selectedTab == .clothes ? 
            .fourthColor : 
            UIColor.white.withAlphaComponent(0.9)
        
        clothesTabButton.tintColor = selectedTab == .clothes ? .white : .black
    }

    @objc private func didTapColorButton() { showColorPicker() }

    private func showColorPicker() {
        if colorOverlayView != nil { return }
        colorButtons.removeAll()
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

        let swatches = colorSwatches.isEmpty ? ["#FFFFFF"] : colorSwatches
        for (i, hex) in swatches.enumerated() {
            if i % columns == 0 {
                currentRow = UIStackView()
                currentRow?.axis = .horizontal
                currentRow?.spacing = 12
                currentRow?.distribution = .fillEqually
                currentRow?.alignment = .center
                currentRow?.translatesAutoresizingMaskIntoConstraints = false
                if let row = currentRow { grid.addArrangedSubview(row) }
            }
            // Wrap button in a container that fills equally, while the button stays fixed-size and circular
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            currentRow?.addArrangedSubview(container)
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: buttonSize).isActive = true

            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.backgroundColor = UIColor(hex: hex) ?? .lightGray
            btn.layer.cornerRadius = buttonSize / 2
            btn.layer.masksToBounds = true
            // Default thin border so light colors (e.g., white) are visible
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
            btn.tag = i
            btn.accessibilityLabel = hex
            btn.addTarget(self, action: #selector(didSelectColor(_:)), for: .touchUpInside)

            container.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                btn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                btn.widthAnchor.constraint(equalToConstant: buttonSize),
                btn.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
            colorButtons.append(btn)
        }

        if let row = currentRow {
            let remainder = swatches.count % columns
            if remainder != 0 {
                for _ in 0..<(columns - remainder) {
                    let spacer = UIView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(spacer)
                }
            }
        }

        // Preselect current color if available
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        let key = "\(parent)_\(child)"
        let currentHex = selections[key]? ["color"]
        updateColorSelectionBorder(selectedHex: currentHex)

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
            self.colorButtons.removeAll()
        })
    }

    @objc private func didSelectColor(_ sender: UIButton) {
        let index = sender.tag
        let swatches = colorSwatches.isEmpty ? ["#FFFFFF"] : colorSwatches
        guard index >= 0 && index < swatches.count else { return }
        let hex = swatches[index]
        sendSelectedColorToUnity(hex: hex)
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        let key = "\(parent)_\(child)"
        var entry = selections[key] ?? [:]
        entry["color"] = hex
        // If this is a Make Up slot, selecting a color should enable it
        if isMakeupSlot(parent: parent, child: child) {
            entry["enabled"] = "true"
            // Enabled = ON; "nosign" thumbnail becomes unselected (no border)
            currentTopIndex = -1
        }
        selections[key] = entry
        updateColorSelectionBorder(selectedHex: hex)
        updateThumbnailBorders()
        // Keep panel open until the user taps close
    }

    private func updateColorSelectionBorder(selectedHex: String?) {
        for button in colorButtons {
            let isSelected = (button.accessibilityLabel == selectedHex)
            if isSelected {
                button.layer.borderColor = UIColor.fourthColor.cgColor
                button.layer.borderWidth = 2
            } else {
                button.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
                button.layer.borderWidth = 1
            }
        }
    }

    private func createThumbnailRows() {
        let itemsPerRow = 4
        var rowStackView: UIStackView?
        for i in 0..<currentAssets.count {
            if i % itemsPerRow == 0 {
                rowStackView = UIStackView()
                rowStackView?.axis = .horizontal
                rowStackView?.spacing = 12
                rowStackView?.distribution = .fillEqually
                rowStackView?.translatesAutoresizingMaskIntoConstraints = false
                if let row = rowStackView { thumbnailStackView.addArrangedSubview(row) }
                // Give rows a consistent height based on available width
                // Each item has equal width; make height = width to ensure square thumbnails
                let rowHeight = thumbnailContentView.widthAnchor.constraint(equalToConstant: 0)
                rowHeight.isActive = false // placeholder to satisfy compiler; we'll set child constraints per button
            }
            let thumbnailButton = createThumbnailButton(for: i)
            rowStackView?.addArrangedSubview(thumbnailButton)
        }
        // Pad last row with invisible placeholders to keep 4 fixed columns
        if let lastRow = rowStackView {
            let remainder = currentAssets.count % itemsPerRow
            if remainder != 0 {
                for _ in 0..<(itemsPerRow - remainder) {
                    let placeholder = UIView()
                    placeholder.translatesAutoresizingMaskIntoConstraints = false
                    placeholder.backgroundColor = .clear
                    placeholder.isUserInteractionEnabled = false
                    // Keep square aspect like the buttons
                    placeholder.heightAnchor.constraint(equalTo: placeholder.widthAnchor).isActive = true
                    lastRow.addArrangedSubview(placeholder)
                }
            }
        }
    }

    private func createThumbnailButton(for index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        let asset = currentAssets[index]
        // Try explicit thumbnailPath first
        if let thumbnailPath = asset.thumbnailPath, !thumbnailPath.isEmpty {
            if let remoteURL = resolvedRemoteURL(from: thumbnailPath) {
                // Try provided URL, and attempt common extension fallback
                let candidates = thumbnailURLCandidates(from: remoteURL)
                setRemoteImage(on: button, urls: candidates, index: index)
            } else if FileManager.default.fileExists(atPath: thumbnailPath),
           let thumbnailImage = UIImage(contentsOfFile: thumbnailPath) {
                let normalized = normalizeImageForDisplay(thumbnailImage)
                button.setImage(normalized, for: .normal)
                button.tintColor = .clear
            }
        } else if let url = resolvedThumbnailURL(for: asset) {
            // Constructed remote URL: {base}/Thumbs/{Category}/{Subcategory}/{Name}.jpg
            let candidates = thumbnailURLCandidates(from: url)
            setRemoteImage(on: button, urls: candidates, index: index)
        }
        if button.image(for: .normal) == nil {
            let iconNames = ["tshirt", "person.crop.circle", "person.fill", "person.2.fill"]
            let iconIndex = index % iconNames.count
            if let systemImage = UIImage(systemName: iconNames[iconIndex]) {
                button.setImage(systemImage, for: .normal)
                button.tintColor = .black
            }
        }
        button.imageView?.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        button.backgroundColor = UIColor.black.withAlphaComponent(0.05)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = index == currentTopIndex ? UIColor.thirdColor.cgColor : UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)
        // Make the button a consistent square: height equals width
        button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
        return button
    }

    @objc private func thumbnailTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        let asset = currentAssets[newIndex]
        let wasSelected = (newIndex == currentTopIndex)
        if wasSelected {
            // Toggle off (reset) this slot
            let parent = parentCategories[selectedParentIndex]
            let child = childCategories[selectedParentIndex][selectedChildIndex]
            if parent.lowercased() == "base" && child.lowercased() == "body" {
                // Remove applied pose animation → back to default A-pose
                sendResetBodyPose()
            } else {
                sendRemoveAssetToUnity(category: parent, subcategory: child)
            }
            // Clear selection state and border
            currentTopIndex = -1
            updateThumbnailBorders()
            // Clear saved model for this slot but keep color in case user selects again
            let key = "\(parent)_\(child)"
            var entry = selections[key] ?? [:]
            entry.removeValue(forKey: "model")
            selections[key] = entry
            return
        } else {
            currentTopIndex = newIndex
            updateThumbnailBorders()
            changeAssetInUnity(asset: asset)
        }
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        let key = "\(parent)_\(child)"
        var entry = selections[key] ?? [:]
        if parent.lowercased() == "base" && child.lowercased() == "body" {
            entry["pose"] = asset.name
        } else {
            entry["model"] = asset.name
        }
        selections[key] = entry
        // Reapply saved color for this slot, or use default if none set
        if let savedHex = entry["color"], !savedHex.isEmpty {
            sendColorToUnity(category: parent, subcategory: child, hex: savedHex)
        } else if let defaultHex = colorSwatches.first {
            sendColorToUnity(category: parent, subcategory: child, hex: defaultHex)
            var updated = selections[key] ?? [:]
            updated["color"] = defaultHex
            selections[key] = updated
        }
    }

    func updateThumbnailBorders() {
        for subview in thumbnailStackView.arrangedSubviews {
            if let rowStackView = subview as? UIStackView {
                for arrangedSubview in rowStackView.arrangedSubviews {
                    if let button = arrangedSubview as? UIButton {
                        button.layer.borderColor = button.tag == currentTopIndex ? UIColor.fourthColor.cgColor : UIColor.clear.cgColor
                    }
                }
            }
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
        button.titleLabel?.font = isParent ? .systemFont(ofSize: 14, weight: .medium) : .systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        // Set default background to secondColor
        button.backgroundColor = .secondColor
        button.layer.cornerRadius = isParent ? 16 : 12
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding so text doesn't touch edges
        let horizontalPadding: CGFloat = isParent ? 16 : 12
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)
        
        if !isParent {
            button.heightAnchor.constraint(equalToConstant: 26).isActive = true
            // Minimum width for easy tapping, but size to content
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
            // Allow button to size to content
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        } else {
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            // Minimum width for easy tapping, but size to content
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
            // Allow button to size to content - use higher priority for parent categories
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        if isParent {
            button.addTarget(self, action: #selector(parentCategoryTapped(_:)), for: .touchUpInside)
        } else {
            button.addTarget(self, action: #selector(childCategoryTapped(_:)), for: .touchUpInside)
        }
        return button
    }

    private var refetchWorkItem: DispatchWorkItem?
    @objc private func parentCategoryTapped(_ sender: UIButton) {
        selectedParentIndex = sender.tag
        updateChildCategories()
        // Debounce refetch to avoid double work when child resets to 0
        refetchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refetchAssetsForSelectedCategory() }
        refetchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    @objc private func childCategoryTapped(_ sender: UIButton) {
        selectedChildIndex = sender.tag
        updateCategoryButtonStates()
        updateThumbnailsForCategory()
        // Debounce refetch
        refetchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refetchAssetsForSelectedCategory() }
        refetchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
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
                button.layer.borderWidth = 0
                button.layer.borderColor = UIColor.clear.cgColor
                let isSelected = index == selectedParentIndex
                // Active tab: darker background with white text
                // Inactive tab: secondColor background with black text
                button.backgroundColor = isSelected ? .fourthColor : .secondColor
                button.setTitleColor(isSelected ? .white : .black, for: .normal)
                button.layer.cornerRadius = 16
            }
        }
        for (index, subview) in childCategoryStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                button.layer.borderWidth = 0
                button.layer.borderColor = UIColor.clear.cgColor
                let isSelected = index == selectedChildIndex
                // Active tab: darker background with white text
                // Inactive tab: secondColor background with black text
                button.backgroundColor = isSelected ? .fourthColor : .secondColor
                button.setTitleColor(isSelected ? .white : .black, for: .normal)
                button.layer.cornerRadius = 12
            }
        }
    }

    func updateThumbnailsForCategory() {
        let parentCategory = parentCategories[selectedParentIndex]
        let childCategory = childCategories[selectedParentIndex][selectedChildIndex]
        currentAssets = assetData[parentCategory]?[childCategory] ?? []
        updateThumbnailDisplay()
        applySelectionForCurrentCategory()
    }

    private func updateThumbnailDisplay() {
        // Clear previous rows
        thumbnailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // By default, no selection until a saved selection is applied or user taps
        currentTopIndex = -1
        // Remove any existing no-assets overlay
        if let existingOverlay = bottomPanel.viewWithTag(9999) { existingOverlay.removeFromSuperview() }

        let parentCategory = parentCategories[selectedParentIndex]
        let childCategory = childCategories[selectedParentIndex][selectedChildIndex]

        if !currentAssets.isEmpty {
            createThumbnailRows()
        } else if isMakeupSlot(parent: parentCategory, child: childCategory) {
            // Show a single toggle thumbnail for Make Up slots (Blush / Eyeshadow)
            showMakeupToggleThumbnail(parent: parentCategory, child: childCategory)
        } else {
            // Overlay a centered message over the thumbnail area
            let container = UIView()
            container.tag = 9999
            container.translatesAutoresizingMaskIntoConstraints = false
            bottomPanel.addSubview(container)

            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 20),
                container.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -20),
                container.topAnchor.constraint(equalTo: childCategoryStackView.bottomAnchor, constant: 10),
                container.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -10)
            ])

            let noAssetsLabel = UILabel()
            noAssetsLabel.text = "No assets available"
            noAssetsLabel.textAlignment = .center
            noAssetsLabel.textColor = .fourthColor
            noAssetsLabel.font = .systemFont(ofSize: 16, weight: .medium)
            noAssetsLabel.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(noAssetsLabel)
            NSLayoutConstraint.activate([
                noAssetsLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                noAssetsLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            bottomPanel.bringSubviewToFront(container)
        }
        updateThumbnailBorders()
        LoadingView.shared.hideOverlayLoading()
    }

    private func showMakeupToggleThumbnail(parent: String, child: String) {
        // Remove any existing no-assets overlay
        if let existingOverlay = bottomPanel.viewWithTag(9999) { existingOverlay.removeFromSuperview() }

        // Create a square thumbnail (same style as other image thumbnails)
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = 0
        button.imageView?.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        button.backgroundColor = UIColor.black.withAlphaComponent(0.05)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        // Always show "nosign". Selected (border on) means OFF.
        button.setImage(UIImage(systemName: "nosign"), for: .normal)
        button.tintColor = .black
        button.contentEdgeInsets = UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        button.addTarget(self, action: #selector(makeupToggleTapped(_:)), for: .touchUpInside)
        // Square aspect
        button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true

        // Place into a 4-column row so its size matches other thumbnails
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(button)
        for _ in 0..<3 {
            let placeholder = UIView()
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            placeholder.backgroundColor = .clear
            placeholder.isUserInteractionEnabled = false
            placeholder.heightAnchor.constraint(equalTo: placeholder.widthAnchor).isActive = true
            row.addArrangedSubview(placeholder)
        }
        thumbnailStackView.addArrangedSubview(row)

        // Default is OFF (selected/bordered). Enabled => unselected (no border).
        currentTopIndex = isMakeupEnabled(parent: parent, child: child) ? -1 : 0
    }

    @objc private func makeupToggleTapped(_ sender: UIButton) {
        let parent = parentCategories[selectedParentIndex]
        let child = childCategories[selectedParentIndex][selectedChildIndex]
        guard isMakeupSlot(parent: parent, child: child) else { return }

        let key = "\(parent)_\(child)"
        let currentlyEnabled = isMakeupEnabled(parent: parent, child: child)

        if currentlyEnabled {
            // Turn OFF: show as selected (border on); remove effect (shader uses Add, so black = no effect)
            setMakeupEnabled(parent: parent, child: child, enabled: false)
            sendColorToUnity(category: parent, subcategory: child, hex: "#000000")
            currentTopIndex = 0
        } else {
            // Turn ON: unselect (no border) and apply saved color (or default)
            setMakeupEnabled(parent: parent, child: child, enabled: true)
            let savedHex = selections[key]?["color"]
            let hexToApply = (savedHex?.isEmpty == false) ? savedHex! : (colorSwatches.first ?? "#FFFFFF")
            var entry = selections[key] ?? [:]
            entry["color"] = hexToApply
            selections[key] = entry
            sendColorToUnity(category: parent, subcategory: child, hex: hexToApply)
            currentTopIndex = -1
        }

        updateThumbnailBorders()
    }

    // MARK: - Rotation overlay forwarding pan to Unity
    private func setupRotateOverlay() {
        if rotateOverlayView != nil { return }
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(overlay, at: 0) // keep all buttons/panels above
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleRotatePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        overlay.addGestureRecognizer(pan)
        rotateOverlayView = overlay
        rotatePan = pan
    }

    @objc private func handleRotatePan(_ gr: UIPanGestureRecognizer) {
        // Ignore if gesture begins inside the bottomPanel to avoid fighting scroll interactions
        let location = gr.location(in: view)
        if bottomPanel.frame.contains(location) { return }
        // Also ignore drags that start on top buttons or color button
        if backButton.frame.contains(location) || saveButton.frame.contains(location) || colorButton.frame.contains(location) { return }

        switch gr.state {
        case .began:
            lastPanTranslationX = 0
        case .changed:
            let tx = gr.translation(in: view).x
            let delta = tx - lastPanTranslationX
            lastPanTranslationX = tx
            // Forward horizontal delta to Unity (as pixels)
            let message = String(format: "%.3f", delta)
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "RotateAvatar", message: message)
        default:
            break
        }
    }

}

