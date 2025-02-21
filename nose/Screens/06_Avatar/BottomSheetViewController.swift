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
        tabBar.selectedSegmentIndex = 0
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
        let changeShirtButton = UIButton(frame: CGRect(x: 20, y: 20, width: 150, height: 50))
        changeShirtButton.setTitle("Change Bottom", for: .normal)
        changeShirtButton.backgroundColor = .systemBlue
        changeShirtButton.addTarget(self, action: #selector(changeBottom), for: .touchUpInside)
        contentView.addSubview(changeShirtButton)
    }

    @objc private func changeBottom() {
        avatar3DViewController?.loadClothingItem(named: "bottom_2") // Swap to new bottom model
    }
}
