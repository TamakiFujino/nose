import UIKit

class ProfileViewController: UIViewController {
    
    private var settingButton: IconButton!
    private var friendButton: IconButton!
    private var avatarButton: IconButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the navigation bar title to "Profile"
        self.title = "Profile"
        
        // Hide the "Back" text in the back button
        let backButton = UIBarButtonItem()
            backButton.title = ""  // Hide the "Back" text
            self.navigationItem.backBarButtonItem = backButton
            self.navigationController?.navigationBar.tintColor = .black
        
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        
        // Set up UI
        // setting button
        settingButton = IconButton(image: UIImage(systemName: "gearshape.fill"),
                                  action: #selector(settingButtonTapped),
                                  target: self)
        view.addSubview(settingButton)
        
        // friend button same icon width as setting button
        friendButton = IconButton(image: UIImage(systemName: "person.badge.plus.fill"),
                                    action: #selector(friendButtonTapped),
                                    target: self)
        // set the same width as setting button
        view.addSubview(friendButton)
        
        // friend button same icon width as setting button
        avatarButton = IconButton(image: UIImage(systemName: "tshirt.fill"),
                                    action: #selector(avatarButtonTapped),
                                    target: self)
        // set the same width as setting button
        view.addSubview(avatarButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // set a setting button at the bottom right corner and friend button next left
            settingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            friendButton.trailingAnchor.constraint(equalTo: settingButton.leadingAnchor, constant: -20),
            friendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            avatarButton.trailingAnchor.constraint(equalTo: friendButton.leadingAnchor, constant: -20),
            avatarButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc func settingButtonTapped() {
        let settingVC = SettingViewController()
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    @objc func friendButtonTapped() {
        let friendListVC = FriendListViewController()
        navigationController?.pushViewController(friendListVC, animated: true)
    }
    
    @objc func avatarButtonTapped() {
        let avatarCustomVC = AvatarCustomViewController()
        navigationController?.pushViewController(avatarCustomVC, animated: true)
    }
}
