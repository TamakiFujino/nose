import UIKit
import FirebaseAuth
import FirebaseFirestore

class FriendsViewController: UIViewController {
    
    // MARK: - Properties
    private var friends: [User] = []
    private var blockedUsers: [User] = []
    /// Received requests (others requested me); show with Approve/Reject
    private var pendingReceived: [User] = []
    /// Sent requests (I requested others); show as "Name requested"
    private var pendingSent: [User] = []
    private var currentSegment: Int = 0
    
    private enum Tab: Int {
        case friends = 0
        case pending = 1
        case blocked = 2
    }
    
    private enum PendingSection: Int {
        case received = 0
        case sent = 1
    }
    
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
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PendingReceivedCell")
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
        navigationController?.navigationBar.tintColor = .label
        navigationItem.largeTitleDisplayMode = .never
        
        // Add subviews
        view.addSubview(categoryTabScrollView)
        categoryTabScrollView.addSubview(categoryTabStackView)
        view.addSubview(tableView)
        
        // Setup category tabs
        setupCategoryTabs()
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Category tabs scroll view
            categoryTabScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            categoryTabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryTabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryTabScrollView.heightAnchor.constraint(equalToConstant: 30),
            
            // Category tabs stack view inside scroll view
            categoryTabStackView.leadingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            categoryTabStackView.trailingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            categoryTabStackView.topAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.topAnchor),
            categoryTabStackView.bottomAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.bottomAnchor),
            categoryTabStackView.heightAnchor.constraint(equalTo: categoryTabScrollView.frameLayoutGuide.heightAnchor),
            
            tableView.topAnchor.constraint(equalTo: categoryTabScrollView.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No current user found")
            return
        }
        let db = Firestore.firestore()
        
        print("DEBUG: Loading friends for user: \(currentUserId)")
        
        // Load friends
        db.collection("users").document(currentUserId)
            .collection("friends").getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("DEBUG: Error loading friends: \(error.localizedDescription)")
                    return
                }
                
                print("DEBUG: Found \(snapshot?.documents.count ?? 0) friend documents")
                
                // Create a dispatch group to handle multiple async operations
                let group = DispatchGroup()
                var loadedFriends: [User] = []
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    let friendId = document.documentID
                    print("DEBUG: Fetching full user data for friend ID: \(friendId)")
                    
                    // Fetch the complete user data from the users collection
                    db.collection("users").document(friendId).getDocument { userSnapshot, userError in
                        defer { group.leave() }
                        
                        if let userError = userError {
                            print("DEBUG: Error fetching user data: \(userError.localizedDescription)")
                            return
                        }
                        
                        if let userSnapshot = userSnapshot, let user = User.fromFirestore(userSnapshot) {
                            print("DEBUG: Successfully loaded friend: \(user.name) with ID: \(user.id)")
                            loadedFriends.append(user)
                        } else {
                            print("DEBUG: Failed to parse user document for ID: \(friendId)")
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("DEBUG: All friends loaded, total: \(loadedFriends.count)")
                    self?.friends = loadedFriends
                    if self?.currentSegment == Tab.friends.rawValue {
                        self?.tableView.reloadData()
                    }
                }
            }
        
        // Load blocked users
        db.collection("users").document(currentUserId)
            .collection("blocked").getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("DEBUG: Error loading blocked users: \(error.localizedDescription)")
                    return
                }
                
                print("DEBUG: Found \(snapshot?.documents.count ?? 0) blocked user documents")
                
                // Create a dispatch group to handle multiple async operations
                let group = DispatchGroup()
                var loadedBlockedUsers: [User] = []
                
                snapshot?.documents.forEach { document in
                    group.enter()
                    let blockedUserId = document.documentID
                    print("DEBUG: Fetching full user data for blocked user ID: \(blockedUserId)")
                    
                    // Fetch the complete user data from the users collection
                    db.collection("users").document(blockedUserId).getDocument { userSnapshot, userError in
                        defer { group.leave() }
                        
                        if let userError = userError {
                            print("DEBUG: Error fetching user data: \(userError.localizedDescription)")
                            return
                        }
                        
                        if let userSnapshot = userSnapshot, let user = User.fromFirestore(userSnapshot) {
                            print("DEBUG: Successfully loaded blocked user: \(user.name) with ID: \(user.id)")
                            loadedBlockedUsers.append(user)
                        } else {
                            print("DEBUG: Failed to parse user document for ID: \(blockedUserId)")
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("DEBUG: All blocked users loaded, total: \(loadedBlockedUsers.count)")
                    self?.blockedUsers = loadedBlockedUsers
                    if self?.currentSegment == Tab.blocked.rawValue {
                        self?.tableView.reloadData()
                    }
                }
            }
        
        loadPending()
    }
    
    private func loadPending() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Load received requests: users/currentUser/friendRequests (doc IDs = requester IDs)
        FirestorePaths.friendRequests(userId: currentUserId, db: db).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("DEBUG: Error loading received friend requests: \(error.localizedDescription)")
                return
            }
            let group = DispatchGroup()
            var received: [User] = []
            snapshot?.documents.forEach { doc in
                let requesterId = doc.documentID
                group.enter()
                db.collection("users").document(requesterId).getDocument { userSnapshot, userError in
                    defer { group.leave() }
                    guard let userSnapshot = userSnapshot, let user = User.fromFirestore(userSnapshot) else { return }
                    received.append(user)
                }
            }
            group.notify(queue: .main) {
                self?.pendingReceived = received
                if self?.currentSegment == Tab.pending.rawValue {
                    self?.tableView.reloadData()
                }
            }
        }
        
        // Load sent requests: users/currentUser/sentFriendRequests (doc IDs = receiver IDs)
        FirestorePaths.sentFriendRequests(userId: currentUserId, db: db).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("DEBUG: Error loading sent friend requests: \(error.localizedDescription)")
                return
            }
            let group = DispatchGroup()
            var sent: [User] = []
            snapshot?.documents.forEach { doc in
                let receiverId = doc.documentID
                group.enter()
                db.collection("users").document(receiverId).getDocument { userSnapshot, userError in
                    defer { group.leave() }
                    guard let userSnapshot = userSnapshot, let user = User.fromFirestore(userSnapshot) else { return }
                    sent.append(user)
                }
            }
            group.notify(queue: .main) {
                self?.pendingSent = sent
                if self?.currentSegment == Tab.pending.rawValue {
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Actions
    // MARK: - Tab Management
    private func setupCategoryTabs() {
        let tabs: [(Tab, String)] = [(.friends, "Friends"), (.pending, "Pending"), (.blocked, "Blocked")]
        for (index, (tab, title)) in tabs.enumerated() {
            let button = createTabButton(title: title, tag: index, tab: tab)
            if tab == .pending {
                button.accessibilityIdentifier = "Pending"
            }
            categoryTabStackView.addArrangedSubview(button)
        }
        updateTabButtonStates()
    }
    
    private func createTabButton(title: String, tag: Int, tab: Tab) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .secondColor
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        button.layer.masksToBounds = true
        button.tag = tag
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
        let tabs: [Tab] = [.friends, .pending, .blocked]
        for (index, tab) in tabs.enumerated() {
            guard index < categoryTabStackView.arrangedSubviews.count,
                  let button = categoryTabStackView.arrangedSubviews[index] as? UIButton else { continue }
            
            let isSelected = (tab.rawValue == currentSegment)
            button.backgroundColor = isSelected ? .themeBlue : .secondColor
            button.setTitleColor(isSelected ? .white : .black, for: .normal)
            button.layer.cornerRadius = 16
        }
    }
    
    // MARK: - Actions
    @objc private func categoryTabTapped(_ sender: UIButton) {
        guard sender.tag < 3 else { return }
        let tabs: [Tab] = [.friends, .pending, .blocked]
        let tab = tabs[sender.tag]
        currentSegment = tab.rawValue
        updateTabButtonStates()
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
        let messageModal = MessageModalViewController(title: title, message: message)
        present(messageModal, animated: true)
    }
    
    private func blockUser(_ user: User) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Are you sure you block user \"\(user.name)\"?",
            message: "You will not be able to share a collection or add as a friend",
            preferredStyle: .alert
        )
        
        // Add cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Add block action
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in
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
        })
        
        present(alert, animated: true)
    }
    
    private func unblockUser(_ user: User) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Are you sure you unblock user \"\(user.name)\"?",
            message: "\(user.name) will be able to add you as a friend with your User ID",
            preferredStyle: .alert
        )
        
        // Add cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Add unblock action
        alert.addAction(UIAlertAction(title: "Unblock", style: .default) { [weak self] _ in
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
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension FriendsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if currentSegment == Tab.pending.rawValue {
            return 2 // Received, Sent
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if currentSegment == Tab.pending.rawValue {
            return section == PendingSection.received.rawValue ? pendingReceived.count : pendingSent.count
        }
        if currentSegment == Tab.friends.rawValue { return friends.count }
        return blockedUsers.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if currentSegment == Tab.pending.rawValue {
            return section == PendingSection.received.rawValue ? "Received" : "Sent"
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if currentSegment == Tab.pending.rawValue {
            if indexPath.section == PendingSection.received.rawValue {
                let cell = tableView.dequeueReusableCell(withIdentifier: "PendingReceivedCell", for: indexPath)
                let user = pendingReceived[indexPath.row]
                var content = cell.defaultContentConfiguration()
                content.text = user.name
                content.textProperties.color = .label
                content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
                cell.contentConfiguration = content
                cell.backgroundColor = .clear
                cell.selectionStyle = .default
                cell.backgroundView = UIView()
                let selectedBg = UIView()
                selectedBg.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                cell.selectedBackgroundView = selectedBg
                // Approve / Reject buttons as accessory
                let approve = UIButton(type: .system)
                approve.setTitle("Approve", for: .normal)
                approve.tag = indexPath.row
                approve.accessibilityIdentifier = "Approve"
                approve.addTarget(self, action: #selector(pendingApproveTapped(_:)), for: .touchUpInside)
                let reject = UIButton(type: .system)
                reject.setTitle("Reject", for: .normal)
                reject.tag = indexPath.row
                reject.accessibilityIdentifier = "Reject"
                reject.addTarget(self, action: #selector(pendingRejectTapped(_:)), for: .touchUpInside)
                let stack = UIStackView(arrangedSubviews: [approve, reject])
                stack.axis = .horizontal
                stack.spacing = 8
                cell.accessoryView = stack
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
                let user = pendingSent[indexPath.row]
                var content = cell.defaultContentConfiguration()
                content.text = "\(user.name) requested"
                content.textProperties.color = .label
                content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
                cell.contentConfiguration = content
                cell.accessoryView = nil
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
                cell.backgroundView = UIView()
                let selectedBg = UIView()
                selectedBg.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                cell.selectedBackgroundView = selectedBg
                return cell
            }
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = currentSegment == Tab.friends.rawValue ? friends[indexPath.row] : blockedUsers[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = user.name
        content.textProperties.color = .label
        content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
        cell.contentConfiguration = content
        cell.accessoryView = nil
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.backgroundView = UIView()
        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        cell.selectedBackgroundView = selectedBg
        return cell
    }
    
    @objc private func pendingApproveTapped(_ sender: UIButton) {
        let row = sender.tag
        guard row < pendingReceived.count else { return }
        let user = pendingReceived[row]
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        UserManager.shared.approveFriendRequest(receiverId: currentUserId, requesterId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadFriends()
                    self?.loadPending()
                    self?.showAlert(title: "Success", message: "Friend request approved.")
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func pendingRejectTapped(_ sender: UIButton) {
        let row = sender.tag
        guard row < pendingReceived.count else { return }
        let user = pendingReceived[row]
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        UserManager.shared.rejectFriendRequest(receiverId: currentUserId, requesterId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadPending()
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if currentSegment == Tab.pending.rawValue {
            return // Approve/Reject handled by buttons; sent rows have no action
        }
        let user = currentSegment == Tab.friends.rawValue ? friends[indexPath.row] : blockedUsers[indexPath.row]
        let alert = UIAlertController(title: user.name, message: nil, preferredStyle: .actionSheet)
        if currentSegment == Tab.friends.rawValue {
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
        
        print("DEBUG: Unfriending user: \(user.name) with ID: \(user.id)")
        
        // Remove from friends
        db.collection("users").document(currentUserId)
            .collection("friends").document(user.id).delete { [weak self] error in
                if let error = error {
                    print("DEBUG: Error unfriending user: \(error.localizedDescription)")
                    return
                }
                
                print("DEBUG: Successfully unfriended user")
                DispatchQueue.main.async {
                    self?.loadFriends()
                }
            }
    }
}
