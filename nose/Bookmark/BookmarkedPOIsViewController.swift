import UIKit

class BookmarkedPOIsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!
    var selectedList: BookmarkList?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        
        // Set up the table view
        tableView = UITableView(frame: view.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        // Add a close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        
        if selectedList == nil {
            title = "Bookmark Lists"
        } else {
            title = selectedList?.name
        }
    }

    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let selectedList = selectedList {
            return selectedList.bookmarks.count
        } else {
            return BookmarksManager.shared.bookmarkLists.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        if let selectedList = selectedList {
            let bookmark = selectedList.bookmarks[indexPath.row]
            cell.textLabel?.text = bookmark.name
            cell.detailTextLabel?.text = bookmark.address
        } else {
            let bookmarkList = BookmarksManager.shared.bookmarkLists[indexPath.row]
            cell.textLabel?.text = bookmarkList.name
            cell.detailTextLabel?.text = "\(bookmarkList.bookmarks.count) POIs"
        }
        
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let selectedList = selectedList {
            let bookmark = selectedList.bookmarks[indexPath.row]
            let detailVC = POIDetailViewController()
            detailVC.placeName = bookmark.name
            detailVC.placeID = bookmark.placeID
            detailVC.address = bookmark.address
            detailVC.phoneNumber = bookmark.phoneNumber
            detailVC.website = bookmark.website
            detailVC.rating = bookmark.rating
            detailVC.openingHours = bookmark.openingHours
            detailVC.modalPresentationStyle = .pageSheet
            if let sheet = detailVC.sheetPresentationController {
                sheet.detents = [.medium()]
            }
            present(detailVC, animated: true, completion: nil)
        } else {
            let bookmarkList = BookmarksManager.shared.bookmarkLists[indexPath.row]
            let bookmarkedPOIsVC = BookmarkedPOIsViewController()
            bookmarkedPOIsVC.selectedList = bookmarkList
            bookmarkedPOIsVC.modalPresentationStyle = .fullScreen
            present(bookmarkedPOIsVC, animated: true, completion: nil)
        }
    }
}
