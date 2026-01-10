import UIKit

protocol ImagePickerViewControllerDelegate: AnyObject {
    func imagePickerViewController(_ controller: ImagePickerViewController, didSelectImage imageName: String, imageUrl: String)
}

class ImagePickerViewController: UIViewController {
    // MARK: - Properties
    weak var delegate: ImagePickerViewControllerDelegate?
    private var allIcons: [CollectionManager.CollectionIcon] = []
    private var filteredIcons: [CollectionManager.CollectionIcon] = []
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Category tabs
    private enum IconCategory: String, CaseIterable {
        case all = "All"
        case hobby = "hobby"
        case food = "food"
        case places = "places"
    }
    private var selectedCategory: IconCategory = .all
    
    // MARK: - UI Components
    private lazy var categoryTabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
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
        
        // Calculate item size for 4 columns (images might need more space than symbols)
        let totalWidth = UIScreen.main.bounds.width
        let itemsPerRow: CGFloat = 4
        let spacing: CGFloat = (itemsPerRow - 1) * layout.minimumInteritemSpacing
        let itemWidth = (totalWidth - spacing) / itemsPerRow
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        
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
        setupUI()
        fetchIcons()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(closeButton)
        view.addSubview(categoryTabStackView)
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        
        setupCategoryTabs()
        
        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Category tabs
            categoryTabStackView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 16),
            categoryTabStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            categoryTabStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            categoryTabStackView.heightAnchor.constraint(equalToConstant: 44),
            
            // Collection view
            collectionView.topAnchor.constraint(equalTo: categoryTabStackView.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.tag = IconCategory.allCases.firstIndex(of: category) ?? 0
        button.addTarget(self, action: #selector(categoryTabTapped(_:)), for: .touchUpInside)
        return button
    }
    
    private func updateTabButtonStates() {
        for (index, category) in IconCategory.allCases.enumerated() {
            guard let button = categoryTabStackView.arrangedSubviews[index] as? UIButton else { continue }
            
            let isSelected = category == selectedCategory
            button.backgroundColor = isSelected ? .systemBlue : UIColor.systemGray5
            button.tintColor = isSelected ? .white : .label
            button.setTitleColor(isSelected ? .white : .label, for: .normal)
        }
    }
    
    @objc private func categoryTabTapped(_ sender: UIButton) {
        guard let category = IconCategory.allCases[safe: sender.tag] else { return }
        selectedCategory = category
        updateTabButtonStates()
        filterIcons()
    }
    
    private func filterIcons() {
        if selectedCategory == .all {
            filteredIcons = allIcons
        } else {
            filteredIcons = allIcons.filter { $0.category == selectedCategory.rawValue }
        }
        collectionView.reloadData()
    }
    
    private func fetchIcons() {
        activityIndicator.startAnimating()
        
        // Fetch collection icons from Firebase Storage via CollectionManager
        CollectionManager.shared.fetchCollectionIcons { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                switch result {
                case .success(let fetchedIcons):
                    self?.allIcons = fetchedIcons
                    self?.filterIcons()
                case .failure(let error):
                    print("❌ Error fetching collection icons: \(error.localizedDescription)")
                    // Fall back to empty list if fetch fails
                    self?.allIcons = []
                    self?.filterIcons()
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension ImagePickerViewController: UICollectionViewDelegate, UICollectionViewDataSource {
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
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
            
            // Download image
            let request = URLRequest(url: url)
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                guard let data = data,
                      let image = UIImage(data: data) else {
                    DispatchQueue.main.async {
                        self.stopSkeleton()
                        self.imageView.image = UIImage(systemName: "photo")
                    }
                    return
                }
                
                // Cache the image
                ImagePickerCell.imageCache.setObject(image, forKey: urlString as NSString)
                
                DispatchQueue.main.async {
                    self.imageView.image = image
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
    
    static let imageCache = NSCache<NSString, UIImage>()
    
    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? UIColor.systemGray5 : .clear
        }
    }
}

