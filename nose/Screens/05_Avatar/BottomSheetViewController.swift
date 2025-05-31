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
    
    let baseTabItems = ["Skin", "Eye", "Eyebrow"]
    let hairTabItems = ["Base", "Front", "Back"]
    let clothesTabItems = ["Tops", "Bottoms", "Socks"]

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
        loadModels(for: "base")
        loadContentForSelectedTab()
    }

    private func setupParentTabBar() {
        let parentTabItems = ["Base", "Hair", "Clothes"]
        parentTabBar = UISegmentedControl(items: parentTabItems)
        parentTabBar.selectedSegmentIndex = 0
        parentTabBar.addTarget(self, action: #selector(parentTabChanged), for: .valueChanged)
        parentTabBar.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(parentTabBar)

        // Set up constraints for the parent tab bar
        NSLayoutConstraint.activate([
            parentTabBar.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            parentTabBar.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            parentTabBar.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16)
        ])
    }

    private func setupChildTabBar() {
        childTabBar = UISegmentedControl(items: baseTabItems)
        childTabBar.selectedSegmentIndex = 0
        childTabBar.addTarget(self, action: #selector(childTabChanged), for: .valueChanged)
        childTabBar.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(childTabBar)

        // Set up constraints for the child tab bar
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

        // Set up constraints for the scroll view
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

        // Set up constraints for the content view
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
            return
        }

        do {
            let data = try Data(contentsOf: url)
            models = try JSONDecoder().decode([Model].self, from: data)
        } catch {
            print("Failed to load or decode \(category).json: \(error)")
        }
    }

    @objc private func parentTabChanged() {
        updateChildTabBar()
        loadContentForSelectedTab()
    }

    @objc private func childTabChanged() {
        loadContentForSelectedTab()
    }

    private func updateChildTabBar() {
        if parentTabBar.selectedSegmentIndex == 0 {
            childTabBar.removeAllSegments()
            for (index, item) in baseTabItems.enumerated() {
                childTabBar.insertSegment(withTitle: item, at: index, animated: false)
            }
        } else if parentTabBar.selectedSegmentIndex == 1 {
            childTabBar.removeAllSegments()
            for (index, item) in hairTabItems.enumerated() {
                childTabBar.insertSegment(withTitle: item, at: index, animated: false)
            }
        } else if parentTabBar.selectedSegmentIndex == 2 {
            childTabBar.removeAllSegments()
            for (index, item) in clothesTabItems.enumerated() {
                childTabBar.insertSegment(withTitle: item, at: index, animated: false)
            }
        }
        childTabBar.selectedSegmentIndex = 0
    }

    private func loadContentForSelectedTab() {
        // Remove all subviews from the content view
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let category: String
        switch parentTabBar.selectedSegmentIndex {
        case 0: // Base tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Skin tab
                category = "skin"
            case 1: // Eye tab
                category = "eye"
            case 2: // Eyebrow tab
                category = "eyebrow"
            default:
                return
            }
        case 1: // Hair tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Base tab
                category = "hair_base"
            case 1: // Front tab
                category = "hair_front"
            case 2: // Back tab
                category = "hair_back"
            default:
                return
            }
        case 2: // Clothes tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Tops tab
                category = "tops"
            case 1: // Jackets tab
                category = "bottoms"
            case 2: // Bottoms tab
                category = "socks"
            default:
                return
            }
        default:
            return
        }

        loadModels(for: category)
        setupThumbnails(for: category)
    }

    private func setupThumbnails(for category: String) {
        let padding: CGFloat = 10
        let buttonSize: CGFloat = (self.bounds.width - (padding * 5)) / 4 // Calculate button size to fit 4 per row with padding

        var lastButton: UIButton?

        for (index, model) in models.enumerated() {
            let row = index / 4
            let column = index % 4
            let xPosition = padding + CGFloat(column) * (buttonSize + padding)
            let yPosition = padding + CGFloat(row) * (buttonSize + padding)

            let thumbnailButton = UIButton(frame: CGRect(x: xPosition, y: yPosition, width: buttonSize, height: buttonSize))
            thumbnailButton.tag = index
            thumbnailButton.setImage(UIImage(named: model.thumbnail), for: .normal)
            thumbnailButton.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)
            contentView.addSubview(thumbnailButton)

            lastButton = thumbnailButton

            // Highlight the selected model
            if let selectedModel = selectedModels[category], selectedModel == model.name {
                thumbnailButton.layer.borderColor = UIColor.blue.cgColor
                thumbnailButton.layer.borderWidth = 2
            } else {
                thumbnailButton.layer.borderColor = UIColor.clear.cgColor
                thumbnailButton.layer.borderWidth = 0
            }
        }

        if let lastButton = lastButton {
            contentView.bottomAnchor.constraint(equalTo: lastButton.bottomAnchor, constant: padding).isActive = true
        }
    }

    @objc private func thumbnailTapped(_ sender: UIButton) {
        let category: String
        switch parentTabBar.selectedSegmentIndex {
        case 0: // Base tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Skin tab
                category = "skin"
            case 1: // Eye tab
                category = "eye"
            case 2: // Eyebrow tab
                category = "eyebrow"
            default:
                return
            }
        case 1: // Hair tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Base tab
                category = "hair_base"
            case 1: // Front tab
                category = "hair_front"
            case 2: // Back tab
                category = "hair_back"
            default:
                return
            }
        case 2: // Clothes tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Tops tab
                category = "tops"
            case 1: // Jackets tab
                category = "bottoms"
            case 2: // Bottoms tab
                category = "socks"
            default:
                return
            }
        default:
            return
        }

        let model = models[sender.tag]

        if selectedModels[category] == model.name {
            // Deselect the model if it is already selected
            selectedModels[category] = nil
            avatar3DViewController?.removeClothingItem(for: category)
        } else {
            // Select the model
            selectedModels[category] = model.name
            avatar3DViewController?.loadClothingItem(named: model.name, category: category)
        }

        // Reload thumbnails to update the selection highlight
        setupThumbnails(for: category)
    }

    func changeSelectedCategoryColor(to color: UIColor) {
        let category: String
        switch parentTabBar.selectedSegmentIndex {
        case 0: // Base tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Skin tab
                category = "skin"
            case 1: // Eye tab
                category = "eye"
            case 2: // Eyebrow tab
                category = "eyebrow"
            default:
                return
            }
        case 1: // Hair tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Base tab
                category = "hair_base"
            case 1: // Front tab
                category = "hair_front"
            case 2: // Back tab
                category = "hair_back"
            default:
                return
            }
        case 2: // Clothes tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Tops tab
                category = "tops"
            case 1: // Jackets tab
                category = "bottoms"
            case 2: // Bottoms tab
                category = "socks"
            default:
                return
            }
        default:
            return
        }

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
            case 0: // Skin tab
                return "skin"
            case 1: // Eye tab
                return "eye"
            case 2: // Eyebrow tab
                return "eyebrow"
            default:
                return ""
            }
        case 1: // Hair tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Base tab
                return "hair_base"
            case 1: // Front tab
                return "hair_front"
            case 2: // Back tab
                return "hair_back"
            default:
                return ""
            }
        case 2: // Clothes tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Tops tab
                return "tops"
            case 1: // Jackets tab
                return "bottoms"
            case 2: // Bottoms tab
                return "socks"
            default:
                return ""
            }
        default:
            return ""
        }
    }
}
