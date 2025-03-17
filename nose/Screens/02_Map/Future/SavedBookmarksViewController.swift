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

        view.backgroundColor = .white
        setupTableView()
        setupMessageLabel()
        setupConstraints()

        // Load bookmark lists
        bookmarkLists = BookmarksManager.shared.bookmarkLists
        updateMessageVisibility()

        // Show saved POIs on the map
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
        poisVC.delegate = self

        // Update to add a navigation bar to the half modal
        let navigationController = UINavigationController(rootViewController: poisVC)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
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
