import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

// MARK: - ImageContainer Helper
private class ImageContainer {
    private var _images: [(String, UIImage?)] = []
    private let queue = DispatchQueue(label: "com.nose.avatarImages", attributes: .concurrent)
    
    var images: [(String, UIImage?)] {
        queue.sync { _images }
    }
    
    func append(_ item: (String, UIImage?)) {
        queue.async(flags: .barrier) {
            self._images.append(item)
        }
    }
}

class ProfileImageViewController: UIViewController {
    
    // MARK: - Properties
    private var avatarImages: [(collectionId: String, image: UIImage?)] = []
    private var selectedIndex: Int?
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // Callback to pass selected image back
    var onImageSelected: ((UIImage) -> Void)?
    
    // Default avatar image
    private var defaultAvatarImage: UIImage? {
        return UIImage(named: "avatar")
    }
    
    // MARK: - UI Components
    private lazy var previewContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondColor
        return view
    }()
    
    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        // Make preview image 2.5x bigger by setting a larger size
        let previewWidth = UIScreen.main.bounds.width * 0.75 // 75% of screen width
        imageView.widthAnchor.constraint(equalToConstant: previewWidth).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: previewWidth * 1.5).isActive = true
        return imageView
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        
        // Calculate item size for 3 columns with taller height
        let totalWidth = UIScreen.main.bounds.width - 32 // 16pt padding on each side
        let itemSpacing: CGFloat = 8 * 2 // 2 spaces between 3 items
        let itemWidth = (totalWidth - itemSpacing) / 3
        let itemHeight = itemWidth * 1.5 // Make height 1.5x the width for portrait aspect ratio
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(AvatarImageCell.self, forCellWithReuseIdentifier: "AvatarImageCell")
        return collectionView
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No avatar images found"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadAvatarImages()
    }
    
    private func setupNavigationBar() {
        title = "Select Profile Picture"
        
        // Add Save button
        let saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveButtonTapped))
        saveButton.isEnabled = false // Disabled until image is selected
        navigationItem.rightBarButtonItem = saveButton
    }
    
    @objc private func saveButtonTapped() {
        guard let selectedIndex = selectedIndex else {
            ToastManager.showToast(message: "Please select an image first", type: .info)
            return
        }
        
        let selectedAvatar = avatarImages[selectedIndex]
        guard let selectedImage = selectedAvatar.image else {
            ToastManager.showToast(message: ToastMessages.avatarUpdateFailed, type: .error)
            return
        }
        
        saveProfileImage(collectionId: selectedAvatar.collectionId, image: selectedImage)
    }
    
    private func saveProfileImage(collectionId: String, image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid else {
            ToastManager.showToast(message: ToastMessages.avatarUpdateFailed, type: .error)
            return
        }
        
        print("💾 Saving profile image from collection: \(collectionId)")
        
        // For default avatar, we'll use "default" as the collectionId
        let finalCollectionId = collectionId == "default" ? "default" : collectionId
        
        // Update user document with selected profile image collection ID
        db.collection("users")
            .document(userId)
            .updateData([
                "profileImageCollectionId": finalCollectionId,
                "profileImageUpdatedAt": FieldValue.serverTimestamp()
            ]) { [weak self] error in
                if let error = error {
                    print("❌ Error saving profile image: \(error.localizedDescription)")
                    ToastManager.showToast(message: ToastMessages.avatarUpdateFailed, type: .error)
                } else {
                    print("✅ Successfully saved profile image selection")
                    ToastManager.showToast(message: ToastMessages.avatarUpdated, type: .success)
                    
                    // Pass the selected image back via callback
                    self?.onImageSelected?(image)
                    
                    // Pop back to settings
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(previewContainerView)
        previewContainerView.addSubview(previewImageView)
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateLabel)
        
        // Calculate heights: 55% for preview, 45% for grid
        let screenHeight = UIScreen.main.bounds.height
        let previewHeight = screenHeight * 0.55
        
        NSLayoutConstraint.activate([
            // Preview container at top (55% of screen)
            previewContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainerView.heightAnchor.constraint(equalToConstant: previewHeight),
            
            // Preview image centered in the visible area (below status bar)
            previewImageView.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor, constant: 60),
            
            // Collection view at bottom (45% of screen)
            collectionView.topAnchor.constraint(equalTo: previewContainerView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadAvatarImages() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            showEmptyState()
            return
        }
        
        loadingIndicator.startAnimating()
        collectionView.isHidden = true
        emptyStateLabel.isHidden = true
        
        print("🔍 Loading avatar images for user: \(userId)")
        
        // First, get all collections for this user to find their collection IDs
        db.collection("users")
            .document(userId)
            .collection("collections")
            .whereField("isOwner", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching collections: \(error.localizedDescription)")
                    self.loadingIndicator.stopAnimating()
                    self.showEmptyState()
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("⚠️ No collections found")
                    self.loadingIndicator.stopAnimating()
                    self.showEmptyState()
                    return
                }
                
                print("✅ Found \(documents.count) collections")
                
                // Extract collection IDs
                let collectionIds = documents.map { $0.documentID }
                self.loadImagesForCollections(userId: userId, collectionIds: collectionIds)
            }
    }
    
    private func loadImagesForCollections(userId: String, collectionIds: [String]) {
        let group = DispatchGroup()
        let container = ImageContainer()
        
        for collectionId in collectionIds {
            group.enter()
            
            self.loadSingleImage(userId: userId, collectionId: collectionId, container: container) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            var allImages = container.images
            
            // Add default avatar as first option
            if let defaultImage = self.defaultAvatarImage {
                allImages.insert(("default", defaultImage), at: 0)
                print("✅ Added default avatar as first option")
            }
            
            self.avatarImages = allImages
            self.loadingIndicator.stopAnimating()
            
            if self.avatarImages.isEmpty {
                self.showEmptyState()
            } else {
                print("✅ Loaded \(self.avatarImages.count) avatar images (including default)")
                self.collectionView.isHidden = false
                self.collectionView.reloadData()
                
                // Auto-select current profile image
                self.autoSelectCurrentProfileImage()
            }
        }
    }
    
    private func loadSingleImage(userId: String, collectionId: String, container: ImageContainer, completion: @escaping () -> Void) {
        // Load PNG avatar image
        let pngRef = storage.reference()
            .child("collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        print("🔍 Attempting to load: collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        pngRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
            if let error = error {
                print("❌ Error loading image for collection \(collectionId): \(error.localizedDescription)")
            } else if let data = data, let image = UIImage(data: data) {
                print("✅ Successfully loaded PNG image for collection: \(collectionId)")
                container.append((collectionId, image))
            } else {
                print("❌ Could not create image from data for collection \(collectionId)")
            }
            completion()
        }
    }
    
    private func showEmptyState() {
        collectionView.isHidden = true
        emptyStateLabel.isHidden = false
    }
    
    private func autoSelectCurrentProfileImage() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated for auto-selection")
            return
        }
        
        print("🔍 Auto-selecting current profile image...")
        
        // Get the saved profile image collection ID from Firestore
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user data for auto-selection: \(error.localizedDescription)")
                    // Default to selecting the first item (default avatar)
                    self.selectImageAtIndex(0)
                    return
                }
                
                let savedCollectionId: String
                if let data = snapshot?.data(),
                   let collectionId = data["profileImageCollectionId"] as? String {
                    savedCollectionId = collectionId
                    print("✅ Found saved profile image collection ID: \(collectionId)")
                } else {
                    savedCollectionId = "default"
                    print("⚠️ No profile image set, defaulting to default avatar")
                }
                
                // Find the index of the saved collection ID
                let index = self.avatarImages.firstIndex { $0.collectionId == savedCollectionId }
                
                if let index = index {
                    print("✅ Auto-selecting image at index: \(index)")
                    self.selectImageAtIndex(index)
                } else {
                    print("⚠️ Saved collection ID not found in available images, selecting default")
                    self.selectImageAtIndex(0) // Default to first item (default avatar)
                }
            }
    }
    
    private func selectImageAtIndex(_ index: Int) {
        guard index < avatarImages.count else {
            print("❌ Index out of bounds for auto-selection")
            return
        }
        
        let selectedAvatar = avatarImages[index]
        selectedIndex = index
        
        // Update preview image
        previewImageView.image = selectedAvatar.image
        
        // Enable Save button
        navigationItem.rightBarButtonItem?.isEnabled = true
        
        // Update collection view selection
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.reloadItems(at: [indexPath])
        
        print("✅ Auto-selected: \(selectedAvatar.collectionId)")
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension ProfileImageViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return avatarImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AvatarImageCell", for: indexPath) as! AvatarImageCell
        let avatarImage = avatarImages[indexPath.item].image
        let isSelected = selectedIndex == indexPath.item
        cell.configure(with: avatarImage, isSelected: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedImage = avatarImages[indexPath.item]
        print("📸 Selected avatar from collection: \(selectedImage.collectionId)")
        
        // Update selected index
        let previousIndex = selectedIndex
        selectedIndex = indexPath.item
        
        // Update preview image
        previewImageView.image = selectedImage.image
        
        // Enable Save button
        navigationItem.rightBarButtonItem?.isEnabled = true
        
        // Reload cells to update borders
        var indexPathsToReload: [IndexPath] = [indexPath]
        if let previousIndex = previousIndex {
            indexPathsToReload.append(IndexPath(item: previousIndex, section: 0))
        }
        collectionView.reloadItems(at: indexPathsToReload)
    }
}

// MARK: - AvatarImageCell
class AvatarImageCell: UICollectionViewCell {
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondColor
        imageView.layer.cornerRadius = 8
        return imageView
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
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
        contentView.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with image: UIImage?, isSelected: Bool = false) {
        if let image = image {
            imageView.image = image
            loadingIndicator.stopAnimating()
        } else {
            imageView.image = nil
            loadingIndicator.startAnimating()
        }
        
        // Update border based on selection state
        if isSelected {
            imageView.layer.borderColor = UIColor.thirdColor.cgColor
            imageView.layer.borderWidth = 2
        } else {
            imageView.layer.borderWidth = 0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.layer.borderWidth = 0
        loadingIndicator.stopAnimating()
    }
}

