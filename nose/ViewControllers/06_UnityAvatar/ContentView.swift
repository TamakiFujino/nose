//
//  ContentViewController.swift
//  UaaLHostFinal
//
//  Created by Momin Aman on 8/9/25.
//

import UIKit

class ContentViewController: UIViewController, ContentViewControllerDelegate {
    
    private var currentTopIndex = 0
    private var topOptionsCount = 3
    private var floatingWindow: UIWindow? // Add this property
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Launch Unity immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.launchUnity()
        }
    }
    
    private func launchUnity() {
        print("Launching Unity...")
        UnityLauncher.shared().launchUnityIfNeeded()
        
        // Wait for Unity to be ready, then create floating UI on top
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.createFloatingUI()
        }
    }
    
    private func createFloatingUI() {
        print("Creating floating UI on top of Unity...")
        
        // Create a new window for the floating UI that will be on top of Unity
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("Failed to get window scene")
            return
        }
        
        // Store the floating window in the property so it doesn't get deallocated
        floatingWindow = UIWindow(windowScene: windowScene)
        
        guard let floatingWindow = floatingWindow else {
            print("Failed to create floating window")
            return
        }
        
        // Create the floating UI view controller
        let floatingVC = FloatingUIController()
        floatingVC.delegate = self
        floatingWindow.rootViewController = floatingVC
        
        // Position the floating window to cover the entire screen
        floatingWindow.frame = UIScreen.main.bounds
        floatingWindow.windowLevel = .alert + 1 // Ensure it's above Unity
        
        // Make it visible
        floatingWindow.isHidden = false
        floatingWindow.makeKeyAndVisible()
        
        print("Floating UI created and should be visible on top of Unity")
        print("Window frame: \(floatingWindow.frame)")
        print("Window level: \(floatingWindow.windowLevel)")
        print("Window is hidden: \(floatingWindow.isHidden)")
        print("Window is key window: \(floatingWindow.isKeyWindow)")
    }
}

// MARK: - Floating UI Controller
class FloatingUIController: UIViewController {
    
    weak var delegate: ContentViewController?
    private var currentTopIndex = 0
    private var topOptionsCount = 4
    
    // Category data
    private let parentCategories = ["Base", "Hair", "Clothes", "Accessories"]
    private let childCategories = [
        ["Eye", "Eyebrow", "Body"],           // Base
        ["Base", "Front", "Side", "Back"],    // Hair
        ["Tops", "Bottoms", "Jacket", "Socks"], // Clothes
        ["Headwear", "Eyewear", "Neckwear"]   // Accessories
    ]
    
    private var selectedParentIndex = 0
    private var selectedChildIndex = 0
    
    // Asset management
    private var assetData: [String: [String: [AssetItem]]] = [:]
    private var currentAssets: [AssetItem] = []
    
    // MARK: - Asset Models
    struct AssetItem: Codable {
        let id: String
        let name: String
        let modelPath: String
        let thumbnailPath: String?
        let category: String
        let subcategory: String
        let isActive: Bool
        let metadata: [String: String]?
        
        enum CodingKeys: String, CodingKey {
            case id, name, modelPath, thumbnailPath, category, subcategory, isActive, metadata
        }
    }
    
    struct CategoryAssets: Codable {
        let category: String
        let subcategory: String
        let assets: [AssetItem]
    }
    
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
        stackView.distribution = .fillEqually
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
        print("FloatingUIController: viewDidLayoutSubviews called")
        print("FloatingUIController: View bounds: \(view.bounds)")
        
