import UIKit
import GoogleMaps
import GooglePlaces

class PastMapMainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var tableView: UITableView!
    var messageLabel: UILabel!
    var items: [BookmarkList] = [] // Data array for items
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Set up navigation bar
        setupNavigationBar()
        
        // Initialize message label
        messageLabel = UILabel()
        messageLabel.text = "No items to display yet."
        messageLabel.textColor = .gray
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Load completed items
        items = BookmarksManager.shared.completedLists
        updateMessageVisibility()
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Past Map"
        self.navigationController?.navigationBar.tintColor = .black
    }

    func updateMessageVisibility() {
        guard let messageLabel = messageLabel, let tableView = tableView else { return }
        
        messageLabel.isHidden = !items.isEmpty
        tableView.isHidden = items.isEmpty
    }

    func addItem(_ item: BookmarkList) {
        items.append(item)
        
        // Ensure the tableView and messageLabel are initialized
        guard tableView != nil, messageLabel != nil else { return }
        
        tableView.reloadData()
        updateMessageVisibility()
    }

    func presentCompletedBookmarkList(_ bookmarkList: BookmarkList) {
        let detailVC = POIsViewController()
        detailVC.bookmarkList = bookmarkList
        detailVC.isFromPastMap = true
        detailVC.delegate = nil // No need for delegate in this case
        
        let navigationController = UINavigationController(rootViewController: detailVC)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.name
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Handle cell selection
        let selectedItem = items[indexPath.row]
        presentCompletedBookmarkList(selectedItem)
    }
}
