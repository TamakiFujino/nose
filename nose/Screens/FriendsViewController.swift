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
        tableView.backgroundColor = .systemBackground
        return tableView
    }()
    
    private lazy var addFriendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "person.badge.plus"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(addFriendButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFriends()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Friends"
        
        // Add subviews
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(addFriendButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            addFriendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addFriendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addFriendButton.widthAnchor.constraint(equalToConstant: 50),
            addFriendButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Load friends
        db.collection("users").document(currentUserId)
            .collection("friends").getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading friends: \(error.localizedDescription)")
                    return
                }
                
                self?.friends = snapshot?.documents.compactMap { document in
                    User.fromFirestore(document)
                } ?? []
                
                DispatchQueue.main.async {
                    if self?.currentSegment == 0 {
                        self?.tableView.reloadData()
                    }
                }
            }
        
        // Load blocked users
        db.collection("users").document(currentUserId)
            .collection("blocked").getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading blocked users: \(error.localizedDescription)")
                    return
                }
                
                self?.blockedUsers = snapshot?.documents.compactMap { document in
                    User.fromFirestore(document)
                } ?? []
                
                DispatchQueue.main.async {
                    if self?.currentSegment == 1 {
                        self?.tableView.reloadData()
                    }
                }
            }
    }
    
    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        currentSegment = sender.selectedSegmentIndex
        tableView.reloadData()
    }
    
    @objc private func addFriendButtonTapped() {
        let addFriendVC = AddFriendViewController()
        navigationController?.pushViewController(addFriendVC, animated: true)
    }
    
    private func addFriend(withEmail email: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
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
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension FriendsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSegment == 0 ? friends.count : blockedUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = currentSegment == 0 ? friends[indexPath.row] : blockedUsers[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = user.name
        cell.contentConfiguration = content
        
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
    
    private func blockUser(_ user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Remove from friends
        db.collection("users").document(currentUserId)
            .collection("friends").document(user.id).delete()
        
        // Add to blocked
        db.collection("users").document(currentUserId)
            .collection("blocked").document(user.id).setData([
                "blockedAt": FieldValue.serverTimestamp()
            ])
        
        loadFriends()
    }
    
    private func unblockUser(_ user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Remove from blocked
        db.collection("users").document(currentUserId)
            .collection("blocked").document(user.id).delete()
        
        loadFriends()
    }
}

