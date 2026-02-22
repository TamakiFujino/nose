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
    
    private enum Tab: Int, CaseIterable {
        case friends = 0
        case pending = 1
        case requested = 2
        case blocked = 3
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
        updateEmptyState()
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

    /// Fetches full User documents for the given user IDs; completion is called on main with parsed users (order not guaranteed).
    private func fetchUsers(ids: [String], db: Firestore, completion: @escaping ([User]) -> Void) {
        guard !ids.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        let group = DispatchGroup()
        var users: [User] = []
        let lock = NSLock()
        ids.forEach { id in
            group.enter()
            FirestorePaths.userDoc(id, db: db).getDocument { snapshot, error in
                defer { group.leave() }
                guard let snapshot = snapshot, let user = User.fromFirestore(snapshot) else { return }
                lock.lock()
                users.append(user)
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
            completion(users)
        }
    }

    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        FirestorePaths.friends(userId: currentUserId, db: db).getDocuments { [weak self] snapshot, error in
            if let error = error { return }
            let ids = snapshot?.documents.map(\.documentID) ?? []
            self?.fetchUsers(ids: ids, db: db) { users in
                self?.friends = users
                if self?.currentSegment == Tab.friends.rawValue {
                    self?.tableView.reloadData()
                    self?.updateEmptyState()
                }
            }
        }

        FirestorePaths.blocked(userId: currentUserId, db: db).getDocuments { [weak self] snapshot, error in
            if let error = error { return }
            let ids = snapshot?.documents.map(\.documentID) ?? []
            self?.fetchUsers(ids: ids, db: db) { users in
                self?.blockedUsers = users
                if self?.currentSegment == Tab.blocked.rawValue {
                    self?.tableView.reloadData()
                    self?.updateEmptyState()
                }
            }
        }

        loadPending()
    }

    private func loadPending() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        FirestorePaths.friendRequests(userId: currentUserId, db: db).getDocuments { [weak self] snapshot, error in
            if let error = error { return }
            let ids = snapshot?.documents.map(\.documentID) ?? []
            self?.fetchUsers(ids: ids, db: db) { users in
                self?.pendingReceived = users
                if self?.currentSegment == Tab.pending.rawValue {
                    self?.tableView.reloadData()
                    self?.updateEmptyState()
                }
            }
        }

        FirestorePaths.sentFriendRequests(userId: currentUserId, db: db).getDocuments { [weak self] snapshot, error in
            if let error = error { return }
            let ids = snapshot?.documents.map(\.documentID) ?? []
            self?.fetchUsers(ids: ids, db: db) { users in
                self?.pendingSent = users
                if self?.currentSegment == Tab.requested.rawValue {
                    self?.tableView.reloadData()
                    self?.updateEmptyState()
                }
            }
        }
    }
    
    // MARK: - Actions
    // MARK: - Tab Management
    private static let tabTitles: [(Tab, String)] = [(.friends, "Friends"), (.pending, "Pending"), (.requested, "Requested"), (.blocked, "Blocked")]

    private func setupCategoryTabs() {
        for (index, (tab, title)) in Self.tabTitles.enumerated() {
            let button = createTabButton(title: title, tag: index, tab: tab)
            if tab == .pending {
                button.accessibilityIdentifier = "Pending"
            } else if tab == .requested {
                button.accessibilityIdentifier = "Requested"
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
        for (index, tab) in Tab.allCases.enumerated() {
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
        guard sender.tag < Tab.allCases.count, let tab = Tab(rawValue: sender.tag) else { return }
        currentSegment = tab.rawValue
        updateTabButtonStates()
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func emptyMessage(for tab: Tab) -> String {
        switch tab {
        case .friends:
            return "No friends yet. Share your User ID from Add Friend so others can send you a request."
        case .pending:
            return "No pending requests. When someone sends you a friend request, it will appear here."
        case .requested:
            return "No requests sent. When you send a friend request from Add Friend, it will appear here until they respond."
        case .blocked:
            return "No blocked users."
        }
    }
    
    private func updateEmptyState() {
        let count: Int
        let tab = Tab(rawValue: currentSegment) ?? .friends
        switch tab {
        case .friends: count = friends.count
        case .pending: count = pendingReceived.count
        case .requested: count = pendingSent.count
        case .blocked: count = blockedUsers.count
        }
        if count == 0 {
            let container = UIView()
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = emptyMessage(for: tab)
            label.font = .systemFont(ofSize: 15, weight: .regular)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 0
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            tableView.backgroundView = container
        } else {
            tableView.backgroundView = nil
        }
    }

    private func configurePendingReceivedCell(_ cell: UITableViewCell, user: User, indexPath: IndexPath) {
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.backgroundView = UIView()
        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        cell.selectedBackgroundView = selectedBg
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = user.name
        nameLabel.font = .systemFont(ofSize: 17, weight: .medium)
        nameLabel.textColor = .label

        let approve = UIButton(type: .system)
        approve.setTitle("Approve", for: .normal)
        approve.tag = indexPath.row
        approve.accessibilityIdentifier = "Approve"
        approve.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        approve.setTitleColor(.black, for: .normal)
        approve.backgroundColor = .secondColor
        approve.layer.cornerRadius = 16
        approve.layer.masksToBounds = true
        approve.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        approve.addTarget(self, action: #selector(pendingApproveTapped(_:)), for: .touchUpInside)

        let reject = UIButton(type: .system)
        reject.setTitle("Reject", for: .normal)
        reject.tag = indexPath.row
        reject.accessibilityIdentifier = "Reject"
        reject.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        reject.setTitleColor(.black, for: .normal)
        reject.backgroundColor = .secondColor
        reject.layer.cornerRadius = 16
        reject.layer.masksToBounds = true
        reject.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        reject.addTarget(self, action: #selector(pendingRejectTapped(_:)), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [approve, reject])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(nameLabel)
        cell.contentView.addSubview(buttonStack)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -12),
            buttonStack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            buttonStack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
    }

    private func showAlert(title: String, message: String) {
        let messageModal = MessageModalViewController(title: title, message: message)
        present(messageModal, animated: true)
    }
    
    private func blockUser(_ user: User) {
        let modal = ConfirmationModalViewController(
            title: "Block user?",
            message: "Are you sure you want to block \"\(user.name)\"? You will not be able to share a collection or add them as a friend.",
            primaryTitle: "Block",
            primaryStyle: .destructive,
            cancelTitle: "Cancel",
            onPrimary: { [weak self] in
                self?.performBlockUser(user)
            },
            onCancel: nil
        )
        present(modal, animated: true)
    }

    private func performBlockUser(_ user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        UserManager.shared.blockUser(currentUserId: currentUserId, blockedUserId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadFriends()
                    self?.showAlert(title: "Success", message: "User blocked successfully")
                case .failure(let error):
                    self?.showAlert(title: "Error", message: "Failed to block user: \(error.localizedDescription)")
                }
            }
        }
    }

    private func unblockUser(_ user: User) {
        let modal = ConfirmationModalViewController(
            title: "Unblock user?",
            message: "\(user.name) will be able to add you as a friend with your User ID.",
            primaryTitle: "Unblock",
            cancelTitle: "Cancel",
            onPrimary: { [weak self] in
                self?.performUnblockUser(user)
            },
            onCancel: nil
        )
        present(modal, animated: true)
    }

    private func performUnblockUser(_ user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        UserManager.shared.unblockUser(currentUserId: currentUserId, blockedUserId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadFriends()
                    self?.showAlert(title: "Success", message: "User unblocked successfully")
                case .failure(let error):
                    self?.showAlert(title: "Error", message: "Failed to unblock user: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension FriendsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Tab(rawValue: currentSegment) {
        case .friends: return friends.count
        case .pending: return pendingReceived.count
        case .requested: return pendingSent.count
        case .blocked: return blockedUsers.count
        case .none: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Tab(rawValue: currentSegment) {
        case .pending:
            let cell = tableView.dequeueReusableCell(withIdentifier: "PendingReceivedCell", for: indexPath)
            let user = pendingReceived[indexPath.row]
            configurePendingReceivedCell(cell, user: user, indexPath: indexPath)
            return cell
        case .requested:
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
        case .friends, .blocked:
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
        case .none:
            return tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        }
    }
    
    @objc private func pendingApproveTapped(_ sender: UIButton) {
        let row = sender.tag
        guard row < pendingReceived.count else { return }
        let user = pendingReceived[row]
        let modal = ConfirmationModalViewController(
            title: "Approve request",
            message: "Add \(user.name) as a friend?",
            primaryTitle: "Approve",
            cancelTitle: "Cancel",
            onPrimary: { [weak self] in
                self?.performApproveFriendRequest(from: user)
            },
            onCancel: nil
        )
        present(modal, animated: true)
    }

    private func performApproveFriendRequest(from user: User) {
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
        let modal = ConfirmationModalViewController(
            title: "Reject request",
            message: "Reject friend request from \(user.name)?",
            primaryTitle: "Reject",
            primaryStyle: .default,
            cancelTitle: "Cancel",
            onPrimary: { [weak self] in
                self?.performRejectFriendRequest(from: user)
            },
            onCancel: nil
        )
        present(modal, animated: true)
    }

    private func performRejectFriendRequest(from user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        UserManager.shared.rejectFriendRequest(receiverId: currentUserId, requesterId: user.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadPending()
                    self?.updateEmptyState()
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if currentSegment == Tab.pending.rawValue || currentSegment == Tab.requested.rawValue {
            return // Approve/Reject handled by buttons; requested rows have no action
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
}
