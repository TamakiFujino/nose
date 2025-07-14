import UIKit
import GooglePlaces

class PlaceTableViewCell: UITableViewCell {
    // MARK: - UI Components
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

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
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

    // MARK: - Configuration
    func configure(with place: PlaceCollection.Place) {
        nameLabel.text = place.name
        ratingLabel.text = "Rating: \(String(format: "%.1f", place.rating))"
        
        // Check cache first for this place's photo
        let photoID = "\(place.placeId)_photo"
        if let cachedImage = PlacesCacheManager.shared.getCachedPhoto(for: photoID) {
            placeImageView.image = cachedImage
            return
        }
        
        // Fetch photo from Places API (only first photo to save API calls)
        PlacesAPIManager.shared.fetchPhotosOnly(placeID: place.placeId) { [weak self] fetchedPlace in
            // Only load the first photo to minimize API usage
            if let photoMetadata = fetchedPlace?.photos?.first {
                PlacesAPIManager.shared.loadPlacePhoto(photo: photoMetadata, placeID: place.placeId, photoIndex: 0) { [weak self] photo in
                    if let photo = photo {
                        DispatchQueue.main.async {
                            self?.placeImageView.image = photo
                        }
                    }
                }
            }
        }
    }
} 
