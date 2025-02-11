import UIKit

class SettingViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()

    // Define setting categories and items
    let settingsData: [(category: String, items: [String])] = [
        ("Profile", ["Name", "Account"]),
        ("Preferences", ["Notifications", "Language"]),
        ("About", ["Privacy Policy", "Terms of Service"])
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
        headingLabel.text = "Settings"
        headingLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headingLabel)
        
        // Subheading Label
        let subheadingLabel = UILabel()
        subheadingLabel.text = "Change your settings here"
        subheadingLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subheadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subheadingLabel)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            // Back button at the top left
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Heading next to the back button
            headingLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 20),
            headingLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            
            // Subheading below heading
            subheadingLabel.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            subheadingLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 5)
        ])
    }
    
    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
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
        cell.accessoryType = .disclosureIndicator  // Add arrow to indicate navigation
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
            let nameVC = NameInputViewController()
            let navController = UINavigationController(rootViewController: nameVC)
            present(navController, animated: true, completion: nil)
        }
    }
}
