import UIKit
import FirebaseFirestore
import FirebaseAuth

protocol ShareCollectionViewControllerDelegate: AnyObject {
    func shareCollectionViewController(_ controller: ShareCollectionViewController, didSelectFriends friends: [User])
}

final class ShareCollectionViewController: UIViewController {
    
    // MARK: - Properties
    private let collection: PlaceCollection
    private var friends: [User] = []
    private var selectedFriends: Set<String> = []
    private var previouslySharedFriends: Set<String> = [] // Track previously shared friends
    weak var delegate: ShareCollectionViewControllerDelegate?
    
    // MARK: - UI Components
    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .fourthColor
        label.numberOfLines = 0
        label.text = "Shared users can save spots to this collection, but cannot add friends, delete, or complete the collection."
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FriendSelectionCell.self, forCellReuseIdentifier: "FriendCell")
        tableView.allowsMultipleSelection = true
        return tableView
    }()
    
    private lazy var shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Update Sharing", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .fourthColor
        button.setTitleColor(.firstColor, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    init(collection: PlaceCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFriends()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .firstColor
        title = "Share Collection"
        
        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .sixthColor
        navigationItem.leftBarButtonItem = closeButton
        
        // Add subviews
        view.addSubview(infoLabel)
        view.addSubview(tableView)
        view.addSubview(shareButton)
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: shareButton.topAnchor, constant: -16),
            
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            shareButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        
        // First, get the current members
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading collection: \(error.localizedDescription)")
                    return
                }
                
                // Debug: Print the entire collection data
                if let data = snapshot?.data() {
                    print("📋 Full collection data: \(data)")
                } else {
                    print("📋 No collection data found")
                }
                
                // Get the list of current members
                let members = snapshot?.data()?["members"] as? [String] ?? [currentUserId]
                print("📋 Current members from Firestore: \(members)")
                
                // Remove owner from the list of previously shared friends
                self?.previouslySharedFriends = Set(members.filter { $0 != currentUserId })
                print("📋 Previously shared friends (excluding owner): \(self?.previouslySharedFriends ?? [])")
                
                // Clear selected friends and repopulate based on current members
                self?.selectedFriends.removeAll()
                
                // Then load all friends
                db.collection("users")
                    .document(currentUserId)
                    .collection("friends")
                    .getDocuments { [weak self] snapshot, error in
                        if let error = error {
                            print("Error loading friends: \(error.localizedDescription)")
                            return
                        }
                        
                        print("📋 Found \(snapshot?.documents.count ?? 0) friends in friends collection")
                        
                        // Create a dispatch group to handle multiple async operations
                        let group = DispatchGroup()
                        var loadedFriends: [User] = []
                        
                        snapshot?.documents.forEach { document in
                            group.enter()
                            let friendId = document.documentID
                            
                            // Fetch the complete user data from the users collection
                            db.collection("users").document(friendId).getDocument { userSnapshot, userError in
                                defer { group.leave() }
                                
                                if let userError = userError {
                                    print("Error fetching user data: \(userError.localizedDescription)")
                                    return
                                }
                                
                                if let userSnapshot = userSnapshot, let user = User.fromFirestore(userSnapshot) {
                                    loadedFriends.append(user)
                                    // If this friend is already a member, add them to selectedFriends
                                    if members.contains(friendId) {
                                        self?.selectedFriends.insert(friendId)
                                        print("✅ Added \(user.name) (ID: \(friendId)) to selectedFriends - already a member")
                                    } else {
                                        print("❌ \(user.name) (ID: \(friendId)) is not a member")
                                    }
                                }
                            }
                        }
                        
                        group.notify(queue: .main) {
                            self?.friends = loadedFriends
                            print("📋 Final selectedFriends: \(self?.selectedFriends ?? [])")
                            print("📋 Final previouslySharedFriends: \(self?.previouslySharedFriends ?? [])")
                            print("📋 Friends loaded: \(loadedFriends.map { "\($0.name) (ID: \($0.id))" })")
                            self?.tableView.reloadData()
                            self?.updateShareButtonState()
                        }
                    }
            }
    }
    
    private func updateShareButtonState() {
        // Enable button if there are changes
        let hasChanges = selectedFriends != self.previouslySharedFriends
        shareButton.isEnabled = hasChanges
        shareButton.alpha = hasChanges ? 1.0 : 0.5
    }
    
    @objc private func shareButtonTapped() {
        let selectedFriendsList = friends.filter { selectedFriends.contains($0.id) }
        print("📤 Selected friends to share with:")
        selectedFriendsList.forEach { friend in
            print("📤 Friend ID: \(friend.id), Name: \(friend.name)")
        }
        didSelectFriends(selectedFriendsList)
    }
    
    func didSelectFriends(_ friends: [User]) {
        print("📤 Passing friends to delegate:")
        friends.forEach { friend in
            print("📤 Friend ID: \(friend.id), Name: \(friend.name)")
        }
        delegate?.shareCollectionViewController(self, didSelectFriends: friends)
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension ShareCollectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath) as! FriendSelectionCell
        let friend = friends[indexPath.row]
        let isSelected = selectedFriends.contains(friend.id)
        let wasPreviouslyShared = previouslySharedFriends.contains(friend.id)
        
        print("🔍 Configuring cell for \(friend.name) (ID: \(friend.id)) - isSelected: \(isSelected), wasPreviouslyShared: \(wasPreviouslyShared)")
        
        cell.configure(with: friend, isSelected: isSelected, wasPreviouslyShared: wasPreviouslyShared)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let friend = friends[indexPath.row]
        if selectedFriends.contains(friend.id) {
            selectedFriends.remove(friend.id)
        } else {
            selectedFriends.insert(friend.id)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateShareButtonState()
    }
}

// MARK: - FriendSelectionCell
final class FriendSelectionCell: UITableViewCell {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        return label
    }()
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .fourthColor
        imageView.isHidden = true
        return imageView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .fourthColor
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmarkImageView)
        contentView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with user: User, isSelected: Bool, wasPreviouslyShared: Bool) {
        nameLabel.text = user.name
        checkmarkImageView.isHidden = !isSelected
        
        print("🎨 Cell config for \(user.name): isSelected=\(isSelected), wasPreviouslyShared=\(wasPreviouslyShared)")
        
        if wasPreviouslyShared && !isSelected {
            statusLabel.text = "Will be removed"
            statusLabel.textColor = .statusError
            print("🎨 Status: Will be removed")
        } else if !wasPreviouslyShared && isSelected {
            statusLabel.text = "Will be added"
            statusLabel.textColor = .statusSuccess
            print("🎨 Status: Will be added")
        } else {
            statusLabel.text = wasPreviouslyShared ? "Currently shared" : "Not shared"
            statusLabel.textColor = .fourthColor
            print("🎨 Status: \(wasPreviouslyShared ? "Currently shared" : "Not shared")")
        }
    }
} 
