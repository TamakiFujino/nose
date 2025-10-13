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
        view.backgroundColor = .firstColor
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
        imageView.backgroundColor = .thirdColor
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
        label.font = AppFonts.displayMedium(24)
        label.textColor = .sixthColor
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFonts.body(16)
        label.textColor = .fourthColor
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var locationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFonts.body(16)
        label.textColor = .fourthColor
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFonts.body(16)
        label.textColor = .sixthColor
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var saveButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "bookmark"), for: .normal)
        button.tintColor = .fourthColor
        button.style = .secondary
        button.size = .large
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
            detailsLabel.textColor = .fourthColor
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
            print("🖼️ Using event uploaded image")
            eventImageView.image = event.images[0]
            return
        }
        
        // If no images loaded yet, try to load from Firestore imageURLs
        print("🔍 Loading event image from Firestore for event: \(event.id)")
        let db = Firestore.firestore()
        
        db.collection("users")
            .document(event.userId)
            .collection("events")
            .document(event.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading event: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.eventImageView.image = UIImage(systemName: "photo")
                        self?.eventImageView.tintColor = .thirdColor
                    }
                    return
                }
                
                guard let data = snapshot?.data(),
                      let imageURLs = data["imageURLs"] as? [String],
                      let firstImageURL = imageURLs.first,
                      !firstImageURL.isEmpty,
                      let url = URL(string: firstImageURL) else {
                    print("⚠️ No event image URL found")
                    DispatchQueue.main.async {
                        self?.eventImageView.image = UIImage(systemName: "photo")
                        self?.eventImageView.tintColor = .borderSubtle
                    }
                    return
                }
                
                print("📥 Downloading event image from: \(firstImageURL)")
                
                // Download the event image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        print("✅ Successfully loaded event image")
                        DispatchQueue.main.async {
                            self?.eventImageView.image = image
                        }
                    } else {
                        print("❌ Failed to load event image")
                        DispatchQueue.main.async {
                            self?.eventImageView.image = UIImage(systemName: "photo")
                            self?.eventImageView.tintColor = .thirdColor
                        }
                    }
                }.resume()
            }
    }
    
    private func loadAvatarImageFromFirestore() {
        // Set placeholder while loading
        avatarImageView.image = UIImage(systemName: "person.circle")
        avatarImageView.tintColor = .thirdColor
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(event.userId)
            .collection("events")
            .document(event.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading avatar image: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let avatarImageURL = data["avatarImageURL"] as? String,
                      !avatarImageURL.isEmpty,
                      let url = URL(string: avatarImageURL) else {
                    print("⚠️ No avatar image URL found for event")
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
        print("💾 Save event to collection: \(event.title)")
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
        print("✅ Saved event '\(event.title)' to collection '\(collection.name)'")
        
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

