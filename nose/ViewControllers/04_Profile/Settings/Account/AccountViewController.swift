import UIKit
import FirebaseAuth
import FirebaseFirestore

final class AccountViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let cellHeight: CGFloat = 44
    }
    
    private enum SettingsItem: String, CaseIterable {
        case logout = "Logout"
        case deleteAccount = "Delete Account"
        
        var isDestructive: Bool {
            switch self {
            case .deleteAccount: return true
            case .logout: return false
            }
        }
        
        var alertTitle: String {
            switch self {
            case .logout: return "Log Out"
            case .deleteAccount: return "Delete Account"
            }
        }
        
        var alertMessage: String {
            switch self {
            case .logout: return "Are you sure you want to log out?"
            case .deleteAccount: return "This action is irreversible. Are you sure?"
            }
        }
    }
    
    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .separator
        return tableView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .firstColor
        title = "Account"
        navigationController?.navigationBar.tintColor = .sixthColor
        navigationItem.largeTitleDisplayMode = .never
        
        // Hide back button text
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        setupTableView()
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    private func handleLogout() {
        do {
            try Auth.auth().signOut()
            showAlert(title: "Logged Out", message: "You have been successfully logged out.") {
                self.navigateToLoginScreen()
            }
        } catch {
            showAlert(title: "Error", message: "Failed to log out: \(error.localizedDescription)")
        }
    }
    
    private func deleteAccount() {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "Are you sure you want to delete your account? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self,
                  let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            UserManager.shared.deleteAccount(userId: currentUserId) { (result: Result<Void, Error>) in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.showAlert(title: "Success", message: "Account deleted successfully") { 
                            self.navigateToLoginScreen()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.showAlert(title: "Error", message: "Failed to delete account: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    private func navigateToLoginScreen() {
        let viewController = ViewController()
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
    
    // MARK: - Alerts
    private func showConfirmationAlert(for item: SettingsItem) {
        let alert = UIAlertController(
            title: item.alertTitle,
            message: item.alertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: item.isDestructive ? .destructive : .default) { [weak self] _ in
            switch item {
            case .logout:
                self?.handleLogout()
            case .deleteAccount:
                self?.deleteAccount()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension AccountViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SettingsItem.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = SettingsItem.allCases[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = item.rawValue
        content.textProperties.color = item.isDestructive ? .statusError : .sixthColor
        cell.contentConfiguration = content
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = SettingsItem.allCases[indexPath.row]
        showConfirmationAlert(for: item)
    }
}
