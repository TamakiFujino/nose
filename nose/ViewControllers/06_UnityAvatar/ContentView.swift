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
    
    private lazy var bottomPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        bottomPanel.addSubview(thumbnailStackView)
        
        // Create thumbnail rows
        createThumbnailRows()
        
        print("FloatingUIController: Added UI elements to view")
        
        // Position bottom panel to occupy 45% of bottom screen
        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomPanel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),
            
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
        // Create one row with 4 thumbnails that fill the width
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.spacing = 16
        rowStackView.distribution = .fillEqually
        
        for i in 0..<topOptionsCount {
            let thumbnailButton = createThumbnailButton(for: i)
            rowStackView.addArrangedSubview(thumbnailButton)
        }
        
        thumbnailStackView.addArrangedSubview(rowStackView)
    }
    
    private func createThumbnailButton(for index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        
        // Use system icons for each model
        let iconNames = ["tshirt", "person.crop.circle", "person.fill", "person.2.fill"]
        let iconName = iconNames[index]
        
        if let systemImage = UIImage(systemName: iconName) {
            button.setImage(systemImage, for: .normal)
            button.tintColor = .black // Changed to black for better contrast on white background
        }
        
        button.imageView?.contentMode = .scaleAspectFit
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1) // Light gray background
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
        print("🎯 Thumbnail \(newIndex + 1) tapped!")
        
        // Update selection
        currentTopIndex = newIndex
        updateThumbnailBorders()
        changeTopInUnity()
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
    
    private func changeTopInUnity() {
        print("Changing top to index: \(currentTopIndex)")
        UnityLauncher.shared().sendMessage(toUnity: "UnityBridge", method: "ChangeTop", message: "\(currentTopIndex)")
    }
}

// MARK: - Protocol for communication
protocol ContentViewControllerDelegate: AnyObject {
    // Add any methods needed for communication
}
