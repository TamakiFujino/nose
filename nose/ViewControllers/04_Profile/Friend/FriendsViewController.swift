import UIKit
import FirebaseAuth
import FirebaseFirestore

class FriendsViewController: UIViewController {
    
    // MARK: - Properties
    private var friends: [User] = []
    private var blockedUsers: [User] = []
    private var currentSegment: Int = 0
    
    // MARK: - UI Components
    private lazy var segmentedControl: UISegmentedControl = {
        let items = ["Friends", "Blocked"]
        let control = UISegmentedControl(items: items)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        return tableView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFriends()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // set background color
        view.backgroundColor = .firstColor
        
        title = "Friends"
        
        // Configure navigation bar
        navigationController?.navigationBar.tintColor = .sixthColor
        navigationItem.largeTitleDisplayMode = .never
        
        // Add subviews
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.lg),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: DesignTokens.Spacing.lg),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            Logger.log("No current user found", level: .debug, category: "Friends")
            return
        }
        let db = Firestore.firestore()
        
        Logger.log("Loading friends for user: \(currentUserId)", level: .info, category: "Friends")
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // Friends
                let friendsSnap = try await getDocumentsAsync(db.collection("users").document(currentUserId).collection("friends"))
                var loadedFriends: [User] = []
                for doc in friendsSnap.documents {
                    let friendId = doc.documentID
                    let userSnap = try await getDocumentAsync(db.collection("users").document(friendId))
                    if let user = User.fromFirestore(userSnap) { loadedFriends.append(user) }
                }
                Logger.log("All friends loaded, total: \(loadedFriends.count)", level: .info, category: "Friends")
                self.friends = loadedFriends
                if self.currentSegment == 0 { self.tableView.reloadData() }
            } catch {
                Logger.log("Error loading friends: \(error.localizedDescription)", level: .error, category: "Friends")
            }
            do {
                // Blocked
                let blockedSnap = try await getDocumentsAsync(db.collection("users").document(currentUserId).collection("blocked"))
                var loadedBlocked: [User] = []
                for doc in blockedSnap.documents {
                    let blockedId = doc.documentID
                    let userSnap = try await getDocumentAsync(db.collection("users").document(blockedId))
                    if let user = User.fromFirestore(userSnap) { loadedBlocked.append(user) }
                }
                Logger.log("All blocked users loaded, total: \(loadedBlocked.count)", level: .info, category: "Friends")
                self.blockedUsers = loadedBlocked
                if self.currentSegment == 1 { self.tableView.reloadData() }
            } catch {
                Logger.log("Error loading blocked users: \(error.localizedDescription)", level: .error, category: "Friends")
            }
        }
    }

    // MARK: - Async Firestore helpers
    private func getDocumentsAsync(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No snapshot"]))
                }
            }
        }
    }

    private func getDocumentAsync(_ ref: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            ref.getDocument { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No snapshot"]))
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        currentSegment = sender.selectedSegmentIndex
        tableView.reloadData()
    }
    
    private func addFriend(withEmail email: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // First check if the user is in blocked list
        db.collection("users").document(currentUserId)
            .collection("blocked").getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error checking blocked users: \(error.localizedDescription)")
                    return
                }
                
                // Find user by email
                db.collection("users").whereField("email", isEqualTo: email).getDocuments { [weak self] snapshot, error in
                    if let error = error {
                        print("Error finding user: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let userDoc = snapshot?.documents.first else {
                        DispatchQueue.main.async {
                            self?.showAlert(title: "Error", message: "User not found")
                        }
                        return
                    }
                    
                    let friendId = userDoc.documentID
                    
                    // Check if the user is blocked
                    if (snapshot?.documents.first(where: { $0.documentID == friendId })) != nil {
                        DispatchQueue.main.async {
                            self?.showAlert(
                                title: "Cannot Add Friend",
                                message: "You have blocked this user. Please unblock them first to add them as a friend."
                            )
                        }
                        return
                    }
                    
                    // Check if the other user has blocked the current user
                    db.collection("users").document(friendId)
                        .collection("blocked").document(currentUserId).getDocument { [weak self] snapshot, error in
                            if let error = error {
                                print("Error checking if blocked: \(error.localizedDescription)")
                                return
                            }
                            
                            if snapshot?.exists == true {
                                DispatchQueue.main.async {
                                    self?.showAlert(title: "Error", message: "User not found")
                                }
                                return
                            }
                            
                            // Add friend relationship
                            db.collection("users").document(currentUserId)
                                .collection("friends").document(friendId).setData([
                                    "addedAt": FieldValue.serverTimestamp()
                                ]) { error in
                                    if let error = error {
                                        print("Error adding friend: \(error.localizedDescription)")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        self?.loadFriends()
                                        self?.showAlert(title: "Success", message: "Friend added successfully")
                                    }
                                }
                        }
                }
            }
    }
    
    private func showAlert(title: String, message: String) {
        AlertManager.present(on: self, title: title, message: message, style: .info)
    }
    
    private func blockUser(_ user: User) {
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        let confirm = UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            print("🔒 FriendsViewController: Starting block operation for user: \(user.name)")
            
            // Use UserManager to handle the blocking operation
            UserManager.shared.blockUser(currentUserId: currentUserId, blockedUserId: user.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("🔒 FriendsViewController: Successfully blocked user")
                        self?.loadFriends()
                        self?.showAlert(title: "Success", message: "User blocked successfully")
                    case .failure(let error):
                        print("❌ FriendsViewController: Error blocking user: \(error.localizedDescription)")
                        self?.showAlert(title: "Error", message: "Failed to block user: \(error.localizedDescription)")
                    }
                }
            }
        }
        AlertManager.present(on: self, title: "Are you sure you block user \"\(user.name)\"?", message: "You will not be able to share a collection or add as a friend", style: .error, preferredStyle: .alert, actions: [cancel, confirm])
    }
    
    private func unblockUser(_ user: User) {
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        let confirm = UIAlertAction(title: "Unblock", style: .default) { [weak self] _ in
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            print("🔓 FriendsViewController: Starting unblock operation for user: \(user.name)")
            
            // Use UserManager to handle the unblocking operation
            UserManager.shared.unblockUser(currentUserId: currentUserId, blockedUserId: user.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("🔓 FriendsViewController: Successfully unblocked user")
                        self?.loadFriends()
                        self?.showAlert(title: "Success", message: "User unblocked successfully")
                    case .failure(let error):
                        print("❌ FriendsViewController: Error unblocking user: \(error.localizedDescription)")
                        self?.showAlert(title: "Error", message: "Failed to unblock user: \(error.localizedDescription)")
                    }
                }
            }
        }
        AlertManager.present(on: self, title: "Are you sure you unblock user \"\(user.name)\"?", message: "\(user.name) will be able to add you as a friend with your User ID", style: .info, preferredStyle: .alert, actions: [cancel, confirm])
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension FriendsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = currentSegment == 0 ? friends.count : blockedUsers.count
        Logger.log("numberOfRowsInSection segment: \(currentSegment), count: \(count)", level: .debug, category: "Friends")
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        Logger.log("cellForRowAt index: \(indexPath.row)", level: .debug, category: "Friends")
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = currentSegment == 0 ? friends[indexPath.row] : blockedUsers[indexPath.row]
        
        Logger.log("User data - name: \(user.name), id: \(user.id)", level: .debug, category: "Friends")
        
        var content = cell.defaultContentConfiguration()
        content.text = user.name
        content.textProperties.color = .sixthColor
        content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
        
        // Configure cell background
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        // Add a custom background view for the cell
        let backgroundView = UIView()
        cell.backgroundView = backgroundView
        
        // Add a custom selected background view
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.firstColor.withAlphaComponent(0.2)
        cell.selectedBackgroundView = selectedBackgroundView
        
        cell.contentConfiguration = content
        
        // Debug the cell's content after configuration
        if let configuredContent = cell.contentConfiguration as? UIListContentConfiguration {
            Logger.log("Cell configured with text: \(configuredContent.text ?? "nil")", level: .debug, category: "Friends")
            Logger.log("Cell text color: \(configuredContent.textProperties.color)", level: .debug, category: "Friends")
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = currentSegment == 0 ? friends[indexPath.row] : blockedUsers[indexPath.row]
        
        let alert = UIAlertController(title: user.name, message: nil, preferredStyle: .actionSheet)
        
        if currentSegment == 0 {
            alert.addAction(UIAlertAction(title: "Block User", style: .destructive) { [weak self] _ in
                self?.blockUser(user)
            })
        } else {
            alert.addAction(UIAlertAction(title: "Unblock User", style: .default) { [weak self] _ in
                self?.unblockUser(user)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func unfriendUser(_ user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        Logger.log("Unfriending user: \(user.name) with ID: \(user.id)", level: .debug, category: "Friends")
        
        // Remove from friends
        db.collection("users").document(currentUserId)
            .collection("friends").document(user.id).delete { [weak self] error in
                if let error = error {
                    Logger.log("Error unfriending user: \(error.localizedDescription)", level: .error, category: "Friends")
                    return
                }
                
                Logger.log("Successfully unfriended user", level: .info, category: "Friends")
                DispatchQueue.main.async {
                    self?.loadFriends()
                }
            }
    }
}
