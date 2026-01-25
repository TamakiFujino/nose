import UIKit
import FirebaseAuth
import FirebaseFirestore

final class EventDetailViewController: UIViewController {
    
    // MARK: - Properties
    private let event: Event
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var dragIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .thirdColor
        view.layer.cornerRadius = 2.5
        return view
    }()
    
    // Event image (header)
    private lazy var eventImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    // Avatar image (left side)
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .clear
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var locationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "bookmark"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .white
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.sixthColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    init(event: Event) {
        self.event = event
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overCurrentContext
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
        loadAvatarImage()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .clear
        
        // Add subviews
        view.addSubview(containerView)
        containerView.addSubview(scrollView)
        scrollView.addSubview(dragIndicator)
        scrollView.addSubview(eventImageView)
        scrollView.addSubview(avatarImageView)
        scrollView.addSubview(titleLabel)
        scrollView.addSubview(dateLabel)
        scrollView.addSubview(locationLabel)
        scrollView.addSubview(detailsLabel)
        view.addSubview(saveButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Container view constraints
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            // Save button constraints
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            saveButton.widthAnchor.constraint(equalToConstant: 50),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            scrollView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            
            // Drag indicator constraints
            dragIndicator.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            dragIndicator.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 40),
            dragIndicator.heightAnchor.constraint(equalToConstant: 5),
            
            // Event image at top (square, full width)
            eventImageView.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 16),
            eventImageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            eventImageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            eventImageView.heightAnchor.constraint(equalTo: eventImageView.widthAnchor),
            eventImageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Avatar image on left below event image
            avatarImageView.topAnchor.constraint(equalTo: eventImageView.bottomAnchor, constant: 12),
            avatarImageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),
            
            // Title label constraints (on right of avatar)
            titleLabel.topAnchor.constraint(equalTo: eventImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            
            // Date label constraints (on right of avatar)
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            
            // Location label constraints (on right of avatar)
            locationLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            locationLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            
            // Details label constraints
            detailsLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 24),
            detailsLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            detailsLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            detailsLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24)
        ])
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }
    
    private func configureContent() {
        // Title
        titleLabel.text = event.title
        
        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let startDateString = dateFormatter.string(from: event.dateTime.startDate)
        let endDateString = dateFormatter.string(from: event.dateTime.endDate)
        dateLabel.text = "📅 \(startDateString) - \(endDateString)"
        
        // Location
        locationLabel.text = "📍 \(event.location.name)\n\(event.location.address)"
        
        // Details
        if !event.details.isEmpty {
            detailsLabel.text = event.details
        } else {
            detailsLabel.text = "No additional details"
            detailsLabel.textColor = .systemGray
        }
    }
    
    private func loadAvatarImage() {
        // Load event uploaded image (header)
        loadEventImage()
        
        // Load avatar image (left side)
        loadAvatarImageFromFirestore()
    }
    
    private func loadEventImage() {
        // Always prioritize event uploaded image if available
        if !event.images.isEmpty {
            eventImageView.image = event.images[0]
            return
        }
        
        // If no images loaded yet, try to load from Firestore imageURLs
        let db = Firestore.firestore()
        
        FirestorePaths.eventDoc(userId: event.userId, eventId: event.id, db: db)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    Logger.log("Error loading event: \(error.localizedDescription)", level: .error, category: "Event")
                    DispatchQueue.main.async {
                        self?.eventImageView.image = UIImage(systemName: "photo")
                        self?.eventImageView.tintColor = .systemGray3
                    }
                    return
                }
                
                guard let data = snapshot?.data(),
                      let imageURLs = data["imageURLs"] as? [String],
                      let firstImageURL = imageURLs.first,
                      !firstImageURL.isEmpty,
                      let url = URL(string: firstImageURL) else {
                    DispatchQueue.main.async {
                        self?.eventImageView.image = UIImage(systemName: "photo")
                        self?.eventImageView.tintColor = .systemGray3
                    }
                    return
                }
                
                // Download the event image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.eventImageView.image = image
                        }
                    } else {
                        Logger.log("Failed to load event image", level: .warn, category: "Event")
                        DispatchQueue.main.async {
                            self?.eventImageView.image = UIImage(systemName: "photo")
                            self?.eventImageView.tintColor = .systemGray3
                        }
                    }
                }.resume()
            }
    }
    
    private func loadAvatarImageFromFirestore() {
        // Set placeholder while loading
        avatarImageView.image = UIImage(systemName: "person.circle")
        avatarImageView.tintColor = .systemGray3
        
        let db = Firestore.firestore()
        FirestorePaths.eventDoc(userId: event.userId, eventId: event.id, db: db)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    Logger.log("Error loading avatar image: \(error.localizedDescription)", level: .error, category: "Event")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let avatarImageURL = data["avatarImageURL"] as? String,
                      !avatarImageURL.isEmpty,
                      let url = URL(string: avatarImageURL) else {
                    return
                }
                
                // Download avatar image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.avatarImageView.image = image
                            self?.avatarImageView.tintColor = nil
                        }
                    }
                }.resume()
            }
    }
    
    // MARK: - Actions
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if location.y < containerView.frame.minY {
            dismiss(animated: true)
        }
    }
    
    @objc private func saveButtonTapped() {
        let saveVC = SaveToCollectionViewController(event: event)
        saveVC.delegate = self
        present(saveVC, animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension EventDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        return location.y < containerView.frame.minY
    }
}

// MARK: - SaveToCollectionViewControllerDelegate
extension EventDetailViewController: SaveToCollectionViewControllerDelegate {
    func saveToCollectionViewController(_ controller: SaveToCollectionViewController, didSaveEvent event: Event, toCollection collection: PlaceCollection) {
        
        // Animate the save button
        UIView.animate(withDuration: 0.2, animations: {
            self.saveButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.saveButton.transform = .identity
            }
        }
    }
}

