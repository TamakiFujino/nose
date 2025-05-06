// this script is to display the saved bookmarks in a table view
import UIKit
import GoogleMaps
import GooglePlaces

class SavedBookmarksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, POIsViewControllerDelegate {

    var tableView: UITableView!
    var bookmarkLists: [BookmarkList] = []
    var messageLabel: UILabel!
    weak var mapView: GMSMapView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Collections"
        view.backgroundColor = .white
        setupTableView()
        setupMessageLabel()
        setupConstraints()

        bookmarkLists = BookmarksManager.shared.bookmarkLists
        updateMessageVisibility()
        showSavedPOIMarkers()
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(BookmarkListCell.self, forCellReuseIdentifier: "BookmarkListCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }

    private func setupMessageLabel() {
        messageLabel = UILabel()
        messageLabel.text = "No bookmark lists created yet."
        messageLabel.textColor = .gray
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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
        let key = "sharedFriends_\(list.id)"
        let sharedCount = (UserDefaults.standard.array(forKey: key) as? [String])?.count ?? 0
        cell.configure(with: list, sharedCount: sharedCount)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedList = bookmarkLists[indexPath.row]

        // Present POIsViewController to display saved POIs for the selected bookmark list
        let poisVC = POIsViewController()
        poisVC.bookmarkList = selectedList
        poisVC.delegate = self

        // Update to add a navigation bar to the half modal
        let savedBookmarksVC = SavedBookmarksViewController()
        let navigationController = UINavigationController(rootViewController: poisVC)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
    }

    // MARK: - POIsViewControllerDelegate

    func didUpdateSharedFriends(for bookmarkList: BookmarkList) {
        if let index = bookmarkLists.firstIndex(where: { $0.id == bookmarkList.id }) {
            bookmarkLists[index] = bookmarkList
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }

// MARK: - POIsViewControllerDelegate

    func didDeleteBookmarkList() {
        bookmarkLists = BookmarksManager.shared.bookmarkLists
        tableView.reloadData()
        updateMessageVisibility()
        showSavedPOIMarkers()
    }

    func didCompleteBookmarkList(_ bookmarkList: BookmarkList) {
        // Remove the completed bookmark list
        BookmarksManager.shared.completeBookmarkList(bookmarkList)
        bookmarkLists = BookmarksManager.shared.bookmarkLists
        tableView.reloadData()
        updateMessageVisibility()
        showSavedPOIMarkers()

        // Present the completed bookmark list in the half modal of PastMapMainViewController
        if let navigationController = navigationController {
            for viewController in navigationController.viewControllers {
                if let pastMapVC = viewController as? PastMapMainViewController {
                    pastMapVC.addItem(bookmarkList)
                    break
                }
            }
        }
    }

    func centerMapOnPOI(latitude: Double, longitude: Double) {
    }

    // MARK: - Showing POIs on Map

    func showSavedPOIMarkers() {
        guard let mapView = mapView else { return }

        mapView.clear() // Clear existing markers

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
            poisVC.delegate = self
            navigationController?.pushViewController(poisVC, animated: true)
        }
    }
}
