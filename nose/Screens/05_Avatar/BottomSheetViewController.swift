import UIKit
import FirebaseStorage

// MARK: - Model
struct Model: Codable {
    let name: String
}

class BottomSheetContentView: UIView {
    // MARK: - Properties
    weak var avatar3DViewController: Avatar3DViewController?

    private var parentTabBar: UISegmentedControl!
    private var childTabBar: UISegmentedControl!
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var models: [Model] = []
    private var selectedModels: [String: String] = [:]
    private let modelsQueue = DispatchQueue(label: "com.nose.modelsQueue", attributes: .concurrent)
    private var loadingIndicator: UIActivityIndicatorView!
    private var loadingOverlay: UIView!
    
    private let baseTabItems = ["Skin", "Eyes", "Eyebrows"]
    private let hairTabItems = ["Base", "Front", "Side", "Back"]
    private let clothesTabItems = ["Tops", "Bottoms", "Socks"]
    
    private let storage = Storage.storage()

    private var jsonCache: [String: [String: [String]]] = [:]  // Cache for JSON data
    private var thumbnailPrefetchQueue = DispatchQueue(label: "com.nose.thumbnailPrefetch", qos: .userInitiated)
    private var pendingThumbnailLoads: Set<String> = []
    private var thumbnailLoadSemaphore = DispatchSemaphore(value: 3)  // Limit concurrent thumbnail loads
    private var uiUpdateQueue = DispatchQueue(label: "com.nose.uiUpdate", qos: .userInteractive)
    private var pendingUIUpdates: [() -> Void] = []
    private var isProcessingUIUpdates = false

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        clipsToBounds = true

        setupParentTabBar()
        setupChildTabBar()
        setupScrollView()
        setupContentView()
        setupLoadingIndicator()
        
