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
    
    private let baseTabItems = ["Skin", "Eye", "Eyebrow"]
    private let hairTabItems = ["Base", "Front", "Side", "Back"]
    private let clothesTabItems = ["Tops", "Bottoms", "Socks"]
    
    private let storage = Storage.storage()

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
        DispatchQueue.main.async {
            self.loadingOverlay.isHidden = false
            self.loadingIndicator.startAnimating()
        }
    }

    private func hideLoading() {
        DispatchQueue.main.async {
            self.loadingOverlay.isHidden = true
            self.loadingIndicator.stopAnimating()
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

            let jsonRef = storage.reference().child("avatar_assets/json/\(mainCategory).json")
            let maxSize: Int64 = 1 * 1024 * 1024 // 1MB max size
            let data = try await jsonRef.data(maxSize: maxSize)
            
            // Decode the dictionary with arrays
            let dict = try JSONDecoder().decode([String: [String]].self, from: data)
            
            // Get the subcategory name
            let subcategory: String
            switch category {
            case "skin": subcategory = "skin"
            case "eyes": subcategory = "eyes"
            case "eyebrows": subcategory = "eyebrows"
            case "hairbase": subcategory = "base"
            case "hairfront": subcategory = "front"
            case "hairside": subcategory = "side"
            case "hairback": subcategory = "back"
            case "tops": subcategory = "tops"
            case "bottoms": subcategory = "bottoms"
            case "socks": subcategory = "socks"
            default: subcategory = category
            }
            
            if let modelsArray = dict[subcategory] {
                let newModels = modelsArray.map { Model(name: $0) }
                await setModels(newModels)
                print("Successfully loaded models for category: \(category) from \(mainCategory).json")
            } else {
                print("No models found for subcategory: \(subcategory) in \(mainCategory).json")
                await setModels([])
            }
        } catch {
            print("Failed to load or decode \(category) from main category JSON: \(error)")
            await setModels([])
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
        
        // Use Task to handle async call
        Task {
            await loadModels(for: category)
            await setupThumbnails(for: category)
            hideLoading()
        }
    }

    private func setupThumbnails(for category: String) async {
        // Skip thumbnail setup for color-only categories
        if category == "skin" {
            return
        }

        let padding: CGFloat = 10
        let buttonSize: CGFloat = (bounds.width - (padding * 5)) / 4
        var lastButton: UIButton?

        let currentModels = await getModels()
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
            await MainActor.run {
                contentView.addSubview(thumbnailButton)
                lastButton = thumbnailButton
            }
        }

        if let lastButton = lastButton {
            await MainActor.run {
                contentView.bottomAnchor.constraint(equalTo: lastButton.bottomAnchor, constant: padding).isActive = true
            }
        }
    }

    private func createThumbnailButton(model: Model, index: Int, frame: CGRect, category: String) async -> UIButton {
        let button = UIButton(frame: frame)
        // Ensure index is valid before setting tag
        guard index >= 0 else {
            print("Invalid index for thumbnail button: \(index)")
            return button
        }
        button.tag = index
        
        // Set placeholder image immediately
        await MainActor.run {
            button.setImage(UIImage(systemName: "photo"), for: .normal)
            button.imageView?.contentMode = .scaleAspectFit
            button.tintColor = .gray
        }
        
        // Load thumbnail asynchronously
        do {
            let image = try await AvatarResourceManager.shared.loadThumbnail(for: model.name)
            await MainActor.run {
                button.setImage(image, for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
                button.tintColor = nil
            }
        } catch {
            print("Failed to load thumbnail for \(model.name): \(error)")
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
}
