import UIKit

class SavedBookmarksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!
    var bookmarkLists: [BookmarkList] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Set up constraints for table view
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Load bookmark lists
        bookmarkLists = BookmarksManager.shared.bookmarkLists
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarkLists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let list = bookmarkLists[indexPath.row]
        cell.textLabel?.text = list.name
        cell.detailTextLabel?.text = "\(list.bookmarks.count) POIs saved" // Show number of POIs saved
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedList = bookmarkLists[indexPath.row]
        
        // Present POIsViewController to display saved POIs for the selected bookmark list
        let poisVC = POIsViewController()
        poisVC.bookmarkList = selectedList
        navigationController?.pushViewController(poisVC, animated: true)
    }
}