        // Force layout update
        view.layoutIfNeeded()
    }
    
    private func setupUI() {
        print("FloatingUIController: setupUI called")
        view.backgroundColor = .clear // Transparent background
        
        // Add UI elements
        view.addSubview(bottomPanel)
        bottomPanel.addSubview(parentCategoryStackView)
        bottomPanel.addSubview(childCategoryStackView)
        bottomPanel.addSubview(thumbnailStackView)
        
        // Create thumbnail rows
        createThumbnailRows()
        
        // Create category buttons
        createCategoryButtons()
        
        print("FloatingUIController: Added UI elements to view")
        
        // Position bottom panel to occupy 45% of bottom screen
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
            thumbnailStackView.centerYAnchor.constraint(equalTo: bottomPanel.centerYAnchor)
        ])
        
        print("FloatingUIController: Constraints activated")
        
        // Force immediate layout to ensure frames are set correctly
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        print("FloatingUIController: View frame after layout: \(view.frame)")
        print("FloatingUIController: Bottom panel frame after layout: \(bottomPanel.frame)")
        print("FloatingUIController: Thumbnail stack frame after layout: \(thumbnailStackView.frame)")
        
        print("Floating UI setup complete")
    }
    
    private func createThumbnailRows() {
        // Create one row with thumbnails that fill the width
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.spacing = 16
        rowStackView.distribution = .fillEqually
        
        for i in 0..<currentAssets.count {
            let thumbnailButton = createThumbnailButton(for: i)
            rowStackView.addArrangedSubview(thumbnailButton)
        }
        
        thumbnailStackView.addArrangedSubview(rowStackView)
    }
    
    private func createThumbnailButton(for index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        
        let asset = currentAssets[index]
        
        // Try to load thumbnail image if available
        if let thumbnailPath = asset.thumbnailPath,
           let thumbnailImage = UIImage(contentsOfFile: thumbnailPath) {
            button.setImage(thumbnailImage, for: .normal)
        } else {
            // Fallback to system icon based on category
            let iconNames = ["tshirt", "person.crop.circle", "person.fill", "person.2.fill"]
            let iconIndex = index % iconNames.count
            let iconName = iconNames[iconIndex]
            
            if let systemImage = UIImage(systemName: iconName) {
                button.setImage(systemImage, for: .normal)
                button.tintColor = .black
            }
        }
        
        button.imageView?.contentMode = .scaleAspectFit
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = index == currentTopIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(thumbnailTapped(_:)), for: .touchUpInside)
        
        // Set both width and height to make perfect squares
        button.widthAnchor.constraint(equalToConstant: 80).isActive = true
        button.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        return button
    }
    
    private func createPlaceholderImage(color: UIColor, size: CGSize) -> UIImage {
        // This method is no longer needed but keeping for compatibility
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    @objc private func thumbnailTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        let asset = currentAssets[newIndex]
        print("🎯 Thumbnail tapped: \(asset.name) (ID: \(asset.id))")
        
        // Update selection
        currentTopIndex = newIndex
        updateThumbnailBorders()
        changeAssetInUnity(asset: asset)
    }
    
    private func updateThumbnailBorders() {
        // Update all thumbnail borders
        for subview in thumbnailStackView.arrangedSubviews {
            if let rowStackView = subview as? UIStackView {
                for arrangedSubview in rowStackView.arrangedSubviews {
                    if let button = arrangedSubview as? UIButton {
                        button.layer.borderColor = button.tag == currentTopIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                    }
                }
            }
        }
    }
    
    private func changeAssetInUnity(asset: AssetItem) {
        print("Changing asset in Unity: \(asset.name) (ID: \(asset.id))")
        
        // Send asset information to Unity
        let assetInfo = [
            "id": asset.id,
            "name": asset.name,
            "modelPath": asset.modelPath,
            "category": asset.category,
            "subcategory": asset.subcategory
        ]
        
        // Convert to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: assetInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ChangeAsset", message: jsonString)
        }
    }
    
    private func createCategoryButtons() {
        // Create parent category buttons
        for (index, title) in parentCategories.enumerated() {
            let button = createCategoryButton(title: title, tag: index, isParent: true)
            parentCategoryStackView.addArrangedSubview(button)
        }
        
        // Create child category buttons for the first parent
        updateChildCategories()
    }
    
    private func createCategoryButton(title: String, tag: Int, isParent: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = tag
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        
        if isParent {
            button.addTarget(self, action: #selector(parentCategoryTapped(_:)), for: .touchUpInside)
        } else {
            button.addTarget(self, action: #selector(childCategoryTapped(_:)), for: .touchUpInside)
        }
        
        return button
    }
    
    private func updateChildCategories() {
        // Remove existing child category buttons
        childCategoryStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Create new child category buttons
        let currentChildCategories = childCategories[selectedParentIndex]
        for (index, title) in currentChildCategories.enumerated() {
            let button = createCategoryButton(title: title, tag: index, isParent: false)
            childCategoryStackView.addArrangedSubview(button)
        }
        
        // Reset child selection
        selectedChildIndex = 0
        updateCategoryButtonStates()
        updateThumbnailsForCategory()
    }
    
    private func updateCategoryButtonStates() {
        // Update parent category button states
        for (index, subview) in parentCategoryStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                button.layer.borderColor = index == selectedParentIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                button.backgroundColor = index == selectedParentIndex ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.black.withAlphaComponent(0.1)
            }
        }
        
        // Update child category button states
        for (index, subview) in childCategoryStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                button.layer.borderColor = index == selectedChildIndex ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                button.backgroundColor = index == selectedChildIndex ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.black.withAlphaComponent(0.1)
            }
        }
    }
    
    @objc private func parentCategoryTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        print("🎯 Parent category tapped: \(parentCategories[newIndex])")
        
        selectedParentIndex = newIndex
        updateChildCategories()
    }
    
    @objc private func childCategoryTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        print("🎯 Child category tapped: \(childCategories[selectedParentIndex][newIndex])")
        
        selectedChildIndex = newIndex
        updateCategoryButtonStates()
        updateThumbnailsForCategory()
    }
    
    private func loadAssetData() {
        // Load asset data from JSON files
        loadAssetsForCategory("Base")
        loadAssetsForCategory("Hair")
        loadAssetsForCategory("Clothes_Tops")      // Clothes - Tops subcategory
        loadAssetsForCategory("Clothes_Socks")     // Clothes - Socks subcategory
        loadAssetsForCategory("Accessories")
        
        print("Asset data loaded: \(assetData)")
    }
    
    private func loadAssetsForCategory(_ category: String) {
        guard let url = Bundle.main.url(forResource: "assets_\(category.lowercased())", withExtension: "json") else {
            print("Could not find assets JSON for category: \(category)")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let categoryAssets = try JSONDecoder().decode(CategoryAssets.self, from: data)
            
            // Extract the main category name (e.g., "Clothes" from "Clothes_Tops")
            let mainCategory = categoryAssets.category
            
            // Organize assets by subcategory under the main category
            if assetData[mainCategory] == nil {
                assetData[mainCategory] = [:]
            }
            
            for asset in categoryAssets.assets {
                if assetData[mainCategory]![asset.subcategory] == nil {
                    assetData[mainCategory]![asset.subcategory] = []
                }
                assetData[mainCategory]![asset.subcategory]?.append(asset)
            }
            
            print("Loaded \(categoryAssets.assets.count) assets for \(mainCategory) - \(categoryAssets.subcategory)")
            
        } catch {
            print("Error loading assets for \(category): \(error)")
        }
    }
    
    private func updateThumbnailsForCategory() {
        let parentCategory = parentCategories[selectedParentIndex]
        let childCategory = childCategories[selectedParentIndex][selectedChildIndex]
        
        print("Updating thumbnails for: \(parentCategory) - \(childCategory)")
        
        // Get assets for the selected category combination
        currentAssets = assetData[parentCategory]?[childCategory] ?? []
        topOptionsCount = currentAssets.count
        
        // Update thumbnail display
        updateThumbnailDisplay()
    }
    
    private func updateThumbnailDisplay() {
        // Remove existing thumbnails
        thumbnailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Create new thumbnails based on current assets
        if !currentAssets.isEmpty {
            createThumbnailRows()
        } else {
            // Show "No assets available" message
            let noAssetsLabel = UILabel()
            noAssetsLabel.text = "No assets available"
            noAssetsLabel.textAlignment = .center
            noAssetsLabel.textColor = .black
            noAssetsLabel.font = .systemFont(ofSize: 16, weight: .medium)
            noAssetsLabel.translatesAutoresizingMaskIntoConstraints = false
            
            thumbnailStackView.addArrangedSubview(noAssetsLabel)
        }
        
        // Reset selection
        currentTopIndex = 0
        updateThumbnailBorders()
    }
}

// MARK: - Protocol for communication
protocol ContentViewControllerDelegate: AnyObject {
    // Add any methods needed for communication
}
