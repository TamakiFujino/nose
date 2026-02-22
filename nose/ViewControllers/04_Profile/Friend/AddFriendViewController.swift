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

        FirestorePaths.userDoc(currentUserId).getDocument { [weak self] snapshot, error in
            if let error = error {
                Logger.log("Error loading current user: \(error.localizedDescription)", level: .error, category: "AddFriend")
                return
            }
            
            guard let snapshot = snapshot else {
                Logger.log("No document found for current user", level: .debug, category: "AddFriend")
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
        
        guard !userId.isEmpty else {
            searchResults = []
            resultContainer.isHidden = true
            addFriendButton.isHidden = true
            showAlert(title: "Invalid Input", message: "Please enter a User ID to search")
            return
        }
        
        // Validate user ID format (10 alphanumeric characters)
        let userIdRegex = "^[A-Z0-9]{10}$"
        guard userId.range(of: userIdRegex, options: .regularExpression) != nil else {
            searchResults = []
            resultContainer.isHidden = true
            addFriendButton.isHidden = true
            showAlert(title: "Invalid User ID", message: "User ID must be exactly 10 characters (letters and numbers)")
            return
        }
        
        // Check if user is searching their own ID
        if userId == currentUser?.userId {
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
        
        // First check if the user is already a friend
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        // First search for the user
        FirestorePaths.users().whereField("userId", isEqualTo: userId).getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                return
            }
            
            if let error = error {
                self.isSearching = false
                self.activityIndicator.stopAnimating()
                self.showAlert(title: "Error", message: "An error occurred while searching. Please try again.")
                return
            }
            
            
            self.searchResults = snapshot?.documents.compactMap { document in
                if let user = User.fromFirestore(document) {
                    return user
                } else {
                    return nil
                }
            } ?? []
            
            if let foundUser = self.searchResults.first {
                // Check if the user is deleted
                if foundUser.isDeleted {
                    self.searchResults = []
                    self.resultContainer.isHidden = true
                    self.addFriendButton.isHidden = true
                    self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
                    return
                }
                
                // Check if the current user has blocked the found user
                FirestorePaths.blocked(userId: currentUserId).document(foundUser.id).getDocument { [weak self] blockedSnapshot, blockedError in
                        guard let self = self else { return }
                        
                        self.isSearching = false
                        self.activityIndicator.stopAnimating()
                        
                        if blockedSnapshot?.exists == true {
                            self.searchResults = []
                            self.resultContainer.isHidden = true
                            self.addFriendButton.isHidden = true
                            self.showAlert(title: "Cannot Add Friend", message: "You have blocked this user. Please unblock them first to add them as a friend.")
                            return
                        }
                        
                        // Check if the found user has blocked the current user
                        FirestorePaths.blocked(userId: foundUser.id).document(currentUserId).getDocument { [weak self] blockedSnapshot, blockedError in
                                guard let self = self else { return }
                                
                                if blockedSnapshot?.exists == true {
                                    self.searchResults = []
                                    self.resultContainer.isHidden = true
                                    self.addFriendButton.isHidden = true
                                    self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
                                    return
                                }
                                
                                // Check if already friends
                                FirestorePaths.friends(userId: currentUserId).document(foundUser.id).getDocument { [weak self] friendSnapshot, friendError in
                                        guard let self = self else { return }
                                        
                                        if friendSnapshot?.exists == true {
                                            self.searchResults = []
                                            self.resultContainer.isHidden = true
                                            self.addFriendButton.isHidden = true
                                            self.showAlert(title: "Already Friends", message: "This user is already in your friends list")
                                            return
                                        }
                                        
                                        // Check for existing pending request (received from this user)
                                        FirestorePaths.friendRequests(userId: currentUserId).document(foundUser.id).getDocument { [weak self] receivedSnapshot, _ in
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
                                                FirestorePaths.sentFriendRequests(userId: currentUserId).document(foundUser.id).getDocument { [weak self] sentSnapshot, _ in
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
                self.isSearching = false
                self.activityIndicator.stopAnimating()
                self.resultContainer.isHidden = true
                self.addFriendButton.isHidden = true
                self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
            }
        }
    }
    
    private func sendFriendRequest(_ user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        UserManager.shared.sendFriendRequest(requesterId: currentUserId, receiverId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showAlert(title: "Request Sent!", message: "Wait for the friend to approve the request.") { _ in
                        self?.searchBar.text = ""
                        self?.resultContainer.isHidden = true
                        self?.addFriendButton.isHidden = true
                        self?.searchResults = []
                    }
                case .failure(let error):
                    self?.showAlert(title: "Error", message: "Failed to send friend request. Please try again.")
                }
            }
        }
    }
    
    private func loadProfileImage(for user: User) {
        Logger.log("Loading profile image for user: \(user.name)", level: .debug, category: "AddFriend")
        
        // First, get the saved profile image collection ID from the user's document
        FirestorePaths.userDoc(user.id).getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Error fetching user data for profile image: \(error.localizedDescription)", level: .error, category: "AddFriend")
                    self.showDefaultProfileImage()
                    return
                }
                
                guard let data = snapshot?.data(),
                      let collectionId = data["profileImageCollectionId"] as? String else {
                    Logger.log("No profile image set for user, showing default", level: .warn, category: "AddFriend")
                    self.showDefaultProfileImage()
                    return
                }
                
                Logger.log("Found profile image collection ID: \(collectionId)", level: .info, category: "AddFriend")
                
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
            Logger.log("Showing default profile image", level: .info, category: "AddFriend")
        } else {
            Logger.log("Could not load default avatar image", level: .error, category: "AddFriend")
        }
    }
    
    private func loadImageFromStorage(userId: String, collectionId: String) {
        let imageRef = storage.reference()
            .child("collection_avatars/\(userId)/\(collectionId)/avatar.png")
        
        Logger.log("Loading image from: collection_avatars/\(userId)/\(collectionId)/avatar.png", level: .debug, category: "AddFriend")
        
        imageRef.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                Logger.log("Error loading profile image: \(error.localizedDescription)", level: .error, category: "AddFriend")
                self?.showDefaultProfileImage()
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                Logger.log("Successfully loaded profile image", level: .info, category: "AddFriend")
                DispatchQueue.main.async {
                    self?.resultProfileImageView.image = image
                }
            } else {
                Logger.log("Could not create image from data", level: .error, category: "AddFriend")
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
