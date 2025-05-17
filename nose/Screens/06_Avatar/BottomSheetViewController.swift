import UIKit

struct Model: Codable {
    let name: String
    let thumbnail: String
}

class BottomSheetContentView: UIView {

    weak var avatar3DViewController: Avatar3DViewController?

    private var parentTabBar: UISegmentedControl!
    private var childTabBar: UISegmentedControl!
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var models: [Model] = []
    private var selectedModels: [String: String] = [:]

    // Mappings for category to tab indices
    private static let categoryToParentTab: [String: Int] = [
        "skin": 0, "eye": 0, "eyebrow": 0, "nose": 0, "mouth": 0,
        "hair_base": 1, "hair_front": 1, "hair_back": 1,
        "tops": 2, "jackets": 2, "bottoms": 2, "socks": 2, "shoes": 2,
        "head": 3, "neck": 3, "eyewear": 3
    ]

    private static let categoryToChildTabInfo: [String: (parentIndex: Int, childIndex: Int)] = [
        "skin": (0, 0), "eye": (0, 1), "eyebrow": (0, 2), "nose": (0, 3), "mouth": (0, 4),
        "hair_base": (1, 0), "hair_front": (1, 1), "hair_back": (1, 2),
        "tops": (2, 0), "jackets": (2, 1), "bottoms": (2, 2), "socks": (2, 3), "shoes": (2, 4),
        "head": (3, 0), "neck": (3, 1), "eyewear": (3, 2)
    ]
    
    // Helper to get current category context based on tab selections
    private var currentCategoryContext: (name: String, parentIndex: Int, childIndex: Int)? {
        let parentIndex = parentTabBar.selectedSegmentIndex
        let childIndex = childTabBar.selectedSegmentIndex

        switch parentIndex {
        case 0: // Base
            let categories = ["skin", "eye", "eyebrow", "nose", "mouth"]
            guard childIndex < categories.count else { return nil }
            return (categories[childIndex], parentIndex, childIndex)
        case 1: // Hair
            let categories = ["hair_base", "hair_front", "hair_back"]
            guard childIndex < categories.count else { return nil }
            return (categories[childIndex], parentIndex, childIndex)
        case 2: // Clothes
            let categories = ["tops", "jackets", "bottoms", "socks", "shoes"]
            guard childIndex < categories.count else { return nil }
            return (categories[childIndex], parentIndex, childIndex)
        case 3: // Accessories
            let categories = ["head", "neck", "eyewear"]
            guard childIndex < categories.count else { return nil }
            return (categories[childIndex], parentIndex, childIndex)
        default:
            return nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        self.backgroundColor = .white
        self.layer.cornerRadius = 16
        self.clipsToBounds = true

        setupParentTabBar()
        setupChildTabBar()
        setupScrollView()
        setupContentView()

        // updateChildTabBar() was already called by setupChildTabBar.
        // Child tab is at index 0 for the current parent (due to updateChildTabBar).
        loadContentForSelectedTab() // Load content for this initial state.
    }

    private func setupParentTabBar() {
        let parentTabItems = ["Base", "Hair", "Clothes", "Accessories"]
        parentTabBar = UISegmentedControl(items: parentTabItems)
        parentTabBar.selectedSegmentIndex = 0
        parentTabBar.addTarget(self, action: #selector(parentTabChanged), for: .valueChanged)
        parentTabBar.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(parentTabBar)

        NSLayoutConstraint.activate([
            parentTabBar.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            parentTabBar.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            parentTabBar.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16)
        ])
    }

    private func setupChildTabBar() {
        childTabBar = UISegmentedControl() 
        childTabBar.selectedSegmentIndex = UISegmentedControl.noSegment 
        childTabBar.addTarget(self, action: #selector(childTabChanged), for: .valueChanged)
        childTabBar.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(childTabBar)
        updateChildTabBar() // Populate for the initially selected parent tab - THIS IS IMPORTANT HERE

        NSLayoutConstraint.activate([
            childTabBar.topAnchor.constraint(equalTo: parentTabBar.bottomAnchor, constant: 16),
            childTabBar.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            childTabBar.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16)
        ])
    }

    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: childTabBar.bottomAnchor, constant: 16),
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
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func loadModels(for category: String) {
        guard let url = Bundle.main.url(forResource: category, withExtension: "json") else {
            print("Failed to locate \(category).json in bundle.")
            models = [] // Clear models if JSON not found
            return
        }

        do {
            let data = try Data(contentsOf: url)
            models = try JSONDecoder().decode([Model].self, from: data)
        } catch {
            print("Failed to load or decode \(category).json: \(error)")
            models = [] // Clear models on error
        }
    }

