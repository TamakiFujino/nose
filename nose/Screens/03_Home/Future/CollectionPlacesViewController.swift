import UIKit
import GooglePlaces

class CollectionPlacesViewController: UIViewController {
    
    // MARK: - Properties
    private let collection: PlaceCollection
    private var places: [PlaceCollection.Place] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    
    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaceTableViewCell.self, forCellReuseIdentifier: "PlaceCell")
        tableView.backgroundColor = .systemBackground
        tableView.rowHeight = 100
        return tableView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = collection.name
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    // MARK: - Initialization
    init(collection: PlaceCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPlaces()
        sessionToken = GMSAutocompleteSessionToken()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadPlaces() {
        places = collection.places
        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CollectionPlacesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
        let place = places[indexPath.row]
        cell.configure(with: place)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let place = places[indexPath.row]
        
        // Fetch full place details from Google Places
        let placesClient = GMSPlacesClient.shared()
        let fields: GMSPlaceField = [.name, .coordinate, .formattedAddress, .phoneNumber, .rating, .openingHours, .photos, .placeID]
        
        placesClient.fetchPlace(fromPlaceID: place.placeId, placeFields: fields, sessionToken: sessionToken) { [weak self] place, error in
            if let error = error {
                print("Error fetching place details: \(error.localizedDescription)")
                return
            }
            
            if let place = place {
                DispatchQueue.main.async {
                    let detailVC = PlaceDetailViewController(place: place)
                    self?.present(detailVC, animated: true)
                }
            }
        }
    }
}

// MARK: - PlaceTableViewCell
class PlaceTableViewCell: UITableViewCell {
    private let placeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(placeImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)
        
        NSLayoutConstraint.activate([
            placeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            placeImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 80),
            placeImageView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            ratingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            ratingLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 16),
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with place: PlaceCollection.Place) {
        nameLabel.text = place.name
        ratingLabel.text = "Rating: \(String(format: "%.1f", place.rating))"
        
        // Fetch place photos
        let placesClient = GMSPlacesClient.shared()
        let fields: GMSPlaceField = [.photos]
        
        placesClient.fetchPlace(fromPlaceID: place.placeId, placeFields: fields, sessionToken: nil) { [weak self] place, error in
            if let error = error {
                print("Error fetching place photos: \(error.localizedDescription)")
                return
            }
            
            if let photoMetadata = place?.photos?.first {
                placesClient.loadPlacePhoto(photoMetadata) { [weak self] photo, error in
                    if let error = error {
                        print("Error loading place photo: \(error.localizedDescription)")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.placeImageView.image = photo
                    }
                }
            }
        }
    }
}
