import UIKit
import FirebaseAuth
import FirebaseFirestore

class AddFriendViewController: UIViewController {
    
    // MARK: - Properties
    private var searchResults: [User] = []
    private var isSearching = false
    private var currentUser: User?
    
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
        return label
    }()
    
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.tintColor = .secondaryLabel
        button.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var resultContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isHidden = true
        return view
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
        button.setTitle("Add Friend", for: .normal)
        button.addTarget(self, action: #selector(addFriendButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "add_friend_button"
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
        resultContainer.addSubview(resultNameLabel)
        resultContainer.addSubview(addFriendButton)
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
            
            resultNameLabel.topAnchor.constraint(equalTo: resultContainer.topAnchor),
            resultNameLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            resultNameLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            
            addFriendButton.topAnchor.constraint(equalTo: resultNameLabel.bottomAnchor, constant: 24),
            addFriendButton.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            addFriendButton.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            addFriendButton.heightAnchor.constraint(equalToConstant: 50),
            addFriendButton.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor),
            
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
        addFriend(user)
    }
    
    private func searchUsers(withUserId userId: String) {
        print("DEBUG: Starting search with userId: \(userId)")
        print("DEBUG: userId length: \(userId.count)")
        
        guard !userId.isEmpty else {
            print("DEBUG: UserId is empty")
            searchResults = []
            resultContainer.isHidden = true
            showAlert(title: "Invalid Input", message: "Please enter a User ID to search")
            return
        }
        
        // Validate user ID format (10 alphanumeric characters)
        let userIdRegex = "^[A-Z0-9]{10}$"
        guard userId.range(of: userIdRegex, options: .regularExpression) != nil else {
            print("DEBUG: Invalid userId format - must be 10 alphanumeric characters")
            searchResults = []
            resultContainer.isHidden = true
            showAlert(title: "Invalid User ID", message: "User ID must be exactly 10 characters (letters and numbers)")
            return
        }
        
        // Check if user is searching their own ID
        if userId == currentUser?.userId {
            print("DEBUG: User searched their own ID")
            searchResults = []
            resultContainer.isHidden = true
            showAlert(title: "Cannot Add Yourself", message: "You cannot add yourself as a friend")
            return
        }
        
        isSearching = true
        activityIndicator.startAnimating()
        resultContainer.isHidden = true
        
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
                                            self.showAlert(title: "Already Friends", message: "This user is already in your friends list")
                                            return
                                        }
                                        
                                        // If not blocked and not friends, show the result
                                        DispatchQueue.main.async {
                                            print("DEBUG: Showing result for user: \(foundUser.name)")
                                            self.resultNameLabel.text = foundUser.name
                                            self.resultContainer.isHidden = false
                                        }
                                    }
                            }
                    }
            } else {
                print("DEBUG: No user found, hiding result container")
                self.isSearching = false
                self.activityIndicator.stopAnimating()
                self.resultContainer.isHidden = true
                self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
            }
        }
    }
    
    private func addFriend(_ user: User) {
        print("DEBUG: Attempting to add friend: \(user.name) with userId: \(user.userId)")
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No current user found")
            return
        }
        
        let db = Firestore.firestore()
        print("DEBUG: Adding friend relationship to Firestore")
        
        // Create a batch write
        let batch = db.batch()
        
        // Add friend relationship for current user
        let currentUserFriendRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(user.id)
        
        // Add friend relationship for the other user
        let otherUserFriendRef = db.collection("users")
            .document(user.id)
            .collection("friends")
            .document(currentUserId)
        
        // Add data to both documents
        batch.setData([
            "addedAt": FieldValue.serverTimestamp()
        ], forDocument: currentUserFriendRef)
        
        batch.setData([
            "addedAt": FieldValue.serverTimestamp()
        ], forDocument: otherUserFriendRef)
        
        // Commit the batch
        batch.commit { [weak self] error in
            if let error = error {
                print("DEBUG: Error adding friend: \(error.localizedDescription)")
                return
            }
            
            print("DEBUG: Friend added successfully for both users")
            DispatchQueue.main.async {
                self?.showAlert(title: "Success", message: "Friend added successfully") { _ in
                    // Clear the search field and result container
                    self?.searchBar.text = ""
                    self?.resultContainer.isHidden = true
                    self?.searchResults = []
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: completion))
        present(alert, animated: true)
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
