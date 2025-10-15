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
        label.font = AppFonts.displayMedium(24)
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
        ratingLabel.font = AppFonts.title(16)
        
        let starImage = UIImageView(image: UIImage(systemName: "star.fill"))
        starImage.tintColor = .fourthColor
        
        stackView.addArrangedSubview(starImage)
        stackView.addArrangedSubview(ratingLabel)
        
        return stackView
    }()
    
    private lazy var phoneNumberLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFonts.body(16)
        label.textColor = .fourthColor
        label.text = place.phoneNumber ?? "Phone number not available"
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFonts.body(16)
        label.textColor = .fourthColor
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
        titleLabel.font = AppFonts.title(18)
        
        stackView.addArrangedSubview(titleLabel)
        
        if let openingHours = place.openingHours, let weekdayText = openingHours.weekdayText {
            for day in weekdayText {
                let dayLabel = UILabel()
                dayLabel.text = day
                dayLabel.font = AppFonts.body(14)
                stackView.addArrangedSubview(dayLabel)
            }
        } else {
            let noHoursLabel = UILabel()
            noHoursLabel.text = "Opening hours not available"
            noHoursLabel.font = AppFonts.body(14)
            noHoursLabel.textColor = .fourthColor
            stackView.addArrangedSubview(noHoursLabel)
        }
        
        return stackView
    }()
    
    private lazy var saveButton: CustomButton = {
        let button = CustomButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        button.setImage(UIImage(systemName: "bookmark")?.withConfiguration(symbolConfig), for: .normal)
        button.tintColor = .fourthColor
        button.style = .secondary
        button.size = .large
        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = .zero
        button.imageEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    init(place: GMSPlace, isFromCollection: Bool) {
        self.place = place
        self.isFromCollection = isFromCollection
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overCurrentContext
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.log("PlaceDetailViewController - viewDidLoad", level: .debug, category: "PlaceDetail")
        setupUI()
        fetchPlaceDetails()
        
        // Hide save button if place is from a collection
        saveButton.isHidden = isFromCollection
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Logger.log("PlaceDetailViewController - viewWillAppear", level: .debug, category: "PlaceDetail")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Logger.log("PlaceDetailViewController - viewDidAppear", level: .debug, category: "PlaceDetail")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewContentSize()
        Logger.log("Container view height: \(containerView.frame.height)", level: .debug, category: "PlaceDetail")
        // Ensure circular save button
        saveButton.layer.cornerRadius = saveButton.bounds.height / 2
        saveButton.clipsToBounds = true
    }
    
    // MARK: - Setup
    private func setupUI() {
        Logger.log("PlaceDetailViewController - setupUI", level: .debug, category: "PlaceDetail")
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
            dragIndicator.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: DesignTokens.Spacing.sm),
            dragIndicator.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 40),
            dragIndicator.heightAnchor.constraint(equalToConstant: 5),
            
            // Photo collection view constraints
            photoCollectionView.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: DesignTokens.Spacing.lg),
            photoCollectionView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            photoCollectionView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            photoCollectionView.heightAnchor.constraint(equalToConstant: 200),
            photoCollectionView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Page control constraints
            pageControl.topAnchor.constraint(equalTo: photoCollectionView.bottomAnchor, constant: DesignTokens.Spacing.sm),
            pageControl.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            
            // Name label constraints
            nameLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            nameLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            
            // Rating view constraints
            ratingView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            ratingView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            
            // Phone number constraints
            phoneNumberLabel.topAnchor.constraint(equalTo: ratingView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            phoneNumberLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            phoneNumberLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            
            // Address label constraints
            addressLabel.topAnchor.constraint(equalTo: phoneNumberLabel.bottomAnchor, constant: DesignTokens.Spacing.lg),
            addressLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            addressLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            
            // Opening hours view constraints
            openingHoursView.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: DesignTokens.Spacing.xxl),
            openingHoursView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            openingHoursView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            openingHoursView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -DesignTokens.Spacing.xxl)
        ])
        
        // Setup initial name label constraint
        nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: DesignTokens.Spacing.lg)
        nameLabelTopConstraint?.isActive = true
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        Logger.log("PlaceDetailViewController - UI setup completed", level: .debug, category: "PlaceDetail")
    }
    
    // MARK: - Helper Methods
    private func fetchPlaceDetails() {
        Logger.log("Initial place data", level: .debug, category: "PlaceDetail")
        Logger.log("Name: \(place.name ?? "Unknown")", level: .debug, category: "PlaceDetail")
        Logger.log("Place ID: \(place.placeID ?? "Unknown")", level: .debug, category: "PlaceDetail")
        Logger.log("Has photos: \(place.photos != nil)", level: .debug, category: "PlaceDetail")
        Logger.log("Photo count: \(place.photos?.count ?? 0)", level: .debug, category: "PlaceDetail")
        Logger.log("Has phone: \(place.phoneNumber != nil)", level: .debug, category: "PlaceDetail")
        Logger.log("Has opening hours: \(place.openingHours != nil)", level: .debug, category: "PlaceDetail")
        
        // Check if we already have sufficient place data
        if place.phoneNumber != nil && place.openingHours != nil && place.photos != nil {
            Logger.log("Place already has sufficient details, using existing data", level: .info, category: "PlaceDetail")
            updateUIWithPlaceDetails(place)
            loadPhotos()
            return
        }
        
        guard let placeID = place.placeID else {
            Logger.log("Error: Place ID is nil", level: .error, category: "PlaceDetail")
            // Use the initial place data since we can't fetch details
            updateUIWithPlaceDetails(place)
            return
        }
        
        // Check cache first
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: placeID) {
            Logger.log("Using cached place details for: \(placeID)", level: .info, category: "PlaceDetail")
            self.detailedPlace = cachedPlace
            DispatchQueue.main.async {
                self.updateUIWithPlaceDetails(cachedPlace)
                self.loadPhotos()
            }
            return
        }
        
        Logger.log("Fetching detailed place information for: \(placeID)", level: .info, category: "PlaceDetail")
        
        PlacesAPIManager.shared.fetchDetailPlaceDetails(placeID: placeID) { [weak self] (fetchedPlace) in
            if let fetchedPlace = fetchedPlace {
                Logger.log("Successfully fetched place details", level: .info, category: "PlaceDetail")
                Logger.log("Place name: \(fetchedPlace.name ?? "Unknown")", level: .debug, category: "PlaceDetail")
                Logger.log("Has photos: \(fetchedPlace.photos != nil)", level: .debug, category: "PlaceDetail")
                Logger.log("Number of photos: \(fetchedPlace.photos?.count ?? 0)", level: .debug, category: "PlaceDetail")
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
                Logger.log("Failed to fetch place details, using existing data", level: .warn, category: "PlaceDetail")
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
        ratingLabel.font = AppFonts.title(16)
        
        let starImage = UIImageView(image: UIImage(systemName: "star.fill"))
        starImage.tintColor = .fourthColor
        
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
            noHoursLabel.textColor = .fourthColor
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
        
        Logger.log("Loading photos for place: \(placeToUse.name ?? "Unknown")", level: .debug, category: "PlaceDetail")
        Logger.log("Has photos: \(placeToUse.photos != nil)", level: .debug, category: "PlaceDetail")
        Logger.log("Number of photos: \(placeToUse.photos?.count ?? 0)", level: .debug, category: "PlaceDetail")
        
        guard let placePhotos = placeToUse.photos, !placePhotos.isEmpty else {
            Logger.log("No photos available for this place", level: .info, category: "PlaceDetail")
            photoCollectionView.isHidden = true
            pageControl.isHidden = true
            
            // Update name label constraint to be directly below drag indicator when no photos
            nameLabelTopConstraint?.isActive = false
            nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: DesignTokens.Spacing.lg)
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
        
        Logger.log("Found \(placePhotos.count) photos, loading first \(limitedPhotos.count)", level: .debug, category: "PlaceDetail")
        
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
            Logger.log("Starting to load photo \(index + 1) of \(limitedPhotos.count)", level: .debug, category: "PlaceDetail")
            loadPhoto(at: index, photo: photo, placeID: placeToUse.placeID ?? "")
        }
        
        updateScrollViewContentSize()
    }
    
    // MARK: - Helper Methods
    private func updateScrollViewContentSize() {
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
        
        Logger.log("Updated scroll view content size: \(scrollView.contentSize)", level: .debug, category: "PlaceDetail")
    }
    
    private func loadPhoto(at index: Int, photo: GMSPlacePhotoMetadata, placeID: String) {
        // Check cache first
        let photoID = "\(placeID)_\(index)"
        if let cachedImage = PlacesCacheManager.shared.getCachedPhoto(for: photoID) {
            Logger.log("Using cached photo \(index + 1)", level: .debug, category: "PlaceDetail")
            DispatchQueue.main.async {
                self.photos[index] = cachedImage
                self.photoCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            return
        }
        
        Logger.log("Loading photo \(index + 1) for place: \(placeID)", level: .debug, category: "PlaceDetail")
        Logger.log("Photo metadata: \(photo)", level: .debug, category: "PlaceDetail")
        
        PlacesAPIManager.shared.loadPlacePhoto(photo: photo, placeID: placeID, photoIndex: index) { [weak self] (image: UIImage?) in
            if let image = image {
                Logger.log("Successfully loaded photo \(index + 1)", level: .debug, category: "PlaceDetail")
                Logger.log("Image size: \(image.size)", level: .debug, category: "PlaceDetail")
                DispatchQueue.main.async {
                    self?.photos[index] = image
                    self?.photoCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
                }
            } else {
                Logger.log("Failed to load photo \(index + 1)", level: .warn, category: "PlaceDetail")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if location.y < containerView.frame.minY {
            Logger.log("Dismissing due to tap outside", level: .debug, category: "PlaceDetail")
            dismiss(animated: true)
        }
    }
    
    @objc private func saveButtonTapped() {
        Logger.log("Save button tapped for place: \(place.name ?? "Unknown")", level: .info, category: "PlaceDetail")
        let saveVC = SaveToCollectionViewController(place: place)
        saveVC.delegate = self
        present(saveVC, animated: true)
    }
    
    // (Removed) Old savePlaceToCollection kept for reference; saving is handled in SaveToCollectionViewController
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
        view.backgroundColor = UIColor.clear
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
        
        // Keep background fully visible; no dimming animation
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.dimmingView.alpha = 0
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
        let image = photos[indexPath.item]
        Logger.log("Configuring cell \(indexPath.item) with image: \(image != nil ? "loaded" : "loading")", level: .debug, category: "PlaceDetail")
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
        view.backgroundColor = .backgroundSecondary
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
        Logger.log("Saved place '\(place.name ?? "Unknown")' to collection '\(collection.name)'", level: .info, category: "PlaceDetail")
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