        // Use Task to handle async call
        Task {
            await loadModels(for: "base")
            loadContentForSelectedTab()
        }
    }

    private func setupParentTabBar() {
        let parentTabItems = ["Base", "Hair", "Clothes"]
        parentTabBar = UISegmentedControl(items: parentTabItems)
        parentTabBar.selectedSegmentIndex = 0
        parentTabBar.addTarget(self, action: #selector(parentTabChanged), for: .valueChanged)
        parentTabBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(parentTabBar)

        NSLayoutConstraint.activate([
            parentTabBar.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            parentTabBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            parentTabBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    private func setupChildTabBar() {
        childTabBar = UISegmentedControl(items: baseTabItems)
        childTabBar.selectedSegmentIndex = 0
        childTabBar.addTarget(self, action: #selector(childTabChanged), for: .valueChanged)
        childTabBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(childTabBar)

        NSLayoutConstraint.activate([
            childTabBar.topAnchor.constraint(equalTo: parentTabBar.bottomAnchor, constant: 16),
            childTabBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            childTabBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: childTabBar.bottomAnchor, constant: 16),
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
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupLoadingIndicator() {
        loadingOverlay = UIView()
        loadingOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        loadingOverlay.isHidden = true
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingOverlay)
        
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])
    }

    private func showLoading() {
        Task { @MainActor in
            loadingOverlay.isHidden = false
            loadingIndicator.startAnimating()
        }
    }

    private func hideLoading() {
        Task { @MainActor in
            loadingOverlay.isHidden = true
            loadingIndicator.stopAnimating()
        }
    }

    // MARK: - Data Loading
    private func loadModels(for category: String) async {
        // Skip loading models for color-only categories
        if category == "skin" {
            await setModels([])
            return
        }

        do {
            // Get the main category file name
            let mainCategory: String
            switch category {
            case "skin", "eyes", "eyebrows":
                mainCategory = "base"
            case "hairbase", "hairfront", "hairside", "hairback":
                mainCategory = "hair"
            case "tops", "bottoms", "socks":
                mainCategory = "clothes"
            default:
                print("Unknown category: \(category)")
                await setModels([])
                return
            }

            // Check cache first
            if let cachedData = jsonCache[mainCategory] {
                let subcategory = getSubcategory(for: category)
                if let modelsArray = cachedData[subcategory] {
                    let newModels = modelsArray.map { Model(name: $0) }
                    await setModels(newModels)
                    await preloadModelEntities(modelNames: modelsArray)
                    return
                }
            }

            // Download and cache if not in cache
            let jsonRef = storage.reference().child("avatar_assets/json/\(mainCategory).json")
            let maxSize: Int64 = 1 * 1024 * 1024 // 1MB max size
            let data = try await jsonRef.data(maxSize: maxSize)
            
            // Decode and cache the dictionary
            let dict = try JSONDecoder().decode([String: [String]].self, from: data)
            jsonCache[mainCategory] = dict
            
            // Get models for current subcategory
            let subcategory = getSubcategory(for: category)
            if let modelsArray = dict[subcategory] {
                let newModels = modelsArray.map { Model(name: $0) }
                await setModels(newModels)
                
                // ✅ Preload all models in this category
                await preloadModelEntities(modelNames: modelsArray)
                
                // ✅ Prefetch thumbnails as you already do
                await prefetchThumbnails(for: modelsArray.prefix(8))
            } else {
                print("No models found for subcategory: \(subcategory) in \(mainCategory).json")
                await setModels([])
            }
        } catch {
            print("Failed to load or decode \(category) from main category JSON: \(error)")
            await setModels([])
        }
    }

    private func getSubcategory(for category: String) -> String {
        switch category {
        case "skin": return "skin"
        case "eyes": return "eyes"
        case "eyebrows": return "eyebrows"
        case "hairbase": return "base"
        case "hairfront": return "front"
        case "hairside": return "side"
        case "hairback": return "back"
        case "tops": return "tops"
        case "bottoms": return "bottoms"
        case "socks": return "socks"
        default: return category
        }
    }
    
    private func preloadModelEntities(modelNames: [String]) async {
        for modelName in modelNames {
            Task {
                do {
                    _ = try await AvatarResourceManager.shared.loadModelEntity(named: modelName)
                } catch {
                    print("❌ Failed to preload model: \(modelName), error: \(error)")
                }
            }
        }
    }

    private func prefetchThumbnails(for models: ArraySlice<String>) async {
        for modelName in models {
            guard !pendingThumbnailLoads.contains(modelName) else { continue }
            pendingThumbnailLoads.insert(modelName)
            
            Task {
                thumbnailLoadSemaphore.wait()
                defer { thumbnailLoadSemaphore.signal() }
                
                do {
                    _ = try await AvatarResourceManager.shared.loadThumbnail(for: modelName)
                    pendingThumbnailLoads.remove(modelName)
                } catch {
                    print("Failed to prefetch thumbnail for \(modelName): \(error)")
                    pendingThumbnailLoads.remove(modelName)
                }
            }
        }
    }

    private func setModels(_ newModels: [Model]) async {
        await MainActor.run {
            models = newModels
        }
    }

    private func getModels() async -> [Model] {
        await MainActor.run {
            return models
        }
    }

    // MARK: - Actions
    @objc private func parentTabChanged() {
        updateChildTabBar()
        Task {
            await loadContentForSelectedTab()
        }
    }

    @objc private func childTabChanged() {
        Task {
            await loadContentForSelectedTab()
        }
    }

    private func updateChildTabBar() {
        let items: [String]
        switch parentTabBar.selectedSegmentIndex {
        case 0: items = baseTabItems
        case 1: items = hairTabItems
        case 2: items = clothesTabItems
        default: return
        }

        childTabBar.removeAllSegments()
        for (index, item) in items.enumerated() {
            childTabBar.insertSegment(withTitle: item, at: index, animated: false)
        }
        childTabBar.selectedSegmentIndex = 0
    }

    private func loadContentForSelectedTab() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        let category = getCurrentCategory()
        
        // Show loading indicator
        showLoading()
        
        // Use Task to handle async call with timeout
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try await withTimeout(seconds: 10) {
                    await self.loadModels(for: category)
                    await self.setupThumbnails(for: category)
                }
            } catch {
                print("Failed to load content: \(error)")
                // Ensure loading indicator is hidden even on error
                self.hideLoading()
            }
        }
    }

    private func setupThumbnails(for category: String) async {
        // Skip thumbnail setup for color-only categories
        if category == "skin" {
            hideLoading()
            return
        }

        let padding: CGFloat = 10
        let buttonSize: CGFloat = (bounds.width - (padding * 5)) / 4
        var lastButton: UIButton?
        var thumbnailButtons: [UIButton] = []

        let currentModels = await getModels()
        
        // Create all buttons first
        for (index, model) in currentModels.enumerated() {
            let row = index / 4
            let column = index % 4
            let xPosition = padding + CGFloat(column) * (buttonSize + padding)
            let yPosition = padding + CGFloat(row) * (buttonSize + padding)

            let thumbnailButton = await createThumbnailButton(
                model: model,
                index: index,
                frame: CGRect(x: xPosition, y: yPosition, width: buttonSize, height: buttonSize),
                category: category
            )
            thumbnailButtons.append(thumbnailButton)
        }

        // Batch UI updates
        await queueUIUpdate {
            // Remove existing views
            self.contentView.subviews.forEach { $0.removeFromSuperview() }
            
            // Add new buttons
            for button in thumbnailButtons {
                self.contentView.addSubview(button)
                lastButton = button
            }
            
            // Update content view size
            if let lastButton = lastButton {
                self.contentView.bottomAnchor.constraint(equalTo: lastButton.bottomAnchor, constant: padding).isActive = true
            }
        }
        
        // Hide loading indicator after setup is complete
        hideLoading()
    }

    private func queueUIUpdate(_ update: @escaping () -> Void) async {
        await MainActor.run {
            pendingUIUpdates.append(update)
            processUIUpdates()
        }
    }

    private func processUIUpdates() {
        guard !isProcessingUIUpdates else { return }
        isProcessingUIUpdates = true
        
        let updates = pendingUIUpdates
        pendingUIUpdates.removeAll()
        
        for update in updates {
            update()
        }
        
        isProcessingUIUpdates = false
        
        if !pendingUIUpdates.isEmpty {
            processUIUpdates()
        }
    }

    private func createThumbnailButton(model: Model, index: Int, frame: CGRect, category: String) async -> UIButton {
        let button = UIButton(frame: frame)
        button.tag = index
        
        // Set placeholder image immediately
        button.setImage(UIImage(systemName: "photo"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = .gray
        
        // Load thumbnail asynchronously with timeout
        Task {
            do {
                // Add timeout to thumbnail loading
                try await withTimeout(seconds: 5) {
                    let image = try await AvatarResourceManager.shared.loadThumbnail(for: model.name)
                    await MainActor.run {
                        button.setImage(image, for: .normal)
                        button.imageView?.contentMode = .scaleAspectFit
                        button.tintColor = nil
                    }
                }
            } catch {
                print("Failed to load thumbnail for \(model.name): \(error)")
                // Keep the placeholder image on error
            }
        }
        
        button.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)

        if let selectedModel = selectedModels[category], selectedModel == model.name {
            button.layer.borderColor = UIColor.fourthColor.cgColor
            button.layer.borderWidth = 2
        } else {
            button.layer.borderColor = UIColor.clear.cgColor
            button.layer.borderWidth = 0
        }

        return button
    }

    @objc private func thumbnailTapped(_ sender: UIButton) {
        let category = getCurrentCategory()
        
        Task {
            // Add bounds checking
            let currentModels = await getModels()
            guard sender.tag >= 0 && sender.tag < currentModels.count else {
                print("Invalid model index: \(sender.tag)")
                return
            }
            
            let model = currentModels[sender.tag]

            // Clear selection for all buttons in the current category
            await MainActor.run {
                contentView.subviews.forEach { view in
                    if let button = view as? UIButton {
                        button.layer.borderColor = UIColor.clear.cgColor
                        button.layer.borderWidth = 0
                    }
                }
            }

            if selectedModels[category] == model.name {
                // Deselect if tapping the same item
                selectedModels[category] = nil
                avatar3DViewController?.removeClothingItem(for: category)
            } else {
                // Select new item
                selectedModels[category] = model.name
                avatar3DViewController?.loadClothingItem(named: model.name, category: category)
                // Highlight the selected button
                await MainActor.run {
                    sender.layer.borderColor = UIColor.fourthColor.cgColor
                    sender.layer.borderWidth = 2
                }
            }
        }
    }

    // MARK: - Public Interface
    func changeSelectedCategoryColor(to color: UIColor) {
        let category = getCurrentCategory()
        // Call the efficient color change method on the 3D view controller
        if category == "skin" {
            avatar3DViewController?.changeSkinColor(to: color)
        } else {
            avatar3DViewController?.changeClothingItemColor(for: category, to: color)
        }
    }

    func getCurrentCategory() -> String {
        switch parentTabBar.selectedSegmentIndex {
        case 0: // Base tab
            switch childTabBar.selectedSegmentIndex {
            case 0: return "skin"
            case 1: return "eyes"
            case 2: return "eyebrows"
            default: return ""
            }
        case 1: // Hair tab
            switch childTabBar.selectedSegmentIndex {
            case 0: return "hairbase"
            case 1: return "hairfront"
            case 2: return "hairside"
            case 3: return "hairback"
            default: return ""
            }
        case 2: // Clothes tab
            switch childTabBar.selectedSegmentIndex {
            case 0: return "tops"
            case 1: return "bottoms"
            case 2: return "socks"
            default: return ""
            }
        default:
            return ""
        }
    }

    // MARK: - Timeout Helper
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "BottomSheetViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
