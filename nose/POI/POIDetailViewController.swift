import UIKit

class POIDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var placeName: String?
    var placeID: String?
    var address: String?
    var phoneNumber: String?
    var website: String?
    var rating: Double?
    var openingHours: [String]?

    var tableView: UITableView!
    var bookmarkLists: [BookmarkList] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        let nameLabel = UILabel()
        nameLabel.text = placeName
        nameLabel.textAlignment = .left
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let addressLabel = UILabel()
        addressLabel.attributedText = createAttributedTextWithIcon(text: address ?? "N/A", icon: UIImage(systemName: "map"))
        addressLabel.textAlignment = .left
        addressLabel.translatesAutoresizingMaskIntoConstraints = false

        let phoneLabel = UILabel()
        phoneLabel.attributedText = createAttributedTextWithIcon(text: phoneNumber ?? "N/A", icon: UIImage(systemName: "phone"))
        phoneLabel.textAlignment = .left
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false

        let websiteLabel = UILabel()
        websiteLabel.attributedText = createAttributedTextWithIcon(text: website ?? "N/A", icon: UIImage(systemName: "globe"))
        websiteLabel.textAlignment = .left
        websiteLabel.translatesAutoresizingMaskIntoConstraints = false

        let ratingLabel = UILabel()
        ratingLabel.text = "Rating: \(rating != nil ? String(rating!) : "N/A")"
        ratingLabel.textAlignment = .left
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false

        let openingHoursLabel = UILabel()
        openingHoursLabel.text = "Opening Hours:\n\(openingHours?.joined(separator: "\n") ?? "N/A")"
        openingHoursLabel.textAlignment = .left
        openingHoursLabel.numberOfLines = 0
        openingHoursLabel.translatesAutoresizingMaskIntoConstraints = false

        // Create the icon button
        let iconButton = UIButton(type: .system)
        iconButton.setImage(UIImage(systemName: "star.fill"), for: .normal) // Using SF Symbols
        iconButton.tintColor = .systemBlue
        iconButton.translatesAutoresizingMaskIntoConstraints = false
        iconButton.addTarget(self, action: #selector(iconButtonTapped), for: .touchUpInside)

        view.addSubview(nameLabel)
        view.addSubview(addressLabel)
        view.addSubview(phoneLabel)
        view.addSubview(websiteLabel)
        view.addSubview(ratingLabel)
        view.addSubview(openingHoursLabel)
        view.addSubview(iconButton)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            addressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            phoneLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            phoneLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 10),
            websiteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            websiteLabel.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 10),
            ratingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ratingLabel.topAnchor.constraint(equalTo: websiteLabel.bottomAnchor, constant: 10),
            openingHoursLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            openingHoursLabel.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 10),
            iconButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconButton.topAnchor.constraint(equalTo: openingHoursLabel.bottomAnchor, constant: 20),
        ])

        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: iconButton.bottomAnchor, constant: 20),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func createAttributedTextWithIcon(text: String, icon: UIImage?) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = icon?.withTintColor(.label) // Adjust the icon color if needed

        let attachmentString = NSAttributedString(attachment: attachment)
        let textString = NSAttributedString(string: " \(text)") // Adding a space before the text

        let combinedString = NSMutableAttributedString()
        combinedString.append(attachmentString)
        combinedString.append(textString)

        return combinedString
    }

    @objc func iconButtonTapped() {
        bookmarkLists = BookmarksManager.shared.bookmarkLists
        
        let alertController = UIAlertController(title: "Select Bookmark List", message: nil, preferredStyle: .alert)
        
        for list in bookmarkLists {
            let action = UIAlertAction(title: list.name, style: .default) { _ in
                self.addPOIToBookmarkList(named: list.name)
            }
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func addPOIToBookmarkList(named listName: String) {
        guard let placeID = placeID, let placeName = placeName else { return }
        
        let bookmarkedPOI = BookmarkedPOI(
            placeID: placeID,
            name: placeName,
            address: address,
            phoneNumber: phoneNumber,
            website: website,
            rating: rating,
            openingHours: openingHours
        )
        
        BookmarksManager.shared.addBookmark(bookmarkedPOI, to: listName)
        print("Bookmarked POI: \(placeName) in list: \(listName)")
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarkLists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        let list = bookmarkLists[indexPath.row]
        cell.textLabel?.text = list.name
        return cell
    }
}
