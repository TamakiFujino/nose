import UIKit
import FirebaseAuth

class AccountViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()

    // Define setting categories and items
    let settingsData: [(category: String, items: [String])] = [
        ("", ["Log out", "Delete Account"]),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        setupUI()
        setupTableView()
    }
    
    func setupUI() {
        // Back button
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .black
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Heading Label
        let headingLabel = UILabel()
        headingLabel.text = "Account"
        headingLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headingLabel)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            // Back button at the top left
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Heading next to the back button
            headingLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 20),
            headingLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
        ])
    }
    
    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
        // go to SettingViewController
        let settingVC = SettingViewController()
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Constraints for TableView
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = settingsData[indexPath.section].items[indexPath.row]
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
        
        if selectedSetting == "Logout" {
            showConfirmationAlert(
                title: "Log Out",
                message: "Are you sure you want to log out?",
                confirmAction: logOut
            )
        } else if selectedSetting == "Delete Account" {
            showConfirmationAlert(
                title: "Delete Account",
                message: "This action is irreversible. Are you sure?",
                confirmAction: deleteAccount
            )
        }
    }

    // MARK: - Actions

    private func logOut() {
        do {
            try Auth.auth().signOut()
            showAlert(title: "Logged Out", message: "You have been successfully logged out.") {
                self.navigateToLoginScreen()
            }
        } catch let error {
            showAlert(title: "Error", message: "Failed to log out: \(error.localizedDescription)")
        }
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            showAlert(title: "Error", message: "No user logged in.")
            return
        }

        user.delete { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to delete account: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Account Deleted", message: "Your account has been successfully deleted.") {
                    self.navigateToLoginScreen()
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateToLoginScreen() {
        let viewController = ViewController()
        viewController.modalPresentationStyle = .fullScreen
        self.present(viewController, animated: true, completion: nil)
    }

    // MARK: - Alerts

    private func showConfirmationAlert(title: String, message: String, confirmAction: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Confirm", style: .destructive) { _ in confirmAction() })
        present(alert, animated: true, completion: nil)
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        present(alert, animated: true, completion: nil)
    }
}
