import UIKit
import FirebaseAuth
import FirebaseFirestore

final class FriendsViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let cellHeight: CGFloat = 60
    }
    
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
        view.backgroundColor = .firstColor
        title = "Friends"
        navigationController?.navigationBar.tintColor = .label
        navigationItem.largeTitleDisplayMode = .never
        
        setupSubviews()
        setupConstraints()
    }
    
    private func setupSubviews() {
        [segmentedControl, tableView].forEach {
            view.addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.standardPadding),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: Constants.standardPadding),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        UserManager.shared.getFriends(userId: currentUserId) { [weak self] result in
            switch result {
            case .success(let friends):
                DispatchQueue.main.async {
                    self?.friends = friends
                    if self?.currentSegment == 0 {
                        self?.tableView.reloadData()
                    }
                }
            case .failure(let error):
                print("Error loading friends: \(error.localizedDescription)")
            }
        }
        
        UserManager.shared.getBlockedUsers(userId: currentUserId) { [weak self] result in
            switch result {
            case .success(let blockedUsers):
                DispatchQueue.main.async {
                    self?.blockedUsers = blockedUsers
                    if self?.currentSegment == 1 {
                        self?.tableView.reloadData()
                    }
                }
            case .failure(let error):
                print("Error loading blocked users: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        currentSegment = sender.selectedSegmentIndex
        tableView.reloadData()
    }
    
    private func showUserActions(for user: User) {
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
        let alert = UIAlertController(
            title: "Block User",
            message: "Are you sure you want to block \"\(user.name)\"? You will not be able to share collections or add them as a friend.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            UserManager.shared.blockUser(currentUserId: currentUserId, blockedUserId: user.id) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self?.loadFriends()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func unblockUser(_ user: User) {
        let alert = UIAlertController(
            title: "Unblock User",
            message: "Are you sure you want to unblock \"\(user.name)\"? They will be able to add you as a friend with your User ID.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Unblock", style: .default) { [weak self] _ in
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            UserManager.shared.unblockUser(currentUserId: currentUserId, blockedUserId: user.id) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self?.loadFriends()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        })
        
        present(alert, animated: true)
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
        content.textProperties.color = .label
        content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        let backgroundView = UIView()
        cell.backgroundView = backgroundView
        
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        cell.selectedBackgroundView = selectedBackgroundView
        
        cell.contentConfiguration = content
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = currentSegment == 0 ? friends[indexPath.row] : blockedUsers[indexPath.row]
        showUserActions(for: user)
    }
}
