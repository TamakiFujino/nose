import UIKit
import GoogleMaps
import GooglePlaces

class POIsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!
    var bookmarkList: BookmarkList!
    var sharedWithCount: Int = 0 // Assuming you have a way to get this count
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        title = bookmarkList.name
        
        // Set up navigation bar
        setupNavigationBar()
        
        // Add label before the table view
        let infoLabel = UILabel()
        let bookmarkIcon = UIImage(systemName: "bookmark.fill")?.withTintColor(.black, renderingMode: .alwaysOriginal)
        let friendsIcon = UIImage(systemName: "person.2.fill")?.withTintColor(.black, renderingMode: .alwaysOriginal)
        
        let bookmarkIconAttachment = NSTextAttachment(image: bookmarkIcon!)
        let friendsIconAttachment = NSTextAttachment(image: friendsIcon!)
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(attachment: bookmarkIconAttachment))
        attributedText.append(NSAttributedString(string: " \(bookmarkList.bookmarks.count)  "))
        attributedText.append(NSAttributedString(attachment: friendsIconAttachment))
        attributedText.append(NSAttributedString(string: " \(sharedWithCount)"))
        
        infoLabel.attributedText = attributedText
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
        view.addSubview(tableView)
        
        // Set up constraints for info label and table view
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("Loaded POIs for bookmark list: \(bookmarkList.name)")
    }

    private func setupNavigationBar() {
        let backButton = UIBarButtonItem()
        backButton.title = ""  // Hide the "Back" text
        self.navigationItem.backBarButtonItem = backButton
        self.navigationController?.navigationBar.tintColor = .black
    }

    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarkList.bookmarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let poi = bookmarkList.bookmarks[indexPath.row]
        cell.textLabel?.text = poi.name
        cell.backgroundColor = .clear // Remove the background color of each cell
        
        // Remove the display of address
        cell.detailTextLabel?.text = nil
        
        return cell
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
        
        // Presenting details for POI
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        print("Presenting details for POI: \(poi.name)")
        self.present(detailVC, animated: true, completion: nil)
    }
}
