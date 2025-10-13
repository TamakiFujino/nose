import UIKit
import GooglePlaces
import FirebaseFirestore

class PlaceTableViewCell: UITableViewCell {
    // MARK: - UI Components
    private let placeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .thirdColor
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .sixthColor
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .fourthColor
        return label
    }()
    
    private let visitedIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .thirdColor
        view.layer.cornerRadius = 12
        view.isHidden = true
        
        let checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.tintColor = .firstColor
        checkmarkImageView.contentMode = .scaleAspectFit
        
        view.addSubview(checkmarkImageView)
        NSLayoutConstraint.activate([
            checkmarkImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        return view
    }()

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Clear images to prevent showing stale data
        placeImageView.image = nil
        placeImageView.tintColor = nil
        nameLabel.text = nil
        ratingLabel.text = nil
    }

    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(placeImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(visitedIndicator)

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
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            visitedIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            visitedIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            visitedIndicator.widthAnchor.constraint(equalToConstant: 24),
            visitedIndicator.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    // MARK: - Configuration
    func configure(with place: PlaceCollection.Place) {
        nameLabel.text = place.name
        ratingLabel.text = "Rating: \(String(format: "%.1f", place.rating))"
        
        // Change background color based on visited status
        if place.visited {
            backgroundColor = .secondColor
        } else {
            backgroundColor = .firstColor
        }
        
        // Hide visited indicator since we're using background color instead
        visitedIndicator.isHidden = true
        
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
    
    func configureWithEvent(_ event: Event) {
        nameLabel.text = event.title
        
        // Format date for event
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, HH:mm"
        let dateString = dateFormatter.string(from: event.dateTime.startDate)
        ratingLabel.text = "⚡ \(dateString) • \(event.location.name)"
        
        backgroundColor = .firstColor
        visitedIndicator.isHidden = true
        
        // Clear image immediately to prevent showing old images
        placeImageView.image = nil
        placeImageView.tintColor = nil
        placeImageView.contentMode = .scaleAspectFill
        
        // Use already loaded image if available
        if !event.images.isEmpty {
            print("📸 Using loaded event image for: \(event.title)")
            placeImageView.image = event.images[0]
        } else {
            print("📥 Need to download event image for: \(event.title)")
            loadEventImage(eventId: event.id, userId: event.userId)
        }
    }
    
    private func loadEventImage(eventId: String, userId: String) {
        // Show placeholder while loading
        placeImageView.image = UIImage(systemName: "photo")
        placeImageView.tintColor = .thirdColor
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("events")
            .document(eventId)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading event image: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let imageURLs = data["imageURLs"] as? [String],
                      let firstImageURL = imageURLs.first,
                      !firstImageURL.isEmpty,
                      let url = URL(string: firstImageURL) else {
                    print("⚠️ No event image URL found")
                    return
                }
                
                // Download event image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.placeImageView.image = image
                            self?.placeImageView.contentMode = .scaleAspectFill
                        }
                    }
                }.resume()
            }
    }
} 
