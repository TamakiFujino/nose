import UIKit
import FirebaseAuth

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()

    // Define setting categories and items (keys for localization)
    var settingsData: [(category: String, items: [String])] = [
        ("settings_profile", ["settings_name", "settings_account"]),
        ("settings_friends", ["settings_friend_list", "settings_add_friend"]),
        ("settings_about", ["settings_privacy_policy", "settings_terms_of_service", "settings_app_version", "settings_licenses"])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .firstColor

        // Set up navigation bar
        setupNavigationBar()

        setupTableView()
        // Avatar display disabled: no header, no profile image load
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    private func setupNavigationBar() {
        navigationItem.title = String(localized: "settings_title")
        self.navigationController?.navigationBar.tintColor = .fourthColor
        
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

        if item == "settings_app_version" {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "versionCell")
            cell.textLabel?.text = String(localized: String.LocalizationValue(stringLiteral: item))
            
            // Get version and build number
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            let fullVersion = "\(version) (\(build))"
            
            Logger.log("DEBUG: App version info:", level: .debug, category: "Settings")
            Logger.log("  - Version: \(version)", level: .debug, category: "Settings")
            Logger.log("  - Build: \(build)", level: .debug, category: "Settings")
            Logger.log("  - Full version: \(fullVersion)", level: .debug, category: "Settings")
            Logger.log("  - Bundle identifier: \(Bundle.main.bundleIdentifier ?? "Unknown")", level: .debug, category: "Settings")
            Logger.log("  - Info dictionary keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "None")", level: .debug, category: "Settings")
            
            cell.detailTextLabel?.text = fullVersion
            cell.detailTextLabel?.textColor = .fourthColor
            cell.detailTextLabel?.accessibilityIdentifier = "app_version_text"
            cell.selectionStyle = .none  // Disable selection for app version cell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = String(localized: String.LocalizationValue(stringLiteral: item))
            cell.accessoryType = .disclosureIndicator  // Add arrow to indicate navigation
        }

        cell.backgroundColor = .clear // Remove the background color of each cell
        return cell
    }

    // Set section headers
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return String(localized: String.LocalizationValue(stringLiteral: settingsData[section].category))
    }

    // Handle selection of a setting option
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedSetting = settingsData[indexPath.section].items[indexPath.row]

        if selectedSetting == "settings_name" {
            let nameupdateVC = EditNameViewController()
            navigationController?.pushViewController(nameupdateVC, animated: true)
        } else if selectedSetting == "settings_account" {
            let accountVC = AccountViewController()
            navigationController?.pushViewController(accountVC, animated: true)
        } else if selectedSetting == "settings_friend_list" {
            let friendsVC = FriendsViewController()
            navigationController?.pushViewController(friendsVC, animated: true)
        } else if selectedSetting == "settings_add_friend" {
            let addFriendVC = AddFriendViewController()
            navigationController?.pushViewController(addFriendVC, animated: true)
        } else if selectedSetting == "settings_privacy_policy" {
            let privacypolicyVC = PrivacyPolicyViewController()
            navigationController?.pushViewController(privacypolicyVC, animated: true)
        } else if selectedSetting == "settings_terms_of_service" {
            let termsVC = ToSViewController()
            navigationController?.pushViewController(termsVC, animated: true)
        } else if selectedSetting == "settings_licenses" {
            let licensesVC = LicensesViewController()
            navigationController?.pushViewController(licensesVC, animated: true)
        }
    }
}
