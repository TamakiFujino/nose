import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth

final class PlaceDetailViewController: UIViewController {
    
    // MARK: - Properties
    private let place: GMSPlace
    private var photos: [UIImage] = []
    private var currentPhotoIndex = 0
    private var detailedPlace: GMSPlace?
    private var isFromCollection: Bool
    
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
    
    private lazy var photoCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        return collectionView
    }()
    
    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.currentPageIndicatorTintColor = .fifthColor
        pageControl.pageIndicatorTintColor = .thirdColor
        return pageControl
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.text = place.name
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var ratingView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        
        // Rating stars
        let ratingLabel = UILabel()
        ratingLabel.text = String(format: "%.1f", place.rating)
        ratingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let starImage = UIImageView(image: UIImage(systemName: "star.fill"))
        starImage.tintColor = .fourthColor
        
        stackView.addArrangedSubview(starImage)
        stackView.addArrangedSubview(ratingLabel)
        
        return stackView
    }()
    
    private lazy var phoneNumberLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .fourthColor
        label.text = place.phoneNumber ?? "Phone number not available"
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.text = place.formattedAddress
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var openingHoursView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 8
        
        let titleLabel = UILabel()
        titleLabel.text = "Opening Hours"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        stackView.addArrangedSubview(titleLabel)
        
        if let openingHours = place.openingHours, let weekdayText = openingHours.weekdayText {
            for day in weekdayText {
                let dayLabel = UILabel()
                dayLabel.text = day
                dayLabel.font = .systemFont(ofSize: 14)
                stackView.addArrangedSubview(dayLabel)
            }
        } else {
            let noHoursLabel = UILabel()
            noHoursLabel.text = "Opening hours not available"
            noHoursLabel.font = .systemFont(ofSize: 14)
            noHoursLabel.textColor = .systemGray
            stackView.addArrangedSubview(noHoursLabel)
        }
        
        return stackView
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
    init(place: GMSPlace, isFromCollection: Bool) {
        self.place = place
        self.isFromCollection = isFromCollection
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("PlaceDetailViewController - viewDidLoad")
        setupUI()
        fetchPlaceDetails()
        
        // Hide save button if place is from a collection
        saveButton.isHidden = isFromCollection
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("PlaceDetailViewController - viewWillAppear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("PlaceDetailViewController - viewDidAppear")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Calculate the total height needed for all content
        var totalHeight: CGFloat = 0
        
        // Add heights of all components
        totalHeight += dragIndicator.frame.height + 8 // Top padding
        totalHeight += photoCollectionView.isHidden ? 0 : (photoCollectionView.frame.height + 8)
        totalHeight += pageControl.isHidden ? 0 : (pageControl.frame.height + 16)
        totalHeight += nameLabel.frame.height + 8
        totalHeight += ratingView.frame.height + 16
        totalHeight += phoneNumberLabel.frame.height + 16
        totalHeight += addressLabel.frame.height + 24
        totalHeight += openingHoursView.frame.height + 24 // Bottom padding
        
        // Update scroll view content size
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight)
        
        print("Scroll view content size: \(scrollView.contentSize)")
        print("Container view height: \(containerView.frame.height)")
    }
    
    // MARK: - Setup
    private func setupUI() {
        print("PlaceDetailViewController - setupUI")
        view.backgroundColor = .clear
        
        // Add subviews
        view.addSubview(containerView)
        containerView.addSubview(scrollView)
        scrollView.addSubview(dragIndicator)
        scrollView.addSubview(photoCollectionView)
        scrollView.addSubview(pageControl)
        scrollView.addSubview(nameLabel)
        scrollView.addSubview(ratingView)
        scrollView.addSubview(phoneNumberLabel)
        scrollView.addSubview(addressLabel)
        scrollView.addSubview(openingHoursView)
        view.addSubview(saveButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Container view constraints
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7),
            
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
            
            // Photo collection view constraints
            photoCollectionView.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 16),
            photoCollectionView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            photoCollectionView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            photoCollectionView.heightAnchor.constraint(equalToConstant: 200),
            photoCollectionView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Page control constraints
            pageControl.topAnchor.constraint(equalTo: photoCollectionView.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            
            // Name label constraints
            nameLabel.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            
            // Rating view constraints
            ratingView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            ratingView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            
            // Phone number constraints
            phoneNumberLabel.topAnchor.constraint(equalTo: ratingView.bottomAnchor, constant: 16),
            phoneNumberLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            phoneNumberLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            
            // Address label constraints
            addressLabel.topAnchor.constraint(equalTo: phoneNumberLabel.bottomAnchor, constant: 16),
            addressLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            addressLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            
            // Opening hours view constraints
            openingHoursView.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 24),
            openingHoursView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            openingHoursView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            openingHoursView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24)
        ])
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        print("PlaceDetailViewController - UI setup completed")
    }
    
    // MARK: - Helper Methods
    private func fetchPlaceDetails() {
        guard let placeID = place.placeID else {
            print("Error: Place ID is nil")
            // Use the initial place data since we can't fetch details
            updateUIWithPlaceDetails(place)
            return
        }
        
        print("Fetching detailed place information for: \(placeID)")
        let fields: GMSPlaceField = [.name, .formattedAddress, .phoneNumber, .rating, .openingHours, .photos]
        
        GMSPlacesClient.shared().fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { [weak self] (fetchedPlace, error) in
            if let error = error {
                print("Error fetching place details: \(error.localizedDescription)")
                // Fall back to initial place data
                DispatchQueue.main.async {
                    if let self = self {
                        self.updateUIWithPlaceDetails(self.place)
                    }
                }
                return
            }
            
            guard let fetchedPlace = fetchedPlace else {
                print("No place details returned")
                // Fall back to initial place data
                DispatchQueue.main.async {
                    if let self = self {
                        self.updateUIWithPlaceDetails(self.place)
                    }
                }
                return
            }
            
            print("Successfully fetched place details")
            self?.detailedPlace = fetchedPlace
            
            DispatchQueue.main.async {
                // Update UI with detailed information
                if let self = self {
                    self.updateUIWithPlaceDetails(fetchedPlace)
                    // Load photos after getting detailed place info
                    self.loadPhotos()
                }
            }
        }
    }
    
    private func updateUIWithPlaceDetails(_ place: GMSPlace) {
        // Update rating
        let rating = place.rating
        let ratingLabel = UILabel()
        ratingLabel.text = String(format: "%.1f", rating)
        ratingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let starImage = UIImageView(image: UIImage(systemName: "star.fill"))
        starImage.tintColor = .systemYellow
        
        ratingView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        ratingView.addArrangedSubview(starImage)
        ratingView.addArrangedSubview(ratingLabel)
        
        // Update phone number
        phoneNumberLabel.text = place.phoneNumber ?? "Phone number not available"
        
        // Update opening hours
        openingHoursView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let titleLabel = UILabel()
        titleLabel.text = "Opening Hours"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        openingHoursView.addArrangedSubview(titleLabel)
        
        if let openingHours = place.openingHours, let weekdayText = openingHours.weekdayText {
            for day in weekdayText {
                let dayLabel = UILabel()
                dayLabel.text = day
                dayLabel.font = .systemFont(ofSize: 14)
                openingHoursView.addArrangedSubview(dayLabel)
            }
        } else {
            let noHoursLabel = UILabel()
            noHoursLabel.text = "Opening hours not available"
            noHoursLabel.font = .systemFont(ofSize: 14)
            noHoursLabel.textColor = .systemGray
            openingHoursView.addArrangedSubview(noHoursLabel)
        }
        
        // Load photos if available
        if place.photos != nil {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        guard let place = detailedPlace, let photos = place.photos, !photos.isEmpty else {
            print("No photos available for this place")
            photoCollectionView.isHidden = true
            pageControl.isHidden = true
            nameLabel.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 16).isActive = true
            return
        }
        
        print("Found \(photos.count) photos")
        for (index, photo) in photos.enumerated() {
            print("Loading photo \(index + 1)")
            GMSPlacesClient.shared().loadPlacePhoto(photo) { [weak self] (image: UIImage?, error: Error?) in
                if let error = error {
                    print("Error loading photo: \(error.localizedDescription)")
                    return
                }
                
                if let image = image {
                    print("Successfully loaded photo \(index + 1)")
                    DispatchQueue.main.async {
                        self?.photos.append(image)
                        self?.photoCollectionView.reloadData()
                        self?.pageControl.numberOfPages = self?.photos.count ?? 0
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if location.y < containerView.frame.minY {
            print("PlaceDetailViewController - Dismissing due to tap outside")
            dismiss(animated: true)
        }
    }
    
    @objc private func saveButtonTapped() {
        print("Save button tapped for place: \(place.name ?? "Unknown")")
        let saveVC = SaveToCollectionViewController(place: place)
        saveVC.delegate = self
        present(saveVC, animated: true)
    }
    
    private func savePlaceToCollection(_ collection: PlaceCollection) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Get references to both collections
        let userCollectionRef = db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            
        let ownerCollectionRef = db.collection("users")
            .document(collection.userId)  // This is the owner's ID
            .collection("collections")
            .document(collection.id)
        
        print("📄 Firestore path: users/\(currentUserId)/collections/\(collection.id)")
        print("📄 Owner path: users/\(collection.userId)/collections/\(collection.id)")
        
        // First get the current collection data
        // ... existing code ...
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PlaceDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        return location.y < containerView.frame.minY
    }
}

// MARK: - UIViewControllerTransitioningDelegate
extension PlaceDetailViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return HalfModalPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

// MARK: - HalfModalPresentationController
class HalfModalPresentationController: UIPresentationController {
    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.alpha = 0
        return view
    }()
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        return CGRect(x: 0,
                     y: containerView.bounds.height * 0.4,
                     width: containerView.bounds.width,
                     height: containerView.bounds.height * 0.6)
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        dimmingView.frame = containerView.bounds
        containerView.addSubview(dimmingView)
        
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.dimmingView.alpha = 1
        })
    }
    
    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.dimmingView.alpha = 0
        })
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension PlaceDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.imageView.image = photos[indexPath.item]
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.frame.width)
        pageControl.currentPage = page
    }
}

// MARK: - PhotoCell
class PhotoCell: UICollectionViewCell {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - SaveToCollectionViewControllerDelegate
extension PlaceDetailViewController: SaveToCollectionViewControllerDelegate {
    func saveToCollectionViewController(_ controller: SaveToCollectionViewController, didSavePlace place: GMSPlace, toCollection collection: PlaceCollection) {
        print("Saved place '\(place.name ?? "Unknown")' to collection '\(collection.name)'")
        // TODO: Implement actual saving to your data source
        // For now, just show a success animation
        UIView.animate(withDuration: 0.2, animations: {
            self.saveButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.saveButton.transform = .identity
            }
        }
    }
}
