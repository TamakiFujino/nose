//
//  ContentViewController.swift
//  UaaLHostFinal
//
//  Created by Momin Aman on 8/9/25.
//

import UIKit

class ContentViewController: UIViewController {
    
    private var currentTopIndex = 0
    private var topOptionsCount = 0
    private var floatingWindow: UIWindow?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Launch Unity immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.launchUnityAndCreateFloatingUI()
        }
    }
    
    private func launchUnityAndCreateFloatingUI() {
        print("Launching Unity...")
        UnityLauncher.shared().launchUnityIfNeeded()
        
        // Create floating UI after Unity launches
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.createFloatingUI()
        }
    }
    
    private func createFloatingUI() {
        print("Creating floating UI...")
        
        // Create a new window for the floating UI
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("Failed to get window scene")
            return
        }
        floatingWindow = UIWindow(windowScene: windowScene)
        
        guard let floatingWindow = floatingWindow else {
            print("Failed to create floating window")
            return
        }
        
        // Create the floating UI view controller
        let floatingVC = FloatingUIController()
        floatingVC.delegate = self
        floatingWindow.rootViewController = floatingVC
        
        // Position the floating window
        floatingWindow.frame = UIScreen.main.bounds
        floatingWindow.windowLevel = .alert + 1 // Ensure it's above Unity
        
        // Make it visible
        floatingWindow.isHidden = false
        floatingWindow.makeKeyAndVisible()
        
        print("Floating UI created and should be visible")
    }
}

// MARK: - Floating UI Controller
class FloatingUIController: UIViewController {
    
    weak var delegate: ContentViewController?
    private var currentTopIndex = 0
    private var topOptionsCount = 3
    
    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("← Previous", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(previousTopTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Next →", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(nextTopTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var currentTopLabel: UILabel = {
        let label = UILabel()
        label.text = "Current: Top 1"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear // Transparent background
        
        // Add UI elements
        view.addSubview(previousButton)
        view.addSubview(nextButton)
        view.addSubview(currentTopLabel)
        
        // Position in top-right corner
        NSLayoutConstraint.activate([
            previousButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            previousButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            previousButton.widthAnchor.constraint(equalToConstant: 120),
            previousButton.heightAnchor.constraint(equalToConstant: 44),
            
            nextButton.topAnchor.constraint(equalTo: previousButton.bottomAnchor, constant: 12),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.widthAnchor.constraint(equalToConstant: 120),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
            
            currentTopLabel.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 12),
            currentTopLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            currentTopLabel.widthAnchor.constraint(equalToConstant: 120),
            currentTopLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        print("Floating UI setup complete")
    }
    
    @objc private func previousTopTapped() {
        print("🎯 Previous button tapped!")
        currentTopIndex = (currentTopIndex - 1 + topOptionsCount) % topOptionsCount
        updateTopSelection()
        changeTopInUnity()
    }
    
    @objc private func nextTopTapped() {
        print("🎯 Next button tapped!")
        currentTopIndex = (currentTopIndex + 1) % topOptionsCount
        updateTopSelection()
        changeTopInUnity()
    }
    
    private func updateTopSelection() {
        currentTopLabel.text = "Current: Top \(currentTopIndex + 1)"
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
