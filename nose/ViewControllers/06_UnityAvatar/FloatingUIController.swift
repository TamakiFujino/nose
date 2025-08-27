import UIKit
import FirebaseCore

class FloatingUIController: UIViewController {
    weak var delegate: ContentViewController?
    private var currentTopIndex = 0

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
    private var imageCache: NSCache<NSString, UIImage> = NSCache()

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
        stackView.distribution = .fillProportionally
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
            thumbnailStackView.topAnchor.constraint(equalTo: childCategoryStackView.bottomAnchor, constant: 10),
            thumbnailStackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomPanel.bottomAnchor, constant: -10)
        ])
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
        // Make the button square; width will be determined by row distribution
        button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
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
                        button.layer.borderColor = button.tag == currentTopIndex ? UIColor.fourthColor.cgColor : UIColor.clear.cgColor
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
        button.titleLabel?.font = isParent ? .systemFont(ofSize: 14, weight: .medium) : .systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .clear
        button.layer.cornerRadius = isParent ? 16 : 12
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        if !isParent {
            button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        } else {
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
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
                button.backgroundColor = index == selectedParentIndex ? .thirdColor : .clear
                button.layer.cornerRadius = 16
            }
        }
        for (index, subview) in childCategoryStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                button.layer.borderWidth = 0
                button.layer.borderColor = UIColor.clear.cgColor
                button.backgroundColor = index == selectedChildIndex ? .thirdColor : .clear
                button.layer.cornerRadius = 12
            }
        }
    }

    private func loadAssetData() {
        // Prefer loading from Addressables catalog on Hosting
        loadAssetsFromAddressablesCatalog { [weak self] in
            self?.updateThumbnailsForCategory()
        }
    }

    private func loadAssetsForCategory(_ category: String, completion: (() -> Void)? = nil) {
        // Try Firebase Hosting first
        if let baseURLString = hostingBaseURL(),
           let url = URL(string: baseURLString + "/assets_\(category.lowercased()).json") {
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("❌ Network error loading assets for \(category): \(error)")
                    self.loadAssetsFromBundle(category: category)
                    DispatchQueue.main.async { completion?() }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    print("❌ Invalid HTTP response for \(category): \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    self.loadAssetsFromBundle(category: category)
                    DispatchQueue.main.async { completion?() }
                    return
                }
                guard let data = data else {
                    print("❌ Empty data for \(category)")
                    self.loadAssetsFromBundle(category: category)
                    DispatchQueue.main.async { completion?() }
                    return
                }

                do {
                    let categoryAssets = try JSONDecoder().decode(CategoryAssets.self, from: data)
                    let mainCategory = categoryAssets.category
                    if self.assetData[mainCategory] == nil { self.assetData[mainCategory] = [:] }
                    for asset in categoryAssets.assets {
                        var existing = self.assetData[mainCategory]![asset.subcategory] ?? []
                        if !existing.contains(where: { $0.id == asset.id }) {
                            existing.append(asset)
                        }
                        self.assetData[mainCategory]![asset.subcategory] = existing
                    }
                } catch {
                    print("❌ JSON decode error for \(category): \(error)")
                    self.loadAssetsFromBundle(category: category)
                }
                DispatchQueue.main.async { completion?() }
            }
            task.resume()
            return
        }

        // Fallback to bundled JSON if hosting URL is not available
        loadAssetsFromBundle(category: category)
        completion?()
    }

    private func loadAssetsFromBundle(category: String) {
        guard let url = Bundle.main.url(forResource: "assets_\(category.lowercased())", withExtension: "json") else {
            print("Could not find bundled assets JSON for category: \(category)")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let categoryAssets = try JSONDecoder().decode(CategoryAssets.self, from: data)
            let mainCategory = categoryAssets.category
            if assetData[mainCategory] == nil { assetData[mainCategory] = [:] }
            for asset in categoryAssets.assets {
                var existing = assetData[mainCategory]![asset.subcategory] ?? []
                if !existing.contains(where: { $0.id == asset.id }) {
                    existing.append(asset)
                }
                assetData[mainCategory]![asset.subcategory] = existing
            }
        } catch {
            print("Error loading bundled assets for \(category): \(error)")
        }
    }

    private func refetchAssetsForSelectedCategory() {
        // Reload from Addressables catalog, then refresh UI for selected category
        loadAssetsFromAddressablesCatalog { [weak self] in
            self?.updateThumbnailsForCategory()
        }
    }

    private func addressablesCatalogURL() -> URL? {
        // Prefer explicit URL in Config.plist
        if let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
           let explicitURL = plistDict["AddressablesCatalogURL"] as? String,
           !explicitURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: explicitURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        // Default to Firebase Hosting base + standard iOS catalog path
        if let base = hostingBaseURL(), let url = URL(string: base + "/addressables/iOS/catalog_0.1.json") {
            return url
        }
        return nil
    }

    private func loadAssetsFromAddressablesCatalog(completion: @escaping () -> Void) {
        guard let url = addressablesCatalogURL() else {
            print("❌ Addressables catalog URL not available.")
            completion()
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { DispatchQueue.main.async { completion() } }
            if let error = error {
                print("❌ Failed to load addressables catalog: \(error)")
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("❌ Invalid HTTP response for catalog: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            guard let data = data else {
                print("❌ Empty catalog data")
                return
            }
            do {
                // Parse m_InternalIds as [String]
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let internalIds = json["m_InternalIds"] as? [String] else {
                    print("❌ Catalog format unexpected (m_InternalIds not found)")
                    return
                }
                self.rebuildAssetDataFromCatalog(internalIds: internalIds)
            } catch {
                print("❌ Catalog JSON parse error: \(error)")
            }
        }.resume()
    }

    private func rebuildAssetDataFromCatalog(internalIds: [String]) {
        var newAssetData: [String: [String: [AssetItem]]] = [:]
        let thumbsPrefix = "Assets/Thumbs/"
        let modelPrefix = "Assets/Models/"
        // Build a set for quick existence checks
        let allIdsSet = Set(internalIds)

        for id in internalIds where id.hasPrefix(thumbsPrefix) {
            // e.g., Assets/Thumbs/Clothes/Tops/01_tops_tight_short.jpg
            let relative = String(id.dropFirst(thumbsPrefix.count))
            let parts = relative.split(separator: "/").map(String.init)
            guard parts.count >= 3 else { continue }
            let category = parts[0]
            let subcategory = parts[1]
            let filename = parts[2]
            let nameWithExt = (filename as NSString).lastPathComponent
            let name = (nameWithExt as NSString).deletingPathExtension

            // Derive model internal id strictly under Assets/Models
            let suffix = "\(category)/\(subcategory)/\(name).prefab"
            let candidate = modelPrefix + suffix
            let modelPath: String = allIdsSet.contains(candidate) ? candidate : candidate

            // Compose remote thumbnail URL on Hosting under /Thumbs/
            guard let base = hostingBaseURL() else { continue }
            var thumbURL = URL(string: base)
            thumbURL?.appendPathComponent("Thumbs")
            thumbURL?.appendPathComponent(category)
            thumbURL?.appendPathComponent(subcategory)
            thumbURL?.appendPathComponent(nameWithExt)

            let item = AssetItem(
                id: "\(category)_\(subcategory)_\(name)",
                name: name,
                modelPath: modelPath,
                thumbnailPath: thumbURL?.absoluteString,
                category: category,
                subcategory: subcategory,
                isActive: true,
                metadata: nil
            )
            if newAssetData[category] == nil { newAssetData[category] = [:] }
            var list = newAssetData[category]![subcategory] ?? []
            // Avoid duplicates by id
            if !list.contains(where: { $0.id == item.id }) { list.append(item) }
            newAssetData[category]![subcategory] = list
        }

        DispatchQueue.main.async {
            self.assetData = newAssetData
        }
    }

    private func hostingBaseURL() -> String? {
        // 1) Prefer explicit base URL in Config.plist (key: FirebaseHostingBaseURL)
        if let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
           let explicitURL = plistDict["FirebaseHostingBaseURL"] as? String,
           !explicitURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2) Derive from Firebase project ID (https://{projectID}.web.app)
        if let projectID = FirebaseApp.app()?.options.projectID, !projectID.isEmpty {
            return "https://\(projectID).web.app"
        }

        // 3) No hosting base URL available
        return nil
    }

    private func resolvedThumbnailURL(for asset: AssetItem) -> URL? {
        guard let base = hostingBaseURL() else { return nil }
        // Compose: {base}/Thumbs/{Category}/{Subcategory}/{Name}.jpg
        // Use URLComponents to safely append path components
        var url = URL(string: base)
        url?.appendPathComponent("Thumbs")
        url?.appendPathComponent(asset.category)
        url?.appendPathComponent(asset.subcategory)
        url?.appendPathComponent("\(asset.name).jpg")
        return url
    }

    private func resolvedRemoteURL(from path: String) -> URL? {
        let lower = path.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: path)
        }
        // Treat as relative to hosting base (handle with or without leading slash)
        guard let base = hostingBaseURL() else { return nil }
        var url = URL(string: base)
        // Ensure no duplicate slashes
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for comp in trimmed.split(separator: "/") {
            url?.appendPathComponent(String(comp))
        }
        return url
    }

    private func thumbnailURLCandidates(from url: URL) -> [URL] {
        var candidates: [URL] = [url]
        let last = url.lastPathComponent.lowercased()
        if last.hasSuffix(".jpg") {
            let alt = url.deletingLastPathComponent().appendingPathComponent((url.lastPathComponent as NSString).deletingPathExtension + ".png")
            candidates.append(alt)
        } else if last.hasSuffix(".png") {
            let alt = url.deletingLastPathComponent().appendingPathComponent((url.lastPathComponent as NSString).deletingPathExtension + ".jpg")
            candidates.append(alt)
        } else {
            candidates.append(url.appendingPathExtension("jpg"))
            candidates.append(url.appendingPathExtension("png"))
        }
        return candidates
    }

    private func setRemoteImage(on button: UIButton, urls: [URL], index: Int) {
        let placeholder = UIImage(systemName: "photo")
        if button.image(for: .normal) == nil {
            button.setImage(placeholder, for: .normal)
            button.tintColor = .lightGray
        }
        // Cache check by first candidate URL key
        if let key = urls.first?.absoluteString as NSString?, let cached = imageCache.object(forKey: key) {
            button.setImage(cached, for: .normal)
            button.tintColor = .clear
            return
        }
        attemptFetch(urls: urls, at: 0, button: button, index: index)
    }

    private func attemptFetch(urls: [URL], at position: Int, button: UIButton, index: Int) {
        guard position < urls.count else { return }
        let url = urls[position]
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if error != nil || !(200...299).contains(httpCode) || data == nil {
                self?.attemptFetch(urls: urls, at: position + 1, button: button, index: index)
                return
            }
            if let data = data, let image = UIImage(data: data) {
                guard let self = self else { return }
                let normalized = self.normalizeImageForDisplay(image)
                if let key = urls.first?.absoluteString as NSString? {
                    self.imageCache.setObject(normalized, forKey: key)
                }
                DispatchQueue.main.async {
                    if button.tag == index {
                        button.setImage(normalized, for: .normal)
                        button.tintColor = .clear
                    }
                }
            }
        }.resume()
    }

    private func normalizeImageForDisplay(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }

    private func updateThumbnailsForCategory() {
        let parentCategory = parentCategories[selectedParentIndex]
        let childCategory = childCategories[selectedParentIndex][selectedChildIndex]
        currentAssets = assetData[parentCategory]?[childCategory] ?? []
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
