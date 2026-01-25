import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth
import MapKit

final class PlaceDetailViewController: UIViewController {
    
    // MARK: - Properties
    private let place: GMSPlace
    private var photos: [UIImage?] = []
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
    
    // Store constraint references for dynamic updates
    private var nameLabelTopConstraint: NSLayoutConstraint?
    
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
        modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSheetPresentation()  // Configure sheet early so default detent applies
        setupUI()
        fetchPlaceDetails()
        
        // Hide save button if place is from a collection
        saveButton.isHidden = isFromCollection
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func configureSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        
        // Small detent (10% - minimized)
        let smallDetentId = UISheetPresentationController.Detent.Identifier("small")
        let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallDetentId) { context in
            return context.maximumDetentValue * 0.1
        }
        
        // Medium detent (60% - default view)
        let mediumDetentId = UISheetPresentationController.Detent.Identifier("medium")
        let mediumDetent = UISheetPresentationController.Detent.custom(identifier: mediumDetentId) { context in
            return context.maximumDetentValue * 0.6
        }
        
        // Large detent (90% - expanded but grabber still reachable)
        let largeDetentId = UISheetPresentationController.Detent.Identifier("large")
        let largeDetent = UISheetPresentationController.Detent.custom(identifier: largeDetentId) { context in
            return context.maximumDetentValue * 0.9
        }
        
        sheet.detents = [smallDetent, mediumDetent, largeDetent]
        sheet.selectedDetentIdentifier = mediumDetentId  // Start at medium
        sheet.largestUndimmedDetentIdentifier = smallDetentId  // Map interactive when minimized
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Post notification when modal is about to close to remove search marker
        NotificationCenter.default.post(name: NSNotification.Name("PlaceDetailViewControllerWillDismiss"), object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewContentSize()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .clear
        
        // Add subviews
        view.addSubview(containerView)
        containerView.addSubview(scrollView)
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
            // Container view constraints - fill entire view since sheet handles sizing
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
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
            
            // Photo collection view constraints (native sheet grabber handles the handle)
            photoCollectionView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            photoCollectionView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            photoCollectionView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            photoCollectionView.heightAnchor.constraint(equalToConstant: 200),
            photoCollectionView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Page control constraints
            pageControl.topAnchor.constraint(equalTo: photoCollectionView.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            
            // Name label constraints
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
        
        // Setup initial name label constraint
        nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 16)
        nameLabelTopConstraint?.isActive = true
    }
    
    // MARK: - Helper Methods
    private func fetchPlaceDetails() {
        // Check if we already have sufficient place data
        if place.phoneNumber != nil && place.openingHours != nil && place.photos != nil {
            updateUIWithPlaceDetails(place)
            loadPhotos()
            return
        }
        
        guard let placeID = place.placeID else {
            Logger.log("Place ID is nil", level: .error, category: "Place")
            // Use the initial place data since we can't fetch details
            updateUIWithPlaceDetails(place)
            return
        }
        
        // Check cache first
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: placeID) {
            self.detailedPlace = cachedPlace
            DispatchQueue.main.async {
                self.updateUIWithPlaceDetails(cachedPlace)
                self.loadPhotos()
            }
            return
        }
        
        PlacesAPIManager.shared.fetchDetailPlaceDetails(placeID: placeID) { [weak self] (fetchedPlace) in
            if let fetchedPlace = fetchedPlace {
                self?.detailedPlace = fetchedPlace
                
                DispatchQueue.main.async {
                    // Update UI with detailed information
                    if let self = self {
                        self.updateUIWithPlaceDetails(fetchedPlace)
                        // Load photos after getting detailed place info
                        self.loadPhotos()
                    }
                }
            } else {
                Logger.log("Failed to fetch place details, using existing data", level: .warn, category: "Place")
                // Fall back to initial place data
                DispatchQueue.main.async {
                    if let self = self {
                        self.updateUIWithPlaceDetails(self.place)
                    }
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
        // Use detailedPlace if available, otherwise fall back to initial place
        let placeToUse = detailedPlace ?? place
        
        guard let placePhotos = placeToUse.photos, !placePhotos.isEmpty else {
            photoCollectionView.isHidden = true
            pageControl.isHidden = true
            
            // Update name label constraint to be at top when no photos
            nameLabelTopConstraint?.isActive = false
            nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16)
            nameLabelTopConstraint?.isActive = true
            
            updateScrollViewContentSize()
            return
        }
        
        // Show photo collection view and page control
        photoCollectionView.isHidden = false
        pageControl.isHidden = false
        
        // Update name label constraint to be below page control when photos are available
        nameLabelTopConstraint?.isActive = false
        nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 16)
        nameLabelTopConstraint?.isActive = true
        
        // Limit photos to reduce API usage (max 5 photos)
        let maxPhotos = 5
        let limitedPhotos = Array(placePhotos.prefix(maxPhotos))
        
        // Show photo collection view immediately with loading placeholders
        photoCollectionView.isHidden = false
        pageControl.isHidden = false
        pageControl.numberOfPages = limitedPhotos.count
        
        // Initialize photos array with nil to indicate loading state
        self.photos.removeAll()
        for _ in 0..<limitedPhotos.count {
            self.photos.append(nil)
        }
        photoCollectionView.reloadData()
        
        // Load photos one by one with caching
        for (index, photo) in limitedPhotos.enumerated() {
            loadPhoto(at: index, photo: photo, placeID: placeToUse.placeID ?? "")
        }
        
        updateScrollViewContentSize()
    }
    
    // MARK: - Helper Methods
    private func updateScrollViewContentSize() {
        // Calculate the total height needed for all content
        var totalHeight: CGFloat = 0
        
        // Add heights of all components
        totalHeight += 16 // Top padding (native sheet grabber handles the handle)
        totalHeight += photoCollectionView.isHidden ? 0 : (photoCollectionView.frame.height + 8)
        totalHeight += pageControl.isHidden ? 0 : (pageControl.frame.height + 16)
        totalHeight += nameLabel.frame.height + 8
        totalHeight += ratingView.frame.height + 16
        totalHeight += phoneNumberLabel.frame.height + 16
        totalHeight += addressLabel.frame.height + 24
        totalHeight += openingHoursView.frame.height + 24 // Bottom padding
        
        // Update scroll view content size
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: totalHeight)
    }
    
    private func loadPhoto(at index: Int, photo: GMSPlacePhotoMetadata, placeID: String) {
        // Check cache first
        let photoID = "\(placeID)_\(index)"
        if let cachedImage = PlacesCacheManager.shared.getCachedPhoto(for: photoID) {
            DispatchQueue.main.async {
                self.photos[index] = cachedImage
                self.photoCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            return
        }
        
        PlacesAPIManager.shared.loadPlacePhoto(photo: photo, placeID: placeID, photoIndex: index) { [weak self] (image: UIImage?) in
            if let image = image {
                DispatchQueue.main.async {
                    self?.photos[index] = image
                    self?.photoCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
                }
            } else {
                Logger.log("Failed to load photo \(index + 1)", level: .warn, category: "Place")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func saveButtonTapped() {
        let saveVC = SaveToCollectionViewController(place: place)
        saveVC.delegate = self
        present(saveVC, animated: true)
    }
    
    private func savePlaceToCollection(_ collection: PlaceCollection) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Get references to both collections
        _ = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collection.id, db: db)
            
        _ = FirestorePaths.collectionDoc(userId: collection.userId, collectionId: collection.id, db: db)
        
        // First get the current collection data
        // ... existing code ...
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension PlaceDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let image = photos[indexPath.item]
        cell.configure(with: image)
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
    
    private let loadingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .fourthColor
        return indicator
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(loadingView)
        loadingView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            loadingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
    }
    
    func configure(with image: UIImage?) {
        if let image = image {
            // Show the actual image
            imageView.image = image
            imageView.isHidden = false
            loadingView.isHidden = true
            activityIndicator.stopAnimating()
        } else {
            // Show loading state
            imageView.image = nil
            imageView.isHidden = true
            loadingView.isHidden = false
            activityIndicator.startAnimating()
        }
    }
}

// MARK: - SaveToCollectionViewControllerDelegate
extension PlaceDetailViewController: SaveToCollectionViewControllerDelegate {
    func saveToCollectionViewController(_ controller: SaveToCollectionViewController, didSavePlace place: GMSPlace, toCollection collection: PlaceCollection) {
        // Show success animation
        UIView.animate(withDuration: 0.2, animations: {
            self.saveButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.saveButton.transform = .identity
            }
        }
    }
}

