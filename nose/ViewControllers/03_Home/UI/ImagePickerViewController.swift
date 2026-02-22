import UIKit

protocol ImagePickerViewControllerDelegate: AnyObject {
    func imagePickerViewController(_ controller: ImagePickerViewController, didSelectImage imageName: String, imageUrl: String)
}

class ImagePickerViewController: UIViewController {
    // MARK: - Properties
    weak var delegate: ImagePickerViewControllerDelegate?
    private var allIcons: [CollectionManager.CollectionIcon] = [] // Cache of all loaded icons
    private var filteredIcons: [CollectionManager.CollectionIcon] = []
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Configure image cache limits
    private func configureImageCache() {
        // Set cache limits: 200 images max, 50MB cost limit
        imageCache.countLimit = 200
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Configure URLCache for HTTP-level caching
        let urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, // 50MB memory
                                diskCapacity: 200 * 1024 * 1024,  // 200MB disk
                                diskPath: "collection_icons_cache")
        URLCache.shared = urlCache
    }
    
    // Category tabs
    private enum IconCategory: String, CaseIterable {
        case hobby = "Hobby"
        case food = "Food"
        case sports = "Sports"
        case symbol = "Symbol"
    }
    private var selectedCategory: IconCategory = .hobby // Default to first category
    private var loadedCategories: Set<String> = [] // Track which categories have been loaded
    
    // MARK: - UI Components
    private lazy var categoryTabScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        return scrollView
    }()
    
    private lazy var categoryTabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        
        // Calculate item size for 6 columns (will be recalculated in viewDidLayoutSubviews for margins)
        let itemsPerRow: CGFloat = 6
        layout.itemSize = CGSize(width: 50, height: 50) // Temporary size, will be updated
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImagePickerCell.self, forCellWithReuseIdentifier: "ImagePickerCell")
        return collectionView
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureImageCache()
        setupUI()
        fetchIcons()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionViewItemSize()
    }
    
    private func updateCollectionViewItemSize() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        
        let itemsPerRow: CGFloat = 6
        let collectionViewWidth = collectionView.bounds.width
        let spacing: CGFloat = (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = (collectionViewWidth - spacing) / itemsPerRow
        
        if layout.itemSize.width != itemWidth {
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.invalidateLayout()
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(closeButton)
        view.addSubview(categoryTabScrollView)
        categoryTabScrollView.addSubview(categoryTabStackView)
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        
        setupCategoryTabs()
        
        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Category tabs scroll view
            categoryTabScrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 16),
            categoryTabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryTabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryTabScrollView.heightAnchor.constraint(equalToConstant: 30),
            
            // Category tabs stack view inside scroll view
            categoryTabStackView.leadingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            categoryTabStackView.trailingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            categoryTabStackView.topAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.topAnchor),
            categoryTabStackView.bottomAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.bottomAnchor),
            categoryTabStackView.heightAnchor.constraint(equalTo: categoryTabScrollView.frameLayoutGuide.heightAnchor),
            
            // Collection view
            collectionView.topAnchor.constraint(equalTo: categoryTabScrollView.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCategoryTabs() {
        for category in IconCategory.allCases {
            let button = createTabButton(for: category)
            categoryTabStackView.addArrangedSubview(button)
        }
        updateTabButtonStates()
    }
    
    private func createTabButton(for category: IconCategory) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(category.rawValue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .secondColor
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        button.layer.masksToBounds = true
        button.tag = IconCategory.allCases.firstIndex(of: category) ?? 0
        button.addTarget(self, action: #selector(categoryTabTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Padding so text doesn't touch edges
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        // Set height constraint
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        // Minimum width for easy tapping, but size to content
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        
        // Allow button to size to content
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return button
    }
    
    private func updateTabButtonStates() {
        for (index, category) in IconCategory.allCases.enumerated() {
            guard let button = categoryTabStackView.arrangedSubviews[index] as? UIButton else { continue }
            
            let isSelected = category == selectedCategory
            // Active tab: themeBlue background with white text
            // Inactive tab: secondColor background with black text
            button.backgroundColor = isSelected ? .themeBlue : .secondColor
            button.setTitleColor(isSelected ? .white : .black, for: .normal)
            button.layer.cornerRadius = 16
        }
    }
    
    @objc private func categoryTabTapped(_ sender: UIButton) {
        guard sender.tag < IconCategory.allCases.count else { return }
        let category = IconCategory.allCases[sender.tag]
        selectedCategory = category
        updateTabButtonStates()
        loadIconsForSelectedCategory()
    }
    
    private func loadIconsForSelectedCategory() {
        let categoryLowercase = selectedCategory.rawValue.lowercased()
        
        // Check if category is already loaded in this view controller instance
        if loadedCategories.contains(categoryLowercase) {
            // Just filter existing icons
            filterIcons()
            return
        }
        
        // Load icons for this category (will use cache if available)
        activityIndicator.startAnimating()
        
        CollectionManager.shared.fetchCollectionIcons(for: categoryLowercase) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                switch result {
                case .success(let fetchedIcons):
                    // Remove existing icons for this category first to avoid duplicates
                    self?.allIcons.removeAll { $0.category.lowercased() == categoryLowercase }
                    
                    // Add the fetched icons and mark category as loaded
                    self?.allIcons.append(contentsOf: fetchedIcons)
                    self?.loadedCategories.insert(categoryLowercase)
                    self?.filterIcons()
                case .failure(let error):
                    Logger.log("Error fetching collection icons for \(categoryLowercase): \(error.localizedDescription)", level: .error, category: "ImagePicker")
                    // Keep existing icons, just filter
                    self?.filterIcons()
                }
            }
        }
    }
    
    private func filterIcons() {
        // Filter by category (matching lowercase category values from icons)
        let categoryLowercase = selectedCategory.rawValue.lowercased()
        filteredIcons = allIcons.filter { $0.category.lowercased() == categoryLowercase }
        collectionView.reloadData()
    }
    
    private func fetchIcons() {
        // Load icons for the initial selected category (hobby by default)
        loadIconsForSelectedCategory()
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension ImagePickerViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredIcons.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImagePickerCell", for: indexPath) as! ImagePickerCell
        
        // Show remote images
        let icon = filteredIcons[indexPath.item]
        cell.configure(with: icon.url, sfSymbolName: nil)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let icon = filteredIcons[indexPath.item]
        delegate?.imagePickerViewController(self, didSelectImage: icon.name, imageUrl: icon.url)
        dismiss(animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // Preload images for nearby cells to improve scrolling performance
        preloadImagesForNearbyCells(around: indexPath)
    }
    
    private func preloadImagesForNearbyCells(around indexPath: IndexPath) {
        // Preload images for cells 5 positions ahead and behind
        let preloadRange = 5
        let startIndex = max(0, indexPath.item - preloadRange)
        let endIndex = min(filteredIcons.count - 1, indexPath.item + preloadRange)
        
        for i in startIndex...endIndex {
            guard i != indexPath.item, i < filteredIcons.count else { continue }
            let icon = filteredIcons[i]
            
            // Only preload if not already cached
            if ImagePickerCell.imageCache.object(forKey: icon.url as NSString) == nil,
               let url = URL(string: icon.url) {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                
                // Check URLCache first
                if URLCache.shared.cachedResponse(for: request) == nil {
                    // Preload in background
                    URLSession.shared.dataTask(with: request).resume()
                }
            }
        }
    }
}

