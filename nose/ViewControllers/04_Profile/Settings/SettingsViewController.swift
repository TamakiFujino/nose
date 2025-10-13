import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // Avatar image view for profile picture
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondColor
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    // Define setting categories and items
    var settingsData: [(category: String, items: [String])] = [
        ("Profile", ["Name", "Account"]),
        ("Friends", ["Friend List", "Add Friend"]),
        ("About", ["Privacy Policy", "Terms of Service", "App Version", "Licenses"])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .firstColor

        // Set up navigation bar
        setupNavigationBar()

        setupTableView()
        setupAvatarHeader()
        loadProfileImage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload profile image when returning from ProfileImageViewController
        loadProfileImage()
    }

    private func setupNavigationBar() {
        navigationItem.title = "Settings"
        self.navigationController?.navigationBar.tintColor = .sixthColor
        
        // Remove any existing right bar button items
        navigationItem.rightBarButtonItems = nil
        navigationItem.rightBarButtonItem = nil
    }

    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "versionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear // Remove the background color
        view.addSubview(tableView)

        // Constraints for TableView
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupAvatarHeader() {
        // Create a container view for the header
        let avatarWidth = UIScreen.main.bounds.width * 0.75 // Same as ProfileImageViewController
        let avatarHeight = avatarWidth * 1.5
        let headerHeight = avatarHeight + 32 // Add padding top and bottom
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: headerHeight))
        headerView.backgroundColor = .clear
        
        // Add avatar image view to header
        avatarImageView.frame = CGRect(
            x: (UIScreen.main.bounds.width - avatarWidth) / 2,
            y: 16,
            width: avatarWidth,
            height: avatarHeight
        )
        headerView.addSubview(avatarImageView)
        
        // Add tap gesture to navigate to ProfileImageViewController
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarImageView.addGestureRecognizer(tapGesture)
        
        // Set as table header view
        tableView.tableHeaderView = headerView
    }
    
    @objc private func avatarTapped() {
        print("🖼️ Avatar tapped - navigating to ProfileImageViewController")
        let profileImageVC = ProfileImageViewController()
        
        // Set callback to receive selected image
        profileImageVC.onImageSelected = { [weak self] selectedImage in
            self?.avatarImageView.image = selectedImage
        }
        
        navigationController?.pushViewController(profileImageVC, animated: true)
    }
    
    private func loadProfileImage() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            showDefaultAvatar()
            return
        }
        
        print("🔍 Loading saved profile image for user: \(userId)")
        
        // Get the saved profile image collection ID from Firestore
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user data: \(error.localizedDescription)")
                    self.showDefaultAvatar()
                    return
                }
                
                guard let data = snapshot?.data(),
                      let collectionId = data["profileImageCollectionId"] as? String else {
                    print("⚠️ No profile image set, showing default")
                    self.showDefaultAvatar()
                    return
                }
                
                print("✅ Found profile image collection ID: \(collectionId)")
                
                if collectionId == "default" {
                    self.showDefaultAvatar()
                } else {
                    self.loadImageFromStorage(userId: userId, collectionId: collectionId)
                }
            }
    }
    
    private func showDefaultAvatar() {
        if let defaultImage = UIImage(named: "avatar") {
            DispatchQueue.main.async {
                self.avatarImageView.image = defaultImage
            }
            print("✅ Showing default avatar")
        } else {
            print("❌ Could not load default avatar image")
        }
    }
    
    private func loadImageFromStorage(userId: String, collectionId: String) {
        let imageRef = storage.reference()
            .child("collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        print("🔍 Loading image from: collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        imageRef.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("❌ Error loading profile image: \(error.localizedDescription)")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("✅ Successfully loaded profile image")
                DispatchQueue.main.async {
                    self?.avatarImageView.image = image
                }
            } else {
                print("❌ Could not create image from data")
            }
        }
    }

    // MARK: - TableView DataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return settingsData.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsData[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = settingsData[indexPath.section].items[indexPath.row]
        let cell: UITableViewCell

        if item == "App Version" {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "versionCell")
            cell.textLabel?.text = item
            
            // Get version and build number
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            let fullVersion = "\(version) (\(build))"
            
            print("DEBUG: App version info:")
            print("  - Version: \(version)")
            print("  - Build: \(build)")
            print("  - Full version: \(fullVersion)")
            print("  - Bundle identifier: \(Bundle.main.bundleIdentifier ?? "Unknown")")
            print("  - Info dictionary keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "None")")
            
            cell.detailTextLabel?.text = fullVersion
            cell.detailTextLabel?.textColor = .fourthColor
            cell.detailTextLabel?.accessibilityIdentifier = "app_version_text"
            cell.selectionStyle = .none  // Disable selection for app version cell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = item
            cell.accessoryType = .disclosureIndicator  // Add arrow to indicate navigation
        }

        cell.backgroundColor = .clear // Remove the background color of each cell
        return cell
    }

    // Set section headers
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return settingsData[section].category
    }

    // Handle selection of a setting option
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedSetting = settingsData[indexPath.section].items[indexPath.row]

        if selectedSetting == "Name" {
            let nameupdateVC = EditNameViewController()
            navigationController?.pushViewController(nameupdateVC, animated: true)
        } else if selectedSetting == "Account" {
            let accountVC = AccountViewController()
            navigationController?.pushViewController(accountVC, animated: true)
        } else if selectedSetting == "Friend List" {
            let friendsVC = FriendsViewController()
            navigationController?.pushViewController(friendsVC, animated: true)
        } else if selectedSetting == "Add Friend" {
            let addFriendVC = AddFriendViewController()
            navigationController?.pushViewController(addFriendVC, animated: true)
        } else if selectedSetting == "Privacy Policy" {
            let privacypolicyVC = PrivacyPolicyViewController()
            navigationController?.pushViewController(privacypolicyVC, animated: true)
        } else if selectedSetting == "Terms of Service" {
            let termsVC = ToSViewController()
            navigationController?.pushViewController(termsVC, animated: true)
        } else if selectedSetting == "Licenses" {
            let licensesVC = LicensesViewController()
            navigationController?.pushViewController(licensesVC, animated: true)
        }
    }
}
