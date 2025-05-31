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
    weak var delegate: ShareCollectionViewControllerDelegate?
    
    // MARK: - UI Components
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
        button.setTitle("Share", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .fourthColor
        button.setTitleColor(.white, for: .normal)
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
        view.backgroundColor = .systemBackground
        title = "Share Collection"
        
        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .black
        navigationItem.leftBarButtonItem = closeButton
        
        // Add subviews
        view.addSubview(tableView)
        view.addSubview(shareButton)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
    
    @objc private func shareButtonTapped() {
        let selectedFriendsList = friends.filter { selectedFriends.contains($0.id) }
        didSelectFriends(selectedFriendsList)
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        
        // First, get the current shared friends
        db.collection("users")
            .document(currentUserId)
            .collection("collections")
            .document(collection.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading collection: \(error.localizedDescription)")
                    return
                }
                
                // Get the list of currently shared friends
                let sharedWith = snapshot?.data()?["sharedWith"] as? [String] ?? []
                
                // Then load all friends
                db.collection("users")
                    .document(currentUserId)
                    .collection("friends")
                    .getDocuments { [weak self] snapshot, error in
                        if let error = error {
                            print("Error loading friends: \(error.localizedDescription)")
                            return
                        }
                        
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
                                    // If this friend is already shared with, add them to selectedFriends
                                    if sharedWith.contains(friendId) {
                                        self?.selectedFriends.insert(friendId)
                                    }
                                }
                            }
                        }
                        
                        group.notify(queue: .main) {
                            self?.friends = loadedFriends
                            self?.tableView.reloadData()
                            self?.updateShareButtonState()
                        }
                    }
            }
    }
    
    private func updateShareButtonState() {
        if selectedFriends.isEmpty {
            shareButton.setTitle("Remove All Friends", for: .normal)
        } else {
            shareButton.setTitle("Share", for: .normal)
        }
    }
    
    func didSelectFriends(_ friends: [User]) {
        delegate?.shareCollectionViewController(self, didSelectFriends: friends)
        // Don't dismiss the view controller
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
        cell.configure(with: friend, isSelected: selectedFriends.contains(friend.id))
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
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with user: User, isSelected: Bool) {
        nameLabel.text = user.name
        checkmarkImageView.isHidden = !isSelected
    }
} 