// MARK: - ImagePickerCell
class ImagePickerCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let skeletonView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()
    
    private let skeletonLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(skeletonView)
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            skeletonView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            skeletonView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            skeletonView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            skeletonView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.6)
        ])
        
        setupSkeletonLayer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        skeletonLayer.frame = skeletonView.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        startSkeleton()
    }
    
    private func setupSkeletonLayer() {
        skeletonLayer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray4.cgColor,
            UIColor.systemGray5.cgColor
        ]
        skeletonLayer.startPoint = CGPoint(x: 0, y: 0.5)
        skeletonLayer.endPoint = CGPoint(x: 1, y: 0.5)
        skeletonLayer.locations = [0, 0.5, 1]
        skeletonView.layer.addSublayer(skeletonLayer)
        startSkeleton()
    }
    
    private func startSkeleton() {
        skeletonView.isHidden = false
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1, -0.5, 0]
        animation.toValue = [1, 1.5, 2]
        animation.duration = 1.0
        animation.repeatCount = .infinity
        skeletonLayer.add(animation, forKey: "skeleton")
    }
    
    private func stopSkeleton() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        skeletonLayer.removeAnimation(forKey: "skeleton")
        skeletonView.isHidden = true
        CATransaction.commit()
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)
        
        // If image is already smaller than maxDimension, return as-is
        guard maxSize > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Create resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    func configure(with urlString: String?, sfSymbolName: String?) {
        if let urlString = urlString, let url = URL(string: urlString) {
            // Check cache first
            if let cachedImage = ImagePickerCell.imageCache.object(forKey: urlString as NSString) {
                imageView.image = cachedImage
                stopSkeleton()
                return
            }
            
            startSkeleton()
            imageView.image = nil
            
            // Download image with caching support
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad // Use cache if available, otherwise load
            
            // Check URLCache first
            if let cachedResponse = URLCache.shared.cachedResponse(for: request),
               let cachedImage = UIImage(data: cachedResponse.data) {
                let resizedImage = self.resizeImage(cachedImage, maxDimension: 150)
                ImagePickerCell.imageCache.setObject(resizedImage, forKey: urlString as NSString)
                DispatchQueue.main.async {
                    self.imageView.image = resizedImage
                    self.stopSkeleton()
                }
                return
            }
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                guard let data = data,
                      let image = UIImage(data: data) else {
                    DispatchQueue.main.async {
                        // When icon fails to load, show gray placeholder (keep skeleton visible)
                        self.imageView.image = nil
                        self.startSkeleton()
                    }
                    return
                }
                
                // Resize image to thumbnail size for memory efficiency (max 150px)
                let maxThumbnailSize: CGFloat = 150
                let resizedImage = self.resizeImage(image, maxDimension: maxThumbnailSize)
                
                // Cache the resized image in memory (NSCache)
                ImagePickerCell.imageCache.setObject(resizedImage, forKey: urlString as NSString)
                
                // Also cache the original response in URLCache for disk persistence
                if let httpResponse = response as? HTTPURLResponse {
                    let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
                    URLCache.shared.storeCachedResponse(cachedResponse, for: request)
                }
                
                DispatchQueue.main.async {
                    self.imageView.image = resizedImage
                    self.stopSkeleton()
                }
            }.resume()
        } else if let symbolName = sfSymbolName {
            imageView.image = UIImage(systemName: symbolName)
            stopSkeleton()
        } else {
            imageView.image = nil
            startSkeleton()
        }
    }
    
    static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Configure cache limits: 200 images max, 50MB cost limit
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()
    
    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? UIColor.systemGray5 : .clear
        }
    }
}


