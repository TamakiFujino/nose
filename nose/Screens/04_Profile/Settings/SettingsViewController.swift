import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()

    // Define setting categories and items
    var settingsData: [(category: String, items: [String])] = [
        ("Profile", ["Name", "Account"]),
        ("About", ["Privacy Policy", "Terms of Service", "App Version", "Licenses"])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        let backButton = UIBarButtonItem()
        backButton.title = ""  // Hide the "Back" text
        self.navigationItem.backBarButtonItem = backButton
        self.navigationController?.navigationBar.tintColor = .black

        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)

        // Set up navigation bar
        setupNavigationBar()

        setupTableView()
    }

    private func setupNavigationBar() {
        navigationItem.title = "Settings"
        self.navigationController?.navigationBar.tintColor = .black
    }

    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
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

        if item == "App Version" {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "versionCell")
            cell.textLabel?.text = item
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                cell.detailTextLabel?.text = version
            }
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
