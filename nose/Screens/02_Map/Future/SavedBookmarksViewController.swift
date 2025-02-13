import UIKit

class SavedBookmarksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var tableView: UITableView!
    var bookmarkLists: [BookmarkList] = []
    var messageLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Initialize message label
        messageLabel = UILabel()
        messageLabel.text = "No bookmark lists created yet."
        messageLabel.textColor = .gray
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(BookmarkListCell.self, forCellReuseIdentifier: "BookmarkListCell")
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
        
        // Load bookmark lists
        bookmarkLists = BookmarksManager.shared.bookmarkLists
        updateMessageVisibility()
    }
    
    func updateMessageVisibility() {
        messageLabel.isHidden = !bookmarkLists.isEmpty
        tableView.isHidden = bookmarkLists.isEmpty
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarkLists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkListCell", for: indexPath) as! BookmarkListCell
        let list = bookmarkLists[indexPath.row]
        cell.configure(with: list)
        cell.menuButton.tag = indexPath.row
        cell.menuButton.addTarget(self, action: #selector(menuButtonTapped(_:)), for: .touchUpInside)
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
    
    // MARK: - Actions
    
    @objc func menuButtonTapped(_ sender: UIButton) {
        let bookmarkList = bookmarkLists[sender.tag]
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let shareAction = UIAlertAction(title: "Share the bookmark list", style: .default) { _ in
            self.presentShareModal(for: bookmarkList)
        }
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteBookmarkList(at: sender.tag)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(shareAction)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func presentShareModal(for list: BookmarkList) {
        let shareModalVC = ShareModalViewController()
        shareModalVC.bookmarkList = list
        shareModalVC.modalPresentationStyle = .pageSheet
        if let sheet = shareModalVC.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(shareModalVC, animated: true, completion: nil)
    }
    
    private func deleteBookmarkList(at index: Int) {
        let listToDelete = bookmarkLists[index]
        BookmarksManager.shared.deleteBookmarkList(listToDelete)
        bookmarkLists.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        updateMessageVisibility()
    }
    
    // Show the bookmark list with the given ID
    func showBookmarkList(withId id: String) {
        if let index = bookmarkLists.firstIndex(where: { $0.id == id }) {
            let selectedList = bookmarkLists[index]
            let poisVC = POIsViewController()
            poisVC.bookmarkList = selectedList
            navigationController?.pushViewController(poisVC, animated: true)
        }
    }
}

class BookmarkListCell: UITableViewCell {
    
    let menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(menuButton)
        
        NSLayoutConstraint.activate([
            menuButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with list: BookmarkList) {
        textLabel?.text = list.name
        textLabel?.textColor = .black
        let sharedText = list.sharedWithFriends.count > 0 ? "shared with \(list.sharedWithFriends.count) friends" : ""
        detailTextLabel?.text = "\(list.bookmarks.count) saved \(sharedText)"
        detailTextLabel?.textColor = .black
    }
}
