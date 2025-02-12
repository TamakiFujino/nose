import UIKit

class ProfileViewController: UIViewController {
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
        
        // add a setting icon button
        let settingButton = UIButton(type: .system)
        settingButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        settingButton.tintColor = .black
        settingButton.translatesAutoresizingMaskIntoConstraints = false
        settingButton.addTarget(self, action: #selector(settingButtonTapped), for: .touchUpInside)
        view.addSubview(settingButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // set a heading next to the back button left-aligned
            headingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headingLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // set a setting button at the bottom right
            settingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)    
        ])
    }
    
    @objc func settingButtonTapped() {
        let settingVC = SettingViewController()
        navigationController?.pushViewController(settingVC, animated: true)
    }
}

