import UIKit
import GoogleMaps
import GooglePlaces

protocol POIsViewControllerDelegate: AnyObject {
    func didDeleteBookmarkList()
}

class POIsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!
    var bookmarkList: BookmarkList!
    var sharedWithCount: Int = 0 // Assuming you have a way to get this count
    var loggedInUser: String = "defaultUser" // Replace this with actual logged-in user ID or default user
    weak var delegate: POIsViewControllerDelegate?
    var infoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        title = bookmarkList.name
        
        // Set up navigation bar
        setupNavigationBar()
        
        // Add label before the table view
        infoLabel = UILabel()
        updateInfoLabel()
        infoLabel.font = UIFont.systemFont(ofSize: 16)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear // Remove the background color
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        // Set up constraints for info label and table view
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("Loaded POIs for bookmark list: \(bookmarkList.name)")
    }

    private func setupNavigationBar() {
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(dismissModal))
        self.navigationItem.leftBarButtonItem = backButton
        self.navigationController?.navigationBar.tintColor = .black
        
        let menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(showMenu))
        self.navigationItem.rightBarButtonItem = menuButton
    }
    
    @objc private func dismissModal() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func showMenu() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let shareAction = UIAlertAction(title: "Share", style: .default) { _ in
            // Implement share functionality here
        }
        let completeCollectionAction = UIAlertAction(title: "Complete collection", style: .default) { _ in
            // Implement complete collection functionality here
        }
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.showDeleteWarning()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(shareAction)
        alertController.addAction(completeCollectionAction)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func showDeleteWarning() {
        let alertController = UIAlertController(title: "Warning", message: "Are you sure you want to delete this bookmark list? This action cannot be undone.", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteBookmarkList()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func deleteBookmarkList() {
        BookmarksManager.shared.deleteBookmarkList(bookmarkList)
        self.delegate?.didDeleteBookmarkList()
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarkList.bookmarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let poi = bookmarkList.bookmarks[indexPath.row]
        
        cell.textLabel?.numberOfLines = 2
        
        // Unwrap rating safely
        let rating = poi.rating ?? 0.0
        
        let ratingText = getRatingText(rating: rating)
        let text = "\(poi.name)\n\(ratingText)"
        let attributedText = NSMutableAttributedString(string: text)
        
        // Make rating display smaller
        let nameRange = (text as NSString).range(of: poi.name)
        let ratingRange = (text as NSString).range(of: ratingText)
        attributedText.addAttributes([.font: UIFont.systemFont(ofSize: 17)], range: nameRange)
        attributedText.addAttributes([.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.fourthColor], range: ratingRange)
        
        // Add more padding between lines
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, attributedText.length))
        
        cell.textLabel?.attributedText = attributedText
        cell.backgroundColor = .clear // Remove the background color of each cell
        
        return cell
    }
    
    private func getRatingText(rating: Double) -> String {
        var ratingText = ""
        let fullStars = Int(rating)
        for _ in 0..<fullStars {
            ratingText += "●"
        }
        if rating - Double(fullStars) >= 0.5 {
            ratingText += "◐"
        }
        let emptyStars = 5 - fullStars - (ratingText.count > fullStars ? 1 : 0)
        for _ in 0..<emptyStars {
            ratingText += "○"
        }
        return ratingText
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let poi = bookmarkList.bookmarks[indexPath.row]
        let detailVC = POIDetailViewController()
        detailVC.placeID = poi.placeID
        detailVC.placeName = poi.name
        detailVC.address = poi.address
        detailVC.phoneNumber = poi.phoneNumber
        detailVC.website = poi.website
        detailVC.rating = poi.rating
        detailVC.openingHours = poi.openingHours
        detailVC.latitude = poi.latitude
        detailVC.longitude = poi.longitude
        
        // Save the selected POI
        BookmarksManager.shared.savePOI(for: loggedInUser, placeID: poi.placeID)
        
        // Presenting details for POI
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        print("Presenting details for POI: \(poi.name)")
        self.present(detailVC, animated: true, completion: nil)
    }
    
    // Swipe to delete functionality
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let poiToDelete = bookmarkList.bookmarks[indexPath.row]
            BookmarksManager.shared.deletePOI(for: loggedInUser, placeID: poiToDelete.placeID)
            bookmarkList.bookmarks.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            BookmarksManager.shared.saveBookmarkList(bookmarkList)  // Save updated bookmark list
            updateInfoLabel() // Update the info label with the new count
        }
    }
    
    private func updateInfoLabel() {
        let bookmarkIcon = UIImage(systemName: "bookmark.fill")?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
        let friendsIcon = UIImage(systemName: "person.fill")?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
        
        let bookmarkIconAttachment = NSTextAttachment()
        bookmarkIconAttachment.image = bookmarkIcon
        bookmarkIconAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let friendsIconAttachment = NSTextAttachment()
        friendsIconAttachment.image = friendsIcon
        friendsIconAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(attachment: bookmarkIconAttachment))
        attributedText.append(NSAttributedString(string: " \(bookmarkList.bookmarks.count)  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        attributedText.append(NSAttributedString(attachment: friendsIconAttachment))
        attributedText.append(NSAttributedString(string: " \(sharedWithCount)", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        // set color of the text
        attributedText.addAttribute(.foregroundColor, value: UIColor.fourthColor, range: NSMakeRange(0, attributedText.length))
        
        infoLabel.attributedText = attributedText
    }
}
