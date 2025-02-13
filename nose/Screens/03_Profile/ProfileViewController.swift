import UIKit

class ProfileViewController: UIViewController {
    
    private var settingButton: IconButton!
    private var friendButton: IconButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backButton = UIBarButtonItem()
            backButton.title = ""  // Hide the "Back" text
            self.navigationItem.backBarButtonItem = backButton
            self.navigationController?.navigationBar.tintColor = .black
        
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        
        // set up UI
        // add a heading
        let headingLabel = UILabel()
        headingLabel.text = "Profile"
        headingLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headingLabel)
        
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
        
        // Layout
        NSLayoutConstraint.activate([
            // set a heading next to the back button left-aligned
            headingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headingLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // set a setting button at the bottom right corner and friend button next left
            settingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            friendButton.trailingAnchor.constraint(equalTo: settingButton.leadingAnchor, constant: -20),
            friendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
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
}

