import UIKit
import GoogleMaps
import GooglePlaces

class SavedBookmarksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var tableView: UITableView!
    var bookmarkLists: [BookmarkList] = []
    var messageLabel: UILabel!
    weak var mapView: GMSMapView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Set up navigation bar
        setupNavigationBar()
        
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
        
        // Show saved POIs on the map
        showSavedPOIMarkers()
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Saved Bookmarks"
        self.navigationController?.navigationBar.tintColor = .black
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
        
        // DEBUG PRINT: Check selectedList before navigation
        print("Selected Bookmark List: \(selectedList.name), POIs Count: \(selectedList.bookmarks.count)")
        
        // Ensure the selectedList has bookmarks
        guard !selectedList.bookmarks.isEmpty else {
            print("Selected list has no bookmarks.")
            return
        }
        
        // Present POIsViewController to display saved POIs for the selected bookmark list
        let poisVC = POIsViewController()
        poisVC.bookmarkList = selectedList
        
        // Update to add a navigation bar to the half modal
        let navigationController = UINavigationController(rootViewController: poisVC)
        navigationController.modalPresentationStyle = .pageSheet
        navigationController.navigationBar.topItem?.title = "Collections"
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    
    @objc func menuButtonTapped(_ sender: UIButton) {
        let bookmarkList = bookmarkLists[sender.tag]
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let shareAction = UIAlertAction(title: "Share the bookmark list", style: .default) { _ in
            self.presentShareModal(for: bookmarkList)
        }
        let completeAction = UIAlertAction(title: "Complete this bookmark", style: .default) { _ in
            self.completeBookmarkList(at: sender.tag)
        }
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteBookmarkList(at: sender.tag)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(shareAction)
        alertController.addAction(completeAction)
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
    
    private func completeBookmarkList(at index: Int) {
        let completedList = bookmarkLists[index]
        // Implement the logic to complete the bookmark list
        print("Completed bookmark list: \(completedList.name)")
        // You can update the UI or show a confirmation message here
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
    
    // MARK: - Showing POIs on Map
    
    func showSavedPOIMarkers() {
        guard let mapView = mapView else { return }
        
        let savedPOIs = bookmarkLists.flatMap { $0.bookmarks }
        
        guard !savedPOIs.isEmpty else {
            print("No saved POIs to display.")
            return
        }
        
        for poi in savedPOIs {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
            marker.title = poi.name
            marker.map = mapView
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
        
        let bookmarkIcon = UIImage(systemName: "bookmark.fill")?.withTintColor(.black, renderingMode: .alwaysOriginal)
        let friendsIcon = UIImage(systemName: "person.2.fill")?.withTintColor(.black, renderingMode: .alwaysOriginal)
        
        let bookmarkIconAttachment = NSTextAttachment(image: bookmarkIcon!)
        let friendsIconAttachment = NSTextAttachment(image: friendsIcon!)
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(attachment: bookmarkIconAttachment))
        attributedText.append(NSAttributedString(string: " \(list.bookmarks.count)  "))
        attributedText.append(NSAttributedString(attachment: friendsIconAttachment))
        attributedText.append(NSAttributedString(string: " \(list.sharedWithFriends.count)"))
        
        detailTextLabel?.attributedText = attributedText
        detailTextLabel?.textColor = .black
    }
}
