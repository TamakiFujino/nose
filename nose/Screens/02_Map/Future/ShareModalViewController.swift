import UIKit

class ShareModalViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var bookmarkList: BookmarkList!
    var tableView: UITableView!
    var friendList: [[String: String]] = []
    var selectedFriends: Set<String> = []
    var onSharingConfirmed: ((Int) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        // Initialize the table view
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FriendCell.self, forCellReuseIdentifier: "FriendCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Initialize confirm button
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.setTitleColor(.fifthColor, for: .normal)
        confirmButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        confirmButton.contentHorizontalAlignment = .right
        confirmButton.setTitleColor(.fifthColor, for: .normal)
        confirmButton.addTarget(self, action: #selector(confirmSharing), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confirmButton)

        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -10),

            confirmButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            confirmButton.widthAnchor.constraint(equalToConstant: 160),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Load previously shared friends
        let key = "sharedFriends_\(bookmarkList.id)"
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            selectedFriends = Set(saved)
        }

// Load friends list
        loadFriendList()
    }

    private func loadFriendList() {
        if let savedFriendList = UserDefaults.standard.array(forKey: "friendList") as? [[String: String]] {
            friendList = savedFriendList
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath) as! FriendCell
        let friend = friendList[indexPath.row]
        cell.configure(with: friend)
        
        if let friendID = friend["id"], selectedFriends.contains(friendID) {
            cell.accessoryType = .checkmark
            cell.tintColor = .fourthColor
        } else {
            cell.accessoryType = .none
        }
    
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let friend = friendList[indexPath.row]
        if let friendID = friend["id"], selectedFriends.contains(friendID) {
            selectedFriends.remove(friendID)
        } else if let friendID = friend["id"] {
            selectedFriends.insert(friendID)
        }

        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    // MARK: - Actions

    @objc func confirmSharing() {
        // Save selected friends to UserDefaults
        let key = "sharedFriends_\(bookmarkList.id)"  // Use unique ID
        UserDefaults.standard.set(Array(selectedFriends), forKey: key)

        onSharingConfirmed?(selectedFriends.count)
        dismiss(animated: true, completion: nil)
        ToastManager.showToast(message: ToastMessages.collectionShared, type: .success)
    }
}

class FriendCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Customize cell UI if needed
    }

    func configure(with friend: [String: String]) {
        textLabel?.text = friend["name"]
    }
}
