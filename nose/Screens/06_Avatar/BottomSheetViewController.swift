import UIKit

class BottomSheetContentView: UIView {
    
    weak var avatar3DViewController: Avatar3DViewController?
    
    private var tabBar: UISegmentedControl!
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
        
        setupTabBar()
        setupContentView()
        loadContentForSelectedTab()
    }
    
    private func setupTabBar() {
        let tabItems = ["Hair", "Tops", "Bottoms", "Socks", "Shoes"]
        tabBar = UISegmentedControl(items: tabItems)
        tabBar.selectedSegmentIndex = 2
        tabBar.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(tabBar)
        
        // Set up constraints for the tab bar
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            tabBar.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            tabBar.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupContentView() {
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(contentView)
        
        // Set up constraints for the content view
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    @objc private func tabChanged() {
        loadContentForSelectedTab()
    }
    
    private func loadContentForSelectedTab() {
        // Remove all subviews from the content view
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        switch tabBar.selectedSegmentIndex {
        case 2: // Bottoms tab
            setupBottomsContent()
        default:
            // Other tabs can be configured here
            break
        }
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

    @objc private func thumbnailTapped(_ sender: UIButton) {
        let bottomModels = ["bottom_1", "bottom_2", "bottom_3", "bottom_4"] // Add more as needed
        let modelName = bottomModels[sender.tag]
        avatar3DViewController?.loadClothingItem(named: modelName)
    }
}
