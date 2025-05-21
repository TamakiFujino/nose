import UIKit
import FirebaseAuth

class ProfileViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var friendsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "person.2.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(friendsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var tshirtButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "tshirt.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(tshirtButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Profile"
        
        // Add subviews
        view.addSubview(friendsButton)
        view.addSubview(tshirtButton)
        view.addSubview(settingsButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Friends button
            friendsButton.trailingAnchor.constraint(equalTo: tshirtButton.leadingAnchor, constant: -16),
            friendsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            friendsButton.widthAnchor.constraint(equalToConstant: 50),
            friendsButton.heightAnchor.constraint(equalToConstant: 50),
            
            // T-shirt button
            tshirtButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -16),
            tshirtButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            tshirtButton.widthAnchor.constraint(equalToConstant: 50),
            tshirtButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Settings button
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 50),
            settingsButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    @objc private func friendsButtonTapped() {
        let friendsVC = FriendsViewController()
        navigationController?.pushViewController(friendsVC, animated: true)
    }
    
    @objc private func tshirtButtonTapped() {
        // TODO: Implement t-shirt functionality
        print("T-shirt button tapped")
    }
    
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
}

