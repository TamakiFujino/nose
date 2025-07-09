import UIKit
import FirebaseStorage

// MARK: - Model
struct Model: Codable {
    let name: String
}

class AvatarPartSelectorView: UIView {
    // MARK: - Properties
    weak var avatar3DViewController: Avatar3DViewController?

    private var parentTabBar: UISegmentedControl!
    private var childTabBar: UISegmentedControl!
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var models: [Model] = []
    private var selectedModels: [String: String] = [:]
    private let modelsQueue = DispatchQueue(label: "com.nose.modelsQueue", attributes: .concurrent)
    
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
        
        // Wait for categories to be loaded before proceeding
        Task {
            // Wait for categories to be loaded
            if !DynamicCategoryManager.shared.isCategoriesLoaded() {
                do {
                    try await DynamicCategoryManager.shared.loadCategories()
                } catch {
                    print("Failed to load categories: \(error)")
                    // Continue with fallback categories
                }
            }
            
            // Update UI with loaded categories
            await MainActor.run {
                updateParentTabBar()
                // Only update child tab bar if parent tab bar was successfully updated
                if parentTabBar.numberOfSegments > 0 {
                    updateChildTabBar()
                }
            }
            
            let initialCategory = getCurrentCategory()
            await loadModels(for: initialCategory)
            loadContentForSelectedTab()
        }
    }

    private func setupParentTabBar() {
        // Initialize with empty items - will be updated when categories are loaded
        parentTabBar = UISegmentedControl(items: [])
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
        // Initialize with empty items - will be updated when categories are loaded
        childTabBar = UISegmentedControl(items: [])
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

    private func showLoading() {
        Task { @MainActor in
            LoadingView.shared.showOverlayLoading(on: self, backgroundColor: UIColor.black.withAlphaComponent(0.3))
        }
    }

    private func hideLoading() {
        Task { @MainActor in
            LoadingView.shared.hideOverlayLoading()
        }
    }

    // MARK: - Data Loading
    private func loadModels(for category: String) async {
        // Skip loading models for color-only categories
        if category == "skin" {
            await setModels([])
            hideLoading()
            return
        }

        do {
            // Use DynamicCategoryManager to get models
            let mainCategory = DynamicCategoryManager.shared.getParentCategory(for: category)
            guard !mainCategory.isEmpty else {
                print("Unknown category: \(category)")
                await setModels([])
                hideLoading()
                return
            }

            // Get models for the current category
            let modelsArray = DynamicCategoryManager.shared.getModels(for: mainCategory, subcategory: category)
            let newModels = modelsArray.map { Model(name: $0) }
            await setModels(newModels)
            
            // Preload all models in this category
            await preloadModelEntities(modelNames: modelsArray)
            
            // Prefetch thumbnails
            await prefetchThumbnails(for: modelsArray.prefix(8))
            
        } catch {
            print("Failed to load models for category \(category): \(error)")
            await setModels([])
            await MainActor.run {
                hideLoading()
            }
        }
    }

    private func preloadModelEntities(modelNames: [String]) async {
        // Create a task group to handle concurrent loading
        await withTaskGroup(of: Void.self) { group in
            for modelName in modelNames {
                group.addTask {
                    do {
                        _ = try await AvatarResourceManager.shared.loadModelEntity(named: modelName)
                    } catch {
                        print("❌ Failed to preload model: \(modelName), error: \(error)")
                    }
                }
            }
        }
    }

    private func prefetchThumbnails(for models: ArraySlice<String>) async {
        // Create a task group to handle concurrent loading
        await withTaskGroup(of: Void.self) { group in
            for modelName in models {
                guard !pendingThumbnailLoads.contains(modelName) else { continue }
                pendingThumbnailLoads.insert(modelName)
                
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        _ = try await AvatarResourceManager.shared.loadThumbnail(for: modelName)
                        self.pendingThumbnailLoads.remove(modelName)
                    } catch {
                        print("Failed to prefetch thumbnail for \(modelName): \(error)")
                        self.pendingThumbnailLoads.remove(modelName)
                    }
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
        // Only update child tab bar if parent tab bar has segments
        if parentTabBar.numberOfSegments > 0 {
            updateChildTabBar()
        }
        Task {
            await loadContentForSelectedTab()
        }
    }

    @objc private func childTabChanged() {
        Task {
            await loadContentForSelectedTab()
        }
    }

    private func updateParentTabBar() {
        guard DynamicCategoryManager.shared.isCategoriesLoaded() else {
            print("❌ Error: Categories not loaded, cannot update parent tab bar")
            return
        }
        
        let parentItems = DynamicCategoryManager.shared.getMainCategories()
        
        parentTabBar.removeAllSegments()
        for (index, item) in parentItems.enumerated() {
            let displayName = DynamicCategoryManager.shared.getDisplayName(for: item)
            parentTabBar.insertSegment(withTitle: displayName, at: index, animated: false)
        }
        parentTabBar.selectedSegmentIndex = 0
    }
    
    private func updateChildTabBar() {
        guard DynamicCategoryManager.shared.isCategoriesLoaded() else {
            print("❌ Error: Categories not loaded, cannot update child tab bar")
            return
        }
        
        let mainCategories = DynamicCategoryManager.shared.getMainCategories()
        
        // Ensure parent tab bar has segments and valid selection
        guard parentTabBar.numberOfSegments > 0 else {
            print("❌ Error: Parent tab bar has no segments")
            return
        }
        
        guard parentTabBar.selectedSegmentIndex >= 0 && parentTabBar.selectedSegmentIndex < mainCategories.count else {
            print("❌ Error: Invalid parent tab index: \(parentTabBar.selectedSegmentIndex), max: \(mainCategories.count)")
            return
        }
        
        let selectedMainCategory = mainCategories[parentTabBar.selectedSegmentIndex]
        let items = DynamicCategoryManager.shared.getSubcategories(for: selectedMainCategory)

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
            guard let self = self else { 
                hideLoading()
                return 
            }
            
            do {
                try await withTimeout(seconds: 10) {
                    await self.loadModels(for: category)
                    await self.setupThumbnails(for: category)
                }
            } catch {
                print("Failed to load content: \(error)")
                // Ensure loading indicator is hidden even on error
                await MainActor.run {
                    self.hideLoading()
                }
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
        await MainActor.run {
            hideLoading()
        }
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
                avatar3DViewController?.removeAvatarPart(for: category)
            } else {
                // Select new item
                selectedModels[category] = model.name
                avatar3DViewController?.loadAvatarPart(named: model.name, category: category)
                // Highlight the selected button
                await MainActor.run {
                    sender.layer.borderColor = UIColor.fourthColor.cgColor
                    sender.layer.borderWidth = 2
                }
            }
        }
    }

    // MARK: - Public Interface
    func syncWithAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        // Clear current selections
        selectedModels.removeAll()
        
        // Update selections from avatar data
        for (category, entry) in avatarData.selections {
            if let modelName = entry["model"] {
                selectedModels[category] = modelName
            }
        }
        
        // Refresh the current view to show selections
        Task {
            await loadContentForSelectedTab()
        }
    }
    
    func changeSelectedCategoryColor(to color: UIColor) {
        let category = getCurrentCategory()
        // Call the efficient color change method on the 3D view controller
        if category == "skin" {
            avatar3DViewController?.changeSkinColor(to: color)
        } else {
            avatar3DViewController?.changeAvatarPartColor(for: category, to: color)
        }
    }

    func getCurrentCategory() -> String {
        guard DynamicCategoryManager.shared.isCategoriesLoaded() else {
            print("❌ Error: Categories not loaded, cannot get current category")
            return ""
        }
        
        // Ensure tab bars have segments
        guard parentTabBar.numberOfSegments > 0 && childTabBar.numberOfSegments > 0 else {
            print("❌ Error: Tab bars have no segments")
            return ""
        }
        
        let mainCategories = DynamicCategoryManager.shared.getMainCategories()
        guard parentTabBar.selectedSegmentIndex >= 0 && parentTabBar.selectedSegmentIndex < mainCategories.count else {
            print("❌ Error: Invalid parent tab index: \(parentTabBar.selectedSegmentIndex), max: \(mainCategories.count)")
            return ""
        }
        
        let selectedMainCategory = mainCategories[parentTabBar.selectedSegmentIndex]
        let subcategories = DynamicCategoryManager.shared.getSubcategories(for: selectedMainCategory)
        
        guard childTabBar.selectedSegmentIndex >= 0 && childTabBar.selectedSegmentIndex < subcategories.count else {
            print("❌ Error: Invalid child tab index: \(childTabBar.selectedSegmentIndex), max: \(subcategories.count)")
            return ""
        }
        
        return subcategories[childTabBar.selectedSegmentIndex]
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

    private func removeCurrentModel(for category: String) {
        guard let avatar3DViewController = avatar3DViewController else { return }
        avatar3DViewController.removeAvatarPart(for: category)
    }
    
    private func applyColor(_ color: UIColor, to category: String) {
        guard let avatar3DViewController = avatar3DViewController else { return }
        if category == "skin" {
            avatar3DViewController.changeSkinColor(to: color)
        } else {
            avatar3DViewController.changeAvatarPartColor(for: category, to: color)
        }
    }
}
