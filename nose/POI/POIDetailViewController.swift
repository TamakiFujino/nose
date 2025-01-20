import UIKit

class POIDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var placeName: String?
    var placeID: String?
    var address: String?
    var phoneNumber: String?
    var website: String?
    var rating: Double?
    var openingHours: [String]?
    var photos: [UIImage] = [] // Array to hold POI photos

    var tableView: UITableView!
    var collectionView: UICollectionView!
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

        let websiteButton = UIButton(type: .system)
        websiteButton.setAttributedTitle(createAttributedTextWithIcon(text: website ?? "N/A", icon: UIImage(systemName: "globe")), for: .normal)
        websiteButton.contentHorizontalAlignment = .left
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        websiteButton.addTarget(self, action: #selector(websiteButtonTapped), for: .touchUpInside)

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
        
        // Create the collection view layout
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.scrollDirection = .horizontal
        
        // Initialize the collection view
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.backgroundColor = .white

        view.addSubview(nameLabel)
        view.addSubview(addressLabel)
        view.addSubview(phoneLabel)
        view.addSubview(websiteButton)
        view.addSubview(ratingLabel)
        view.addSubview(openingHoursLabel)
        view.addSubview(iconButton)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            addressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            phoneLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            phoneLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 10),
            websiteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            websiteButton.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 10),
            ratingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ratingLabel.topAnchor.constraint(equalTo: websiteButton.bottomAnchor, constant: 10),
            openingHoursLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            openingHoursLabel.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 10),
            iconButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconButton.topAnchor.constraint(equalTo: openingHoursLabel.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            collectionView.topAnchor.constraint(equalTo: iconButton.bottomAnchor, constant: 20),
            collectionView.heightAnchor.constraint(equalToConstant: 100)
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
            tableView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20),
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

    @objc func websiteButtonTapped() {
        if let website = website, let url = URL(string: website) {
            UIApplication.shared.open(url)
        }
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

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
        cell.imageView.image = photos[indexPath.item]
        return cell
    }
}
