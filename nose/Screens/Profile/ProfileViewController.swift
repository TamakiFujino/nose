import UIKit

class ProfileViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)
        
        // set up UI
        // add a back button
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        backButton.tintColor = .black
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
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
            // set a back button at the top left
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // set a heading next to the back button left-aligned
            headingLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 20),
            headingLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            
            // set a setting button at the bottom right
            settingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)    
        ])
    }
    
    
    @objc func backButtonTapped() {
        dismiss(animated: true, completion: nil)
        // set background of button to none
        view.backgroundColor = .white
    }
    
    @objc func settingButtonTapped() {
        // go to setting page
        // let settingVC = SettingViewController()
        // present(settingVC, animated: true, completion: nil)
    }
}

