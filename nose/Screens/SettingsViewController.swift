import UIKit
import FirebaseAuth
import FirebaseFirestore

class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var settingsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.backgroundColor = .systemGroupedBackground
        return tableView
    }()
    
    // MARK: - Properties
    private let sections: [(title: String, items: [String])] = [
        ("Account", ["Name", "Log Out", "Delete Account"]),
        ("About", ["Privacy Policy", "Terms of Service", "Licenses", "App Version"])
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Settings"
        
        view.addSubview(settingsTableView)
        
        NSLayoutConstraint.activate([
            settingsTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            settingsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    private func handleLogOut() {
        let alert = UIAlertController(
            title: "Log Out",
            message: "Are you sure you want to log out?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { [weak self] _ in
            do {
                try Auth.auth().signOut()
                self?.navigationController?.popToRootViewController(animated: true)
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        })
        
        present(alert, animated: true)
    }
    
    private func handleDeleteAccount() {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "Are you sure you want to delete your account? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let user = Auth.auth().currentUser else { return }
            
            // Delete user data from Firestore first
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).delete { error in
                if let error = error {
                    print("Error deleting user data: \(error.localizedDescription)")
                    return
                }
                
                // Then delete the user account
                user.delete { error in
                    if let error = error {
                        print("Error deleting user account: \(error.localizedDescription)")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.navigationController?.popToRootViewController(animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showPrivacyPolicy() {
        // TODO: Implement privacy policy view
        print("Show privacy policy")
    }
    
    private func showTermsOfService() {
        // TODO: Implement terms of service view
        print("Show terms of service")
    }
    
    private func showLicenses() {
        // TODO: Implement licenses view
        print("Show licenses")
    }
    
    private func showAppVersion() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let alert = UIAlertController(
            title: "App Version",
            message: "Version: \(version)\nBuild: \(build)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension SettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = item
        
        // Set text color for destructive actions
        if item == "Log Out" || item == "Delete Account" {
            content.textProperties.color = .systemRed
        }
        
        cell.contentConfiguration = content
        
        // Add disclosure indicator for all items except destructive actions
        if item != "Log Out" && item != "Delete Account" {
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        
        switch item {
        case "Name":
            let editNameVC = EditNameViewController()
            navigationController?.pushViewController(editNameVC, animated: true)
        case "Log Out":
            handleLogOut()
        case "Delete Account":
            handleDeleteAccount()
        case "Privacy Policy":
            showPrivacyPolicy()
        case "Terms of Service":
            showTermsOfService()
        case "Licenses":
            showLicenses()
        case "App Version":
            showAppVersion()
        default:
            break
        }
    }
}

