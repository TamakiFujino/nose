import UIKit

class BookmarkedPOIsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!
    var bookmarkLists: [BookmarkList] = []
    var messageLabel: UILabel!
    
    // Properties to hold POI information
    var placeID: String?
    var placeName: String?
    var address: String?
    var phoneNumber: String?
    var website: String?
    var rating: Double?
    var openingHours: [String]?
    
    // Property to keep track of the selected bookmark list
    var selectedBookmarkList: BookmarkList?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Add navigation bar
        let navBar = UINavigationBar()
        navBar.barTintColor = .white
        navBar.translatesAutoresizingMaskIntoConstraints = false
        let navItem = UINavigationItem(title: "Bookmark Lists")
        let backItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(backButtonTapped))
        navItem.leftBarButtonItem = backItem
        backItem.tintColor = .none
        backItem.image = UIImage(systemName: "arrow.left")
        navBar.setItems([navItem], animated: false)
        view.addSubview(navBar)
        
        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Initialize message label
        messageLabel = UILabel()
        messageLabel.text = "No bookmark lists created yet."
        messageLabel.textColor = .gray
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add "Create Bookmark List" button
        let createListButton = UIButton(type: .system)
        createListButton.setTitle("Create Bookmark List", for: .normal)
        createListButton.translatesAutoresizingMaskIntoConstraints = false
        createListButton.addTarget(self, action: #selector(createListButtonTapped), for: .touchUpInside)
        view.addSubview(createListButton)
        
        // Add "Confirm" button
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        view.addSubview(confirmButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: createListButton.topAnchor, constant: -10),
            
            createListButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            createListButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // Load bookmark lists
        bookmarkLists = BookmarksManager.shared.bookmarkLists
        updateMessageVisibility()
    }

    func updateMessageVisibility() {
        messageLabel.isHidden = !bookmarkLists.isEmpty
    }

    @objc func backButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func createListButtonTapped() {
        let alertController = UIAlertController(title: "Create Bookmark List", message: "Enter a name for your new bookmark list.", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "List Name"
        }
        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
            if let listName = alertController.textFields?.first?.text, !listName.isEmpty {
                BookmarksManager.shared.createBookmarkList(name: listName)
                self.bookmarkLists = BookmarksManager.shared.bookmarkLists // Refresh the list
                self.tableView.reloadData()
                self.updateMessageVisibility()
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(createAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func confirmButtonTapped() {
        print("Confirm button tapped")

        guard let selectedList = selectedBookmarkList else {
            print("No bookmark list selected")
            return
        }
        
        guard let placeID = placeID, let placeName = placeName else {
            print("POI information is incomplete")
            return
        }
        
        let bookmarkedPOI = BookmarkedPOI(
            placeID: placeID,
            name: placeName,
            address: address,
            phoneNumber: phoneNumber,
            website: website,
            rating: rating,
            openingHours: openingHours
        )
        
        if let index = bookmarkLists.firstIndex(of: selectedList) {
            bookmarkLists[index].bookmarks.append(bookmarkedPOI)
            BookmarksManager.shared.saveBookmarkList(bookmarkLists[index])
        }
        
        if let navigationController = navigationController {
            navigationController.popToRootViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarkLists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let list = bookmarkLists[indexPath.row]
        cell.textLabel?.text = list.name
        cell.detailTextLabel?.text = "\(list.bookmarks.count) POIs saved"
        cell.accessoryType = list == selectedBookmarkList ? .checkmark : .none
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedBookmarkList = bookmarkLists[indexPath.row]
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            let listToDelete = self.bookmarkLists.remove(at: indexPath.row)
            BookmarksManager.shared.deleteBookmarkList(listToDelete)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateMessageVisibility()
            completionHandler(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
