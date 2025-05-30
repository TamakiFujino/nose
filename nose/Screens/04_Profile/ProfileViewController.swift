import UIKit
import FirebaseAuth

class ProfileViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var friendsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "person.2.fill"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(friendsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
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
        view.addSubview(settingsButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Friends button
            friendsButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -16),
            friendsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            friendsButton.widthAnchor.constraint(equalToConstant: 50),
            friendsButton.heightAnchor.constraint(equalToConstant: 50),
            
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
    
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
}
