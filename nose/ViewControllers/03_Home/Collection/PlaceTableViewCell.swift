import UIKit
import GooglePlaces
import FirebaseFirestore

protocol PlaceTableViewCellDelegate: AnyObject {
    func placeTableViewCell(_ cell: PlaceTableViewCell, didTapHeart placeId: String, isHearted: Bool)
}

class PlaceTableViewCell: UITableViewCell {
    // MARK: - Properties
    private var currentPlaceId: String? // Track which place this cell is currently displaying
    
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
    
    private lazy var heartButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "heart")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.setImage(UIImage(systemName: "heart.fill")?.withRenderingMode(.alwaysTemplate), for: .selected)
        button.tintColor = .secondaryLabel // Match bookmark color
        button.adjustsImageWhenHighlighted = false
        button.addTarget(self, action: #selector(heartButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let heartCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel // Match bookmark color
        label.text = "0"
        return label
    }()
    
    private lazy var heartContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.addSubview(heartButton)
        view.addSubview(heartCountLabel)
        
        NSLayoutConstraint.activate([
            heartButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            heartButton.topAnchor.constraint(equalTo: view.topAnchor),
            heartButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heartButton.widthAnchor.constraint(equalToConstant: 44),
            heartButton.heightAnchor.constraint(equalToConstant: 44),
            
            heartCountLabel.leadingAnchor.constraint(equalTo: heartButton.trailingAnchor, constant: 0),
            heartCountLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            heartCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        return view
    }()
    
    private let bottomBorderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        return view
    }()
    
    // MARK: - Properties
    weak var delegate: PlaceTableViewCellDelegate?
    private var placeId: String?
    private var isHearted: Bool = false
    private var heartCount: Int = 0

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
        currentPlaceId = nil // Clear the tracked place ID
        placeId = nil
        isHearted = false
        heartCount = 0
        heartButton.isSelected = false
        heartCountLabel.text = "0"
    }

    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(placeImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(visitedIndicator)
        contentView.addSubview(heartContainerView)
        contentView.addSubview(bottomBorderView)

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
            visitedIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            heartContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            heartContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Custom bottom border with consistent margins on both sides
            bottomBorderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bottomBorderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bottomBorderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBorderView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    
    @objc private func heartButtonTapped() {
        guard let placeId = placeId else { return }
        let newHeartedState = !isHearted
        delegate?.placeTableViewCell(self, didTapHeart: placeId, isHearted: newHeartedState)
    }
    
    // MARK: - Public Methods
    /// Update heart state without reloading the entire cell (prevents image flicker)
    func updateHeartState(isHearted: Bool, heartCount: Int) {
        self.isHearted = isHearted
        self.heartCount = heartCount
        heartButton.isSelected = isHearted
        heartCountLabel.text = "\(heartCount)"
        
        // Animate the heart with a pink flash and scale effect
        animateHeart(isHearted: isHearted)
    }
    
    private func animateHeart(isHearted: Bool) {
        // Flash pink color
        heartButton.tintColor = .systemPink
        
        // Scale up animation
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut], animations: {
            self.heartButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            // Scale back down and return to gray
            UIView.animate(withDuration: 0.15, delay: 0.1, options: [.curveEaseIn], animations: {
                self.heartButton.transform = .identity
            }) { _ in
                // Return to gray color after animation
                UIView.animate(withDuration: 0.2) {
                    self.heartButton.tintColor = .secondaryLabel
                }
            }
        }
    }

    // MARK: - Configuration
    func configure(with place: PlaceCollection.Place, isHearted: Bool = false, heartCount: Int = 0, showHeartButton: Bool = true) {
        // Store the placeId to verify in async callbacks
        currentPlaceId = place.placeId
        self.placeId = place.placeId
        self.isHearted = isHearted
        self.heartCount = heartCount
        
        // Clear image immediately to prevent showing stale images from cell reuse
        placeImageView.image = nil
        
        nameLabel.text = place.name
        ratingLabel.text = "Rating: \(String(format: "%.1f", place.rating))"
        
        // Update heart button state and visibility
        heartButton.isSelected = isHearted
        heartCountLabel.text = "\(heartCount)"
        heartContainerView.isHidden = !showHeartButton
        
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
            // Verify cell hasn't been reused before setting cached image
            if currentPlaceId == place.placeId {
            placeImageView.image = cachedImage
            }
            return
        }
        
        // Fetch photo from Places API (only first photo to save API calls)
        PlacesAPIManager.shared.fetchPhotosOnly(placeID: place.placeId) { [weak self] fetchedPlace in
            // Verify cell hasn't been reused before processing
            guard let self = self, self.currentPlaceId == place.placeId else { return }
            
            // Only load the first photo to minimize API usage
            if let photoMetadata = fetchedPlace?.photos?.first {
                PlacesAPIManager.shared.loadPlacePhoto(photo: photoMetadata, placeID: place.placeId, photoIndex: 0) { [weak self] photo in
                    // Verify cell hasn't been reused before setting image
                    guard let self = self, self.currentPlaceId == place.placeId else { return }
                    
                    if let photo = photo {
                        DispatchQueue.main.async {
                            // Double-check one more time before setting image
                            if self.currentPlaceId == place.placeId {
                                self.placeImageView.image = photo
                            }
                        }
                    }
                }
            }
        }
    }
    
    func configureWithEvent(_ event: Event) {
        // Store the eventId to verify in async callbacks
        currentPlaceId = event.id
        
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
            // Verify cell hasn't been reused before setting image
            if currentPlaceId == event.id {
            placeImageView.image = event.images[0]
            }
        } else {
            loadEventImage(eventId: event.id, userId: event.userId)
        }
    }
    
    private func loadEventImage(eventId: String, userId: String) {
        // Show placeholder while loading
        placeImageView.image = UIImage(systemName: "photo")
        placeImageView.tintColor = .thirdColor
        
        let db = Firestore.firestore()
        FirestorePaths.eventDoc(userId: userId, eventId: eventId, db: db)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                // Verify cell hasn't been reused before processing
                guard self.currentPlaceId == eventId else { return }
                
                if let error = error {
                    Logger.log("Error loading event image: \(error.localizedDescription)", level: .error, category: "Collection")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let imageURLs = data["imageURLs"] as? [String],
                      let firstImageURL = imageURLs.first,
                      !firstImageURL.isEmpty,
                      let url = URL(string: firstImageURL) else {
                    return
                }
                
                // Download event image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            // Verify cell hasn't been reused before setting image
                            if self.currentPlaceId == eventId {
                                self.placeImageView.image = image
                                self.placeImageView.contentMode = .scaleAspectFill
                            }
                        }
                    }
                }.resume()
            }
    }
} 
