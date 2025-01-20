import UIKit

class BookmarkedPOIsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!

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
    }

    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BookmarksManager.shared.bookmarks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let bookmark = BookmarksManager.shared.bookmarks[indexPath.row]
        cell.textLabel?.text = bookmark.name
        cell.detailTextLabel?.text = bookmark.address
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bookmark = BookmarksManager.shared.bookmarks[indexPath.row]
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
    }
}
