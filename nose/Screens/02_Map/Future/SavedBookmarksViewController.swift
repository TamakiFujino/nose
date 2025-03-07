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
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedList = bookmarkLists[indexPath.row]
        
        // Present POIsViewController to display saved POIs for the selected bookmark list
        let poisVC = POIsViewController()
        poisVC.bookmarkList = selectedList
        
        // Update to add a navigation bar to the half modal
        let navigationController = UINavigationController(rootViewController: poisVC)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Customize cell UI if needed
        textLabel?.numberOfLines = 2 // Allow textLabel to have multiple lines
    }
    
    func configure(with list: BookmarkList) {
        let nameText = NSAttributedString(string: "\(list.name)\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16)])
        
        let bookmarkIcon = UIImage(systemName: "bookmark.fill")?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
        let friendsIcon = UIImage(systemName: "person.fill")?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
        
        let bookmarkIconAttachment = NSTextAttachment()
        bookmarkIconAttachment.image = bookmarkIcon
        bookmarkIconAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let friendsIconAttachment = NSTextAttachment()
        friendsIconAttachment.image = friendsIcon
        friendsIconAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let infoText = NSMutableAttributedString()
        infoText.append(NSAttributedString(attachment: bookmarkIconAttachment))
        infoText.append(NSAttributedString(string: " \(list.bookmarks.count)  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        infoText.append(NSAttributedString(attachment: friendsIconAttachment))
        infoText.append(NSAttributedString(string: " \(list.sharedWithFriends.count)", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        infoText.addAttribute(.foregroundColor, value: UIColor.fourthColor, range: NSMakeRange(0, infoText.length))
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(nameText)
        attributedText.append(infoText)
        
        textLabel?.attributedText = attributedText
    }
}
