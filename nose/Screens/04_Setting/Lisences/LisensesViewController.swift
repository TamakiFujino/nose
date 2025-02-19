import UIKit

class LicensesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()
    var licenses: [[String: String]] = []

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
        loadLicenses()
    }

    private func setupNavigationBar() {
        navigationItem.title = "Licenses"
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

    func loadLicenses() {
        loadPlistLicenses(fileName: "Pods-nose-acknowledgements")
        loadPlistLicenses(fileName: "SPM-acknowledgements")
    }

    func loadPlistLicenses(fileName: String) {
        if let path = Bundle.main.path(forResource: fileName, ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
           let preferenceSpecifiers = dict["PreferenceSpecifiers"] as? [[String: AnyObject]] {
            for item in preferenceSpecifiers {
                if let title = item["Title"] as? String, let footerText = item["FooterText"] as? String, title != "Acknowledgements" {
                    licenses.append(["name": title, "license": footerText])
                }
            }
        }
    }

    // MARK: - TableView DataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return licenses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = licenses[indexPath.row]["name"]
        cell.accessoryType = .disclosureIndicator  // Add arrow to indicate navigation
        cell.backgroundColor = .clear // Remove the background color of each cell
        return cell
    }

    // Handle selection of a license
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let licenseDetailVC = LicenseDetailViewController()
        licenseDetailVC.licenseText = licenses[indexPath.row]["license"] ?? ""
        licenseDetailVC.title = licenses[indexPath.row]["name"]
        navigationController?.pushViewController(licenseDetailVC, animated: true)
    }
}