    @objc private func parentTabChanged() {
        updateChildTabBar()       // Sets child segments and selectedIndex to 0
        loadContentForSelectedTab() // Explicitly load content after child tabs are updated
    }

    @objc private func childTabChanged() {
        loadContentForSelectedTab() // This is fine as is
    }

    private func updateChildTabBar() {
        let baseTabItems = ["Skin", "Eye", "Eyebrow", "Nose", "Mouth"]
        let hairTabItems = ["Base", "Front", "Back"]
        let clothesTabItems = ["Tops", "Jackets", "Bottoms", "Socks", "Shoes"]
        let accessoriesTabItems = ["Head", "Neck", "Eyewear"]

        let items: [String]
        switch parentTabBar.selectedSegmentIndex {
        case 0: items = baseTabItems
        case 1: items = hairTabItems
        case 2: items = clothesTabItems
        case 3: items = accessoriesTabItems
        default: items = []
        }

        childTabBar.removeAllSegments()
        for (index, item) in items.enumerated() {
            childTabBar.insertSegment(withTitle: item, at: index, animated: false)
        }
        
        if !items.isEmpty {
            childTabBar.selectedSegmentIndex = 0
            // REMOVED: loadContentForSelectedTab() 
        } else {
            // If no child tabs, clear content (or handle as appropriate)
            contentView?.subviews.forEach { $0.removeFromSuperview() } // Add optional chaining for contentView
            models = []
        }
    }

    private func loadContentForSelectedTab() {
        contentView.subviews.forEach { $0.removeFromSuperview() }

        guard let context = currentCategoryContext else {
            print("No valid category context for selected tabs.")
            models = [] // Clear models
            return
        }

        loadModels(for: context.name)
        setupThumbnails(for: context.name)
    }

    private func setupThumbnails(for category: String) {
        let padding: CGFloat = 10
        let buttonSize: CGFloat = (self.bounds.width - (padding * 5)) / 4
        guard buttonSize > 0 else { return } // Avoid division by zero or negative size

        var lastButton: UIButton?
        var currentConstraints = [NSLayoutConstraint]()

        for (index, model) in models.enumerated() {
            let row = index / 4
            let column = index % 4
            let xPosition = padding + CGFloat(column) * (buttonSize + padding)
            let yPosition = padding + CGFloat(row) * (buttonSize + padding)

            let thumbnailButton = UIButton(frame: CGRect(x: xPosition, y: yPosition, width: buttonSize, height: buttonSize))
            thumbnailButton.tag = index
            if let image = UIImage(named: model.thumbnail) {
                thumbnailButton.setImage(image, for: .normal)
            } else {
                thumbnailButton.setTitle(model.name.prefix(3).uppercased(), for: .normal) // Fallback text
                thumbnailButton.backgroundColor = .lightGray
            }
            thumbnailButton.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)
            contentView.addSubview(thumbnailButton)
            lastButton = thumbnailButton

            if let selectedModelName = selectedModels[category], selectedModelName == model.name {
                thumbnailButton.layer.borderColor = UIColor.blue.cgColor
                thumbnailButton.layer.borderWidth = 2
            } else {
                thumbnailButton.layer.borderColor = UIColor.clear.cgColor
                thumbnailButton.layer.borderWidth = 0
            }
        }
        
