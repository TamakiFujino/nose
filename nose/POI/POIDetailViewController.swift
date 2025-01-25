// this script is to display the detail info of a selected POI
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
    var latitude: Double?
    var longitude: Double?

    var tableView: UITableView!
    var collectionView: UICollectionView!
    var scrollView: UIScrollView!
    var stackView: UIStackView!
    var bookmarkLists: [BookmarkList] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // Initialize ScrollView and StackView
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40) // Adjust width to account for left and right margins
        ])
        
        // Add content to StackView
        // Create the icon button
        let iconButton = UIButton(type: .system)
        // set the icon button to right-aligned
        iconButton.contentHorizontalAlignment = .right
        iconButton.setImage(UIImage(systemName: "bookmark"), for: .normal) // Using SF Symbols
        iconButton.tintColor = .systemBlue
        iconButton.translatesAutoresizingMaskIntoConstraints = false
        iconButton.addTarget(self, action: #selector(iconButtonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(iconButton)
        
        let nameLabel = UILabel()
        nameLabel.text = placeName
        nameLabel.textAlignment = .left
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(nameLabel)

        let addressLabel = UILabel()
        addressLabel.attributedText = createAttributedTextWithIcon(text: address ?? "N/A", icon: UIImage(systemName: "map"))
        addressLabel.textAlignment = .left
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(addressLabel)

        let phoneLabel = UILabel()
        phoneLabel.attributedText = createAttributedTextWithIcon(text: phoneNumber ?? "N/A", icon: UIImage(systemName: "phone"))
        phoneLabel.textAlignment = .left
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(phoneLabel)

        let websiteButton = UIButton(type: .system)
        websiteButton.setAttributedTitle(createAttributedTextWithIcon(text: website ?? "N/A", icon: UIImage(systemName: "globe")), for: .normal)
        websiteButton.contentHorizontalAlignment = .left
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        websiteButton.addTarget(self, action: #selector(websiteButtonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(websiteButton)

        let ratingLabel = UILabel()
        if let rating = rating {
            ratingLabel.attributedText = createAttributedTextWithIcon(text: String(format: "%.1f", rating), icon: UIImage(systemName: "star.fill"))
        } else {
            ratingLabel.text = "Rating: N/A"
        }
        ratingLabel.textAlignment = .left
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(ratingLabel)

        let openingHoursLabel = UILabel()
        openingHoursLabel.text = "Opening Hours:\n\(openingHours?.joined(separator: "\n") ?? "N/A")"
        openingHoursLabel.textAlignment = .left
        openingHoursLabel.numberOfLines = 0
        openingHoursLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(openingHoursLabel)
        
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
        stackView.addArrangedSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.heightAnchor.constraint(equalToConstant: 100)
        ])

        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.heightAnchor.constraint(equalToConstant: 200) // Adjust as needed
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
        let bookmarkedPOIsVC = BookmarkedPOIsViewController()
        bookmarkedPOIsVC.placeID = placeID
        bookmarkedPOIsVC.placeName = placeName
        bookmarkedPOIsVC.address = address
        bookmarkedPOIsVC.phoneNumber = phoneNumber
        bookmarkedPOIsVC.website = website
        bookmarkedPOIsVC.rating = rating
        bookmarkedPOIsVC.openingHours = openingHours
        bookmarkedPOIsVC.latitude = latitude
        bookmarkedPOIsVC.longitude =  longitude
        
        // Debug prints to verify properties
        print("Transitioning to BookmarkedPOIsViewController with:")
        print("placeID: \(placeID ?? "nil")")
        print("placeName: \(placeName ?? "nil")")
        
        bookmarkedPOIsVC.modalPresentationStyle = .fullScreen
        present(bookmarkedPOIsVC, animated: true, completion: nil)
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
