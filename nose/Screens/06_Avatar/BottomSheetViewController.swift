import UIKit

class BottomSheetContentView: UIView {
    
    weak var avatar3DViewController: Avatar3DViewController?
    
    private var parentTabBar: UISegmentedControl!
    private var childTabBar: UISegmentedControl!
    private var contentView: UIView!
    
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
        setupContentView()
        loadContentForSelectedTab()
    }
    
    private func setupParentTabBar() {
        let parentTabItems = ["Base", "Clothes"]
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
        let baseTabItems = ["Skin", "Eye", "Eyebrow", "Nose", "Hair"]
        let clothesTabItems = ["Tops", "Bottoms", "Socks", "Shoes", "Accessories"]
        
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
    
    private func setupContentView() {
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(contentView)
        
        // Set up constraints for the content view
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: childTabBar.bottomAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    @objc private func parentTabChanged() {
        updateChildTabBar()
        loadContentForSelectedTab()
    }
    
    @objc private func childTabChanged() {
        loadContentForSelectedTab()
    }
    
    private func updateChildTabBar() {
        let baseTabItems = ["Skin", "Eye", "Eyebrow", "Nose", "Hair"]
        let clothesTabItems = ["Tops", "Bottoms", "Socks", "Shoes", "Accessories"]
        
        if parentTabBar.selectedSegmentIndex == 0 {
            childTabBar.removeAllSegments()
            for (index, item) in baseTabItems.enumerated() {
                childTabBar.insertSegment(withTitle: item, at: index, animated: false)
            }
        } else {
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
        
        switch parentTabBar.selectedSegmentIndex {
        case 0: // Base tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Skin tab
                setupSkinContent()
            case 1: // Eye tab
                setupEyeContent()
            case 2: // Eyebrow tab
                setupEyebrowContent()
            case 3: // Nose tab
                setupNoseContent()
            case 4: // Hair tab
                setupHairContent()
            default:
                break
            }
        case 1: // Clothes tab
            switch childTabBar.selectedSegmentIndex {
            case 0: // Tops tab
                setupTopsContent()
            case 1: // Bottoms tab
                setupBottomsContent()
            case 2: // Socks tab
                setupSocksContent()
            case 3: // Shoes tab
                setupShoesContent()
            case 4: // Accessories tab
                setupAccessoriesContent()
            default:
                break
            }
        default:
            break
        }
    }
    
    private func setupSkinContent() {
        // Add your code to set up the Skin content here
    }
    
    private func setupEyeContent() {
        // Add your code to set up the Eye content here
    }
    
    private func setupEyebrowContent() {
        // Add your code to set up the Eyebrow content here
    }
    
    private func setupNoseContent() {
        // Add your code to set up the Nose content here
    }
    
    private func setupHairContent() {
        // Add your code to set up the Hair content here
    }
    
    private func setupTopsContent() {
        // Add your code to set up the Tops content here
    }
    
    private func setupBottomsContent() {
        let bottomModels = ["bottom_1", "bottom_2", "bottom_3", "bottom_4"] // Add more as needed
        let padding: CGFloat = 10
        let buttonSize: CGFloat = (self.bounds.width - (padding * 5)) / 4 // Calculate button size to fit 4 per row with padding
        
        for (index, modelName) in bottomModels.enumerated() {
            let row = index / 4
            let column = index % 4
            let xPosition = padding + CGFloat(column) * (buttonSize + padding)
            let yPosition = padding + CGFloat(row) * (buttonSize + padding)
            
            let thumbnailButton = UIButton(frame: CGRect(x: xPosition, y: yPosition, width: buttonSize, height: buttonSize))
            thumbnailButton.tag = index
            thumbnailButton.setImage(UIImage(named: modelName), for: .normal) // Assuming thumbnails are named same as models
            thumbnailButton.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)
            contentView.addSubview(thumbnailButton)
        }
    }

    private func setupSocksContent() {
        // Add your code to set up the Socks content here
    }
    
    private func setupShoesContent() {
        // Add your code to set up the Shoes content here
    }
    
    private func setupAccessoriesContent() {
        // Add your code to set up the Accessories content here
    }
    
    @objc private func thumbnailTapped(_ sender: UIButton) {
        let bottomModels = ["bottom_1", "bottom_2", "bottom_3", "bottom_4"] // Add more as needed
        let modelName = bottomModels[sender.tag]
        avatar3DViewController?.loadClothingItem(named: modelName)
    }
}