        // Ensure contentView's bottom anchor is constrained to the last button
        if let lastButton = lastButton {
            // Remove old bottom constraint if it exists to avoid conflicts
            contentView.constraints.filter { $0.firstAnchor == contentView.bottomAnchor }.forEach { $0.isActive = false }
            contentView.bottomAnchor.constraint(equalTo: lastButton.bottomAnchor, constant: padding).isActive = true
        } else {
             // If no buttons, ensure contentView has a minimal height or is constrained to top
            contentView.constraints.filter { $0.firstAnchor == contentView.bottomAnchor }.forEach { $0.isActive = false }
            contentView.heightAnchor.constraint(equalToConstant: 0).isActive = true // Or some other appropriate constraint
        }
    }

    @objc private func thumbnailTapped(_ sender: UIButton) {
        guard let context = currentCategoryContext else { return }
        let category = context.name
        
        guard sender.tag < models.count else { return } // Bounds check
        let model = models[sender.tag]

        if selectedModels[category] == model.name {
            selectedModels[category] = nil
            avatar3DViewController?.removeClothingItem(for: category)
        } else {
            selectedModels[category] = model.name
            avatar3DViewController?.loadClothingItem(named: model.name, category: category)
        }
        setupThumbnails(for: category) // Reload to update selection highlight
    }

    func changeSelectedCategoryColor(to color: UIColor) {
        guard let context = currentCategoryContext else { return }
        let category = context.name

        if category == "skin" {
            avatar3DViewController?.changeSkinColor(to: color)
        } else {
            avatar3DViewController?.changeClothingItemColor(for: category, to: color)
        }
    }

    // New method to synchronize selected models from Avatar3DViewController
    func syncSelectedModels(with chosenAvatarModels: [String: String]) {
        self.selectedModels = chosenAvatarModels
        // After syncing, if a category is currently displayed, refresh its thumbnails to show selection
        if let currentContext = currentCategoryContext {
            print("Syncing selected models. Refreshing thumbnails for category: \(currentContext.name)")
            // We need to ensure models for this category are loaded before setting up thumbnails
            // loadModels(for: currentContext.name) // This might be redundant if loadContentForSelectedTab was just called
            setupThumbnails(for: currentContext.name)
        }
    }

    func selectCategoryAndDisplayItems(named categoryName: String) {
        print("BottomSheetContentView: Attempting to select category: \(categoryName)")
        
        guard let tabInfo = BottomSheetContentView.categoryToChildTabInfo[categoryName.lowercased()] else {
            print("Error: Category '\(categoryName)' not found in mapping.")
            return
        }

        let targetParentIndex = tabInfo.parentIndex
        let targetChildIndex = tabInfo.childIndex

        if parentTabBar.selectedSegmentIndex != targetParentIndex {
            parentTabBar.selectedSegmentIndex = targetParentIndex
            updateChildTabBar() // This will also trigger a loadContentForSelectedTab for the default child (index 0)
        }

        // updateChildTabBar sets child to 0 and calls loadContent. If targetChildIndex is also 0, we are done.
        // If targetChildIndex is different, we need to select it and reload again.
        if childTabBar.numberOfSegments > targetChildIndex && childTabBar.selectedSegmentIndex != targetChildIndex {
            childTabBar.selectedSegmentIndex = targetChildIndex
            loadContentForSelectedTab() // Explicitly reload for the correct child tab
        } else if childTabBar.selectedSegmentIndex == targetChildIndex {
            // Parent might have changed, and child already at target (e.g. if target is 0)
            // loadContentForSelectedTab was already called by updateChildTabBar in this case.
            // Or, parent didn't change, and child was already correct.
            // If content isn't loaded, ensure it is.
            if contentView.subviews.isEmpty && models.isEmpty { // A simple check
                 loadContentForSelectedTab()
            }
        } else if childTabBar.numberOfSegments <= targetChildIndex {
             print("Error: Child tab index \(targetChildIndex) out of bounds for category '\(categoryName)'. Child segments: \(childTabBar.numberOfSegments)")
            if childTabBar.numberOfSegments > 0 && childTabBar.selectedSegmentIndex != 0 {
                childTabBar.selectedSegmentIndex = 0 
                loadContentForSelectedTab()
            } else if childTabBar.numberOfSegments > 0 && childTabBar.selectedSegmentIndex == 0 {
                // Already at 0, and updateChildTabBar should have loaded it.
                if contentView.subviews.isEmpty && models.isEmpty { // A simple check
                     loadContentForSelectedTab()
                }
            }
        }
        print("BottomSheetContentView: Selected parent tab \(parentTabBar.selectedSegmentIndex), child tab \(childTabBar.selectedSegmentIndex) for category \(categoryName)")
    }
}
