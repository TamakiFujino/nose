import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class AddFriendViewController: UIViewController {
    
    // MARK: - Properties
    private var searchResults: [User] = []
    private var isSearching = false
    private var currentUser: User?
    private let storage = Storage.storage()
    
    // MARK: - UI Components
    private lazy var searchContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search by User ID"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .allCharacters
        searchBar.accessibilityIdentifier = "search_by_user_id"
        return searchBar
    }()
    
    private lazy var userIdContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 8
        return view
    }()
    
    private lazy var userIdLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Your User ID:"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var userIdValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.accessibilityIdentifier = "user_id_value"
        return label
    }()
    
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.tintColor = .secondaryLabel
        button.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "copy_button"
        button.accessibilityLabel = "copy"
        return button
    }()
    
    private lazy var resultContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    private lazy var resultProfileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondColor
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        return imageView
    }()
    
    private lazy var resultNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var addFriendButton: CustomButton = {
        let button = CustomButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Send Request", for: .normal)
        button.addTarget(self, action: #selector(addFriendButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "add_friend_button"
        button.isHidden = true // Initially hidden
        return button
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
        loadCurrentUser()
    }
    
    // MARK: - Public Methods
    func setSearchText(_ text: String) {
        searchBar.text = text.uppercased()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // set background color
        view.backgroundColor = .firstColor
        
        title = "Add Friend"
        
        // Configure navigation bar
        navigationController?.navigationBar.tintColor = .label
        navigationItem.largeTitleDisplayMode = .never
        
        // Add subviews
        view.addSubview(searchContainer)
        searchContainer.addSubview(searchBar)
        view.addSubview(userIdContainer)
        userIdContainer.addSubview(userIdLabel)
        userIdContainer.addSubview(userIdValueLabel)
        userIdContainer.addSubview(copyButton)
        view.addSubview(resultContainer)
        resultContainer.addSubview(resultProfileImageView)
        resultContainer.addSubview(resultNameLabel)
        view.addSubview(addFriendButton)
        view.addSubview(activityIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),
            
            searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            
            userIdContainer.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            userIdContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            userIdContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            userIdContainer.heightAnchor.constraint(equalToConstant: 44),
            
            userIdLabel.leadingAnchor.constraint(equalTo: userIdContainer.leadingAnchor),
            userIdLabel.centerYAnchor.constraint(equalTo: userIdContainer.centerYAnchor),
            
            userIdValueLabel.leadingAnchor.constraint(equalTo: userIdLabel.trailingAnchor, constant: 4),
            userIdValueLabel.centerYAnchor.constraint(equalTo: userIdContainer.centerYAnchor),
            
            copyButton.leadingAnchor.constraint(equalTo: userIdValueLabel.trailingAnchor, constant: 4),
            copyButton.centerYAnchor.constraint(equalTo: userIdContainer.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 24),
            copyButton.heightAnchor.constraint(equalToConstant: 24),
            
            resultContainer.topAnchor.constraint(equalTo: userIdContainer.bottomAnchor, constant: 32),
            resultContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            resultProfileImageView.topAnchor.constraint(equalTo: resultContainer.topAnchor),
            resultProfileImageView.centerXAnchor.constraint(equalTo: resultContainer.centerXAnchor),
            resultProfileImageView.widthAnchor.constraint(equalToConstant: 200), // Same as preview size
            resultProfileImageView.heightAnchor.constraint(equalToConstant: 300), // 1.5x width for portrait
            
            resultNameLabel.topAnchor.constraint(equalTo: resultProfileImageView.bottomAnchor, constant: 16),
            resultNameLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            resultNameLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            resultNameLabel.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor),
            
            addFriendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addFriendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addFriendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addFriendButton.heightAnchor.constraint(equalToConstant: 50),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadCurrentUser() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error loading current user: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("No document found for current user")
                return
            }
            
            if let user = User.fromFirestore(snapshot) {
                DispatchQueue.main.async {
                    self?.currentUser = user
                    self?.userIdValueLabel.text = user.userId
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func copyButtonTapped() {
        guard let userId = userIdValueLabel.text else { return }
        UIPasteboard.general.string = userId
        
        // Show feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // Show temporary checkmark
        copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        }
    }
    
    @objc private func addFriendButtonTapped() {
        guard let user = searchResults.first else { return }
        sendFriendRequest(user)
    }
    
    private func searchUsers(withUserId userId: String) {
        print("DEBUG: Starting search with userId: \(userId)")
        print("DEBUG: userId length: \(userId.count)")
        
        guard !userId.isEmpty else {
            print("DEBUG: UserId is empty")
            searchResults = []
            resultContainer.isHidden = true
            addFriendButton.isHidden = true
            showAlert(title: "Invalid Input", message: "Please enter a User ID to search")
            return
        }
        
        // Validate user ID format (10 alphanumeric characters)
        let userIdRegex = "^[A-Z0-9]{10}$"
        guard userId.range(of: userIdRegex, options: .regularExpression) != nil else {
            print("DEBUG: Invalid userId format - must be 10 alphanumeric characters")
            searchResults = []
            resultContainer.isHidden = true
            addFriendButton.isHidden = true
            showAlert(title: "Invalid User ID", message: "User ID must be exactly 10 characters (letters and numbers)")
            return
        }
        
        // Check if user is searching their own ID
        if userId == currentUser?.userId {
            print("DEBUG: User searched their own ID")
            searchResults = []
            resultContainer.isHidden = true
            addFriendButton.isHidden = true
            showAlert(title: "Cannot Add Yourself", message: "You cannot add yourself as a friend")
            return
        }
        
        isSearching = true
        activityIndicator.startAnimating()
        resultContainer.isHidden = true
        addFriendButton.isHidden = true
        
        print("DEBUG: Querying Firestore for user with userId: \(userId)")
        let db = Firestore.firestore()
        
        // First check if the user is already a friend
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // First search for the user
        db.collection("users").whereField("userId", isEqualTo: userId).getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                print("DEBUG: Self was deallocated")
                return
            }
            
            if let error = error {
                print("DEBUG: Firestore error: \(error.localizedDescription)")
                self.isSearching = false
                self.activityIndicator.stopAnimating()
                self.showAlert(title: "Error", message: "An error occurred while searching. Please try again.")
                return
            }
            
            print("DEBUG: Firestore query completed")
            print("DEBUG: Number of documents found: \(snapshot?.documents.count ?? 0)")
            
            self.searchResults = snapshot?.documents.compactMap { document in
                if let user = User.fromFirestore(document) {
                    print("DEBUG: Successfully parsed user: \(user.name) with userId: \(user.userId)")
                    return user
                } else {
                    print("DEBUG: Failed to parse user from document")
                    return nil
                }
            } ?? []
            
            if let foundUser = self.searchResults.first {
                // Check if the user is deleted
                if foundUser.isDeleted {
                    print("DEBUG: Found user is deleted")
                    self.searchResults = []
                    self.resultContainer.isHidden = true
                    self.addFriendButton.isHidden = true
                    self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
                    return
                }
                
                // Check if the current user has blocked the found user
                db.collection("users").document(currentUserId)
                    .collection("blocked").document(foundUser.id).getDocument { [weak self] blockedSnapshot, blockedError in
                        guard let self = self else { return }
                        
                        self.isSearching = false
                        self.activityIndicator.stopAnimating()
                        
                        if blockedSnapshot?.exists == true {
                            print("DEBUG: Current user has blocked the found user")
                            self.searchResults = []
                            self.resultContainer.isHidden = true
                            self.addFriendButton.isHidden = true
                            self.showAlert(title: "Cannot Add Friend", message: "You have blocked this user. Please unblock them first to add them as a friend.")
                            return
                        }
                        
                        // Check if the found user has blocked the current user
                        db.collection("users").document(foundUser.id)
                            .collection("blocked").document(currentUserId).getDocument { [weak self] blockedSnapshot, blockedError in
                                guard let self = self else { return }
                                
                                if blockedSnapshot?.exists == true {
                                    print("DEBUG: Current user is blocked by the found user")
                                    self.searchResults = []
                                    self.resultContainer.isHidden = true
                                    self.addFriendButton.isHidden = true
                                    self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
                                    return
                                }
                                
                                // Check if already friends
                                db.collection("users").document(currentUserId)
                                    .collection("friends").document(foundUser.id).getDocument { [weak self] friendSnapshot, friendError in
                                        guard let self = self else { return }
                                        
                                        if friendSnapshot?.exists == true {
                                            print("DEBUG: User is already a friend")
                                            self.searchResults = []
                                            self.resultContainer.isHidden = true
                                            self.addFriendButton.isHidden = true
                                            self.showAlert(title: "Already Friends", message: "This user is already in your friends list")
                                            return
                                        }
                                        
                                        // Check for existing pending request (received from this user)
                                        db.collection("users").document(currentUserId)
                                            .collection("friendRequests").document(foundUser.id).getDocument { [weak self] receivedSnapshot, _ in
                                                guard let self = self else { return }
                                                if receivedSnapshot?.exists == true {
                                                    self.isSearching = false
                                                    self.activityIndicator.stopAnimating()
                                                    self.searchResults = []
                                                    self.resultContainer.isHidden = true
                                                    self.addFriendButton.isHidden = true
                                                    self.showAlert(title: "Request Pending", message: "This user has already sent you a friend request. Check the Pending tab to approve or reject.")
                                                    return
                                                }
                                                // Check for existing sent request to this user
                                                db.collection("users").document(currentUserId)
                                                    .collection("sentFriendRequests").document(foundUser.id).getDocument { [weak self] sentSnapshot, _ in
                                                        guard let self = self else { return }
                                                        if sentSnapshot?.exists == true {
                                                            self.isSearching = false
                                                            self.activityIndicator.stopAnimating()
                                                            self.searchResults = []
                                                            self.resultContainer.isHidden = true
                                                            self.addFriendButton.isHidden = true
                                                            self.showAlert(title: "Request Already Sent", message: "You have already sent a friend request to this user. Check the Pending tab.")
                                                            return
                                                        }
                                                        // If not blocked, not friends, and no pending request, show the result
                                                        DispatchQueue.main.async {
                                                            print("DEBUG: Showing result for user: \(foundUser.name)")
                                                            self.resultNameLabel.text = foundUser.name
                                                            self.loadProfileImage(for: foundUser)
                                                            self.resultContainer.isHidden = false
                                                            self.addFriendButton.isHidden = false
                                                        }
                                                    }
                                            }
                                    }
                            }
                    }
            } else {
                print("DEBUG: No user found, hiding result container")
                self.isSearching = false
                self.activityIndicator.stopAnimating()
                self.resultContainer.isHidden = true
                self.addFriendButton.isHidden = true
                self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
            }
        }
    }
    
    private func sendFriendRequest(_ user: User) {
        print("DEBUG: Sending friend request to: \(user.name) with userId: \(user.userId)")
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No current user found")
            return
        }
        
        UserManager.shared.sendFriendRequest(requesterId: currentUserId, receiverId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("DEBUG: Friend request sent successfully")
                    self?.showAlert(title: "Success", message: "Friend request sent.") { _ in
                        self?.searchBar.text = ""
                        self?.resultContainer.isHidden = true
                        self?.addFriendButton.isHidden = true
                        self?.searchResults = []
                    }
                case .failure(let error):
                    print("DEBUG: Error sending friend request: \(error.localizedDescription)")
                    self?.showAlert(title: "Error", message: "Failed to send friend request. Please try again.")
                }
            }
        }
    }
    
    private func loadProfileImage(for user: User) {
        print("🔍 Loading profile image for user: \(user.name)")
        
        // First, get the saved profile image collection ID from the user's document
        let db = Firestore.firestore()
        db.collection("users")
            .document(user.id)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user data for profile image: \(error.localizedDescription)")
                    self.showDefaultProfileImage()
                    return
                }
                
                guard let data = snapshot?.data(),
                      let collectionId = data["profileImageCollectionId"] as? String else {
                    print("⚠️ No profile image set for user, showing default")
                    self.showDefaultProfileImage()
                    return
                }
                
                print("✅ Found profile image collection ID: \(collectionId)")
                
                if collectionId == "default" {
                    self.showDefaultProfileImage()
                } else {
                    self.loadImageFromStorage(userId: user.id, collectionId: collectionId)
                }
            }
    }
    
    private func showDefaultProfileImage() {
        if let defaultImage = UIImage(named: "avatar") {
            DispatchQueue.main.async {
                self.resultProfileImageView.image = defaultImage
            }
            print("✅ Showing default profile image")
        } else {
            print("❌ Could not load default avatar image")
        }
    }
    
    private func loadImageFromStorage(userId: String, collectionId: String) {
        let imageRef = storage.reference()
            .child("collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        print("🔍 Loading image from: collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        imageRef.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("❌ Error loading profile image: \(error.localizedDescription)")
                self?.showDefaultProfileImage()
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("✅ Successfully loaded profile image")
                DispatchQueue.main.async {
                    self?.resultProfileImageView.image = image
                }
            } else {
                print("❌ Could not create image from data")
                self?.showDefaultProfileImage()
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let messageModal = MessageModalViewController(title: title, message: message)
        if let completion = completion {
            messageModal.onDismiss = {
                completion(UIAlertAction())
            }
        }
        present(messageModal, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension AddFriendViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Don't search while typing
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let searchText = searchBar.text {
            searchUsers(withUserId: searchText.uppercased())
        }
    }
}
