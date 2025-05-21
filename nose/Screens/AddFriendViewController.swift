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
        searchBar.placeholder = "Search by User ID (e.g., USER123456)"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .allCharacters
        return searchBar
    }()
    
    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Search", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var userIdContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
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
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var resultContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
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
    
    private lazy var resultUserIdLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private lazy var addFriendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Add Friend", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(addFriendButtonTapped), for: .touchUpInside)
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
        view.backgroundColor = .systemBackground
        title = "Add Friend"
        
        // Add subviews
        view.addSubview(searchContainer)
        searchContainer.addSubview(searchBar)
        searchContainer.addSubview(searchButton)
        view.addSubview(userIdContainer)
        userIdContainer.addSubview(userIdLabel)
        userIdContainer.addSubview(userIdValueLabel)
        userIdContainer.addSubview(copyButton)
        view.addSubview(resultContainer)
        resultContainer.addSubview(resultNameLabel)
        resultContainer.addSubview(resultUserIdLabel)
        resultContainer.addSubview(addFriendButton)
        view.addSubview(activityIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),
            
            searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            
            searchButton.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchButton.leadingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: 8),
            searchButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -16),
            searchButton.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 80),
            
            userIdContainer.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            userIdContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            userIdContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            userIdContainer.heightAnchor.constraint(equalToConstant: 44),
            
            userIdLabel.leadingAnchor.constraint(equalTo: userIdContainer.leadingAnchor, constant: 12),
            userIdLabel.centerYAnchor.constraint(equalTo: userIdContainer.centerYAnchor),
            
            userIdValueLabel.leadingAnchor.constraint(equalTo: userIdLabel.trailingAnchor, constant: 8),
            userIdValueLabel.centerYAnchor.constraint(equalTo: userIdContainer.centerYAnchor),
            
            copyButton.leadingAnchor.constraint(equalTo: userIdValueLabel.trailingAnchor, constant: 8),
            copyButton.trailingAnchor.constraint(equalTo: userIdContainer.trailingAnchor, constant: -12),
            copyButton.centerYAnchor.constraint(equalTo: userIdContainer.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 44),
            copyButton.heightAnchor.constraint(equalToConstant: 44),
            
            resultContainer.topAnchor.constraint(equalTo: userIdContainer.bottomAnchor, constant: 32),
            resultContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            resultNameLabel.topAnchor.constraint(equalTo: resultContainer.topAnchor),
            resultNameLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            resultNameLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            
            resultUserIdLabel.topAnchor.constraint(equalTo: resultNameLabel.bottomAnchor, constant: 8),
            resultUserIdLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            resultUserIdLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            
            addFriendButton.topAnchor.constraint(equalTo: resultUserIdLabel.bottomAnchor, constant: 24),
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
        guard let userId = currentUser?.userId else { return }
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
    
    @objc private func searchButtonTapped() {
        print("DEBUG: Search button tapped")
        searchBar.resignFirstResponder()
        if let searchText = searchBar.text {
            print("DEBUG: Search text: \(searchText)")
            searchUsers(withUserId: searchText.uppercased())
        } else {
            print("DEBUG: Search text is nil")
        }
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
        
        // Only search if the input matches the expected format
        guard userId.hasPrefix("USER") else {
            print("DEBUG: Invalid userId format - must start with 'USER'")
            searchResults = []
            resultContainer.isHidden = true
            showAlert(title: "Invalid User ID", message: "User ID must start with 'USER' followed by numbers")
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
        db.collection("users").document(currentUserId)
            .collection("friends").document(userId).getDocument { [weak self] friendSnapshot, friendError in
                if friendSnapshot?.exists == true {
                    print("DEBUG: User is already a friend")
                    self?.isSearching = false
                    self?.activityIndicator.stopAnimating()
                    self?.showAlert(title: "Already Friends", message: "This user is already in your friends list")
                    return
                }
                
                // Then check if the user is blocked
                db.collection("users").document(currentUserId)
                    .collection("blocked").document(userId).getDocument { [weak self] blockedSnapshot, blockedError in
                        if blockedSnapshot?.exists == true {
                            print("DEBUG: User is blocked")
                            self?.isSearching = false
                            self?.activityIndicator.stopAnimating()
                            self?.showAlert(title: "User Blocked", message: "You have blocked this user. Unblock them first to add them as a friend.")
                            return
                        }
                        
                        // Finally search for the user
                        db.collection("users").whereField("userId", isEqualTo: userId).getDocuments { [weak self] snapshot, error in
                            guard let self = self else {
                                print("DEBUG: Self was deallocated")
                                return
                            }
                            
                            self.isSearching = false
                            self.activityIndicator.stopAnimating()
                            
                            if let error = error {
                                print("DEBUG: Firestore error: \(error.localizedDescription)")
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
                            
                            DispatchQueue.main.async {
                                if let user = self.searchResults.first {
                                    print("DEBUG: Showing result for user: \(user.name)")
                                    self.resultNameLabel.text = user.name
                                    self.resultUserIdLabel.text = user.userId
                                    self.resultContainer.isHidden = false
                                } else {
                                    print("DEBUG: No user found, hiding result container")
                                    self.resultContainer.isHidden = true
                                    self.showAlert(title: "User Not Found", message: "No user found with this User ID. Please check the ID and try again.")
                                }
                            }
                        }
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
        
        // Add friend relationship
        db.collection("users").document(currentUserId)
            .collection("friends").document(user.id).setData([
                "addedAt": FieldValue.serverTimestamp()
            ]) { [weak self] error in
                if let error = error {
                    print("DEBUG: Error adding friend: \(error.localizedDescription)")
                    return
                }
                
                print("DEBUG: Friend added successfully")
                DispatchQueue.main.async {
                    self?.showAlert(title: "Success", message: "Friend added successfully") { _ in
                        self?.navigationController?.popViewController(animated: true)
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
        // Don't search while typing, only when search button is pressed
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchButtonTapped()
    }
}

