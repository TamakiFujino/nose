import UIKit
import RealityKit

class ProfileViewController: UIViewController {
    private var settingButton: IconButton!
    private var friendButton: IconButton!
    private var avatarButton: IconButton!
    private var avatar3DViewController: Avatar3DViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the navigation bar title to "Profile"
        self.title = "Profile"

        // Hide the "Back" text in the back button
        let backButton = UIBarButtonItem()
        backButton.title = ""  // Hide the "Back" text
        self.navigationItem.backBarButtonItem = backButton
        self.navigationController?.navigationBar.tintColor = .black

        // Add CustomGradientView as the background
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
        view.addSubview(friendButton)

        // avatar button same icon width as setting button
        avatarButton = IconButton(image: UIImage(systemName: "tshirt.fill"),
                                    action: #selector(avatarButtonTapped),
                                    target: self)
        view.addSubview(avatarButton)

        // Initialize and add the Avatar3DViewController
        avatar3DViewController = Avatar3DViewController()
        addChild(avatar3DViewController)
        view.addSubview(avatar3DViewController.view)
        avatar3DViewController.didMove(toParent: self)

        // Remove the background of the AR view
        avatar3DViewController.arView.backgroundColor = .clear

        // Layout
        avatar3DViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // set a setting button at the bottom right corner and friend button next left
            settingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            friendButton.trailingAnchor.constraint(equalTo: settingButton.leadingAnchor, constant: -20),
            friendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            avatarButton.trailingAnchor.constraint(equalTo: friendButton.leadingAnchor, constant: -20),
            avatarButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            // Layout for avatar3DViewController
            avatar3DViewController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatar3DViewController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            avatar3DViewController.view.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1),
            avatar3DViewController.view.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1)
        ])

        // Bring buttons to the front
        view.bringSubviewToFront(settingButton)
        view.bringSubviewToFront(friendButton)
        view.bringSubviewToFront(avatarButton)

        // Modify camera position and base entity, and apply skin color
        setupCustomCameraAndEntity()
        applySkinColor()
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

    private func setupCustomCameraAndEntity() {
        // Custom camera position for ProfileViewController
        let customCameraPosition = SIMD3<Float>(0.0, -0.5, 10)

        DispatchQueue.main.async {
            self.avatar3DViewController.setupCameraPosition(position: customCameraPosition)
        }

        // Customize baseEntity if needed
        self.avatar3DViewController.baseEntity?.transform.rotation = simd_quatf(angle: .pi / 4, axis: [0, -0.4, 0])
    }

    private func applySkinColor() {
        // Apply the skin color from avatar3DViewController
        if let skinColor = avatar3DViewController.skinColor {
            avatar3DViewController.changeSkinColor(to: skinColor)
        }
    }
}
