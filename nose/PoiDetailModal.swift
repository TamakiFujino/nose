import UIKit

class POIDetailViewController: UIViewController {

    var placeName: String?
    var placeID: String?
    var address: String?
    var phoneNumber: String?
    var website: String?
    var rating: Double?
    var openingHours: [String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        let nameLabel = UILabel()
        nameLabel.text = placeName
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let placeIDLabel = UILabel()
        placeIDLabel.text = "Place ID: \(placeID ?? "")"
        placeIDLabel.textAlignment = .center
        placeIDLabel.translatesAutoresizingMaskIntoConstraints = false

        let addressLabel = UILabel()
        addressLabel.text = "Address: \(address ?? "N/A")"
        addressLabel.textAlignment = .center
        addressLabel.translatesAutoresizingMaskIntoConstraints = false

        let phoneLabel = UILabel()
        phoneLabel.text = "Phone: \(phoneNumber ?? "N/A")"
        phoneLabel.textAlignment = .center
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false

        let websiteLabel = UILabel()
        websiteLabel.text = "Website: \(website ?? "N/A")"
        websiteLabel.textAlignment = .center
        websiteLabel.translatesAutoresizingMaskIntoConstraints = false

        let ratingLabel = UILabel()
        ratingLabel.text = "Rating: \(rating != nil ? String(rating!) : "N/A")"
        ratingLabel.textAlignment = .center
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false

        let openingHoursLabel = UILabel()
        openingHoursLabel.text = "Opening Hours:\n\(openingHours?.joined(separator: "\n") ?? "N/A")"
        openingHoursLabel.textAlignment = .center
        openingHoursLabel.numberOfLines = 0
        openingHoursLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(nameLabel)
        view.addSubview(placeIDLabel)
        view.addSubview(addressLabel)
        view.addSubview(phoneLabel)
        view.addSubview(websiteLabel)
        view.addSubview(ratingLabel)
        view.addSubview(openingHoursLabel)

        NSLayoutConstraint.activate([
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            placeIDLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeIDLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            addressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addressLabel.topAnchor.constraint(equalTo: placeIDLabel.bottomAnchor, constant: 10),
            phoneLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            phoneLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 10),
            websiteLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            websiteLabel.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 10),
            ratingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ratingLabel.topAnchor.constraint(equalTo: websiteLabel.bottomAnchor, constant: 10),
            openingHoursLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openingHoursLabel.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 10)
        ])
    }
}
