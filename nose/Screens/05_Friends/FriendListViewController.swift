import UIKit

class FriendListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let headerLabel = UILabel()
    let segmentedControl = UISegmentedControl(items: ["Friends", "Blocked"])
    let tableView = UITableView()
    var friendList: [[String: String]] = []
    var blockedList: [[String: String]] = []
    var blockedFriends: Set<String> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set background white
        view.backgroundColor = .white
        
        // Set up navigation bar
        setupNavigationBar()
        
        // Set up UI
        setupUI()
        
        // Layout
        setupConstraints()
        
        // Load the friend and blocked lists
        loadFriendList()
        loadBlockedFriends()
        loadBlockedList()
        
        // Initially show friends tab
        segmentedControl.selectedSegmentIndex = 0
        updateTableView()
    }
    
    private func setupNavigationBar() {
        let addFriendButton = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus.fill"), style: .plain, target: self, action: #selector(addFriendButtonTapped))
        navigationItem.rightBarButtonItem = addFriendButton
    }
    
    private func setupUI() {
        // Add heading
        headerLabel.text = "ともだちリスト"
        headerLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        headerLabel.textColor = .black
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        
        // Add segmented control
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        // Add table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FriendTableViewCell.self, forCellReuseIdentifier: "friendCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header label constraints
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Segmented control constraints
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            
            // Table view constraints
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadFriendList() {
        if let savedFriendList = UserDefaults.standard.array(forKey: "friendList") as? [[String: String]] {
            friendList = savedFriendList.filter { !blockedFriends.contains($0["id"] ?? "") }
        }
    }
    
    private func loadBlockedFriends() {
        if let savedBlockedFriends = UserDefaults.standard.array(forKey: "blockedFriends") as? [String] {
            blockedFriends = Set(savedBlockedFriends)
        }
    }
    
    private func loadBlockedList() {
        if let savedFriendList = UserDefaults.standard.array(forKey: "friendList") as? [[String: String]] {
            blockedList = savedFriendList.filter { blockedFriends.contains($0["id"] ?? "") }
        }
    }
    
    private func saveBlockedFriends() {
        UserDefaults.standard.set(Array(blockedFriends), forKey: "blockedFriends")
    }
    
    @objc private func addFriendButtonTapped() {
        let addFriendVC = AddFriendViewController()
        navigationController?.pushViewController(addFriendVC, animated: true)
    }
    
    @objc private func segmentedControlChanged() {
        updateTableView()
    }
    
    private func updateTableView() {
        if segmentedControl.selectedSegmentIndex == 0 {
            loadFriendList()
        } else {
            loadBlockedList()
        }
        tableView.reloadData()
    }
    
    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return friendList.count
        } else {
            return blockedList.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "friendCell", for: indexPath) as! FriendTableViewCell
        let data = segmentedControl.selectedSegmentIndex == 0 ? friendList[indexPath.row] : blockedList[indexPath.row]
        cell.textLabel?.text = data["name"]
        cell.delegate = self
        cell.indexPath = indexPath
        return cell
    }
    
    // UITableViewDelegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let data = segmentedControl.selectedSegmentIndex == 0 ? friendList[indexPath.row] : blockedList[indexPath.row]
        let alert = UIAlertController(title: "Info", message: "ID: \(data["id"] ?? "")\nName: \(data["name"] ?? "")", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension FriendListViewController: FriendTableViewCellDelegate {
    func didTapOptionsButton(at indexPath: IndexPath) {
        let data = segmentedControl.selectedSegmentIndex == 0 ? friendList[indexPath.row] : blockedList[indexPath.row]
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if segmentedControl.selectedSegmentIndex == 0 {
            let blockAction = UIAlertAction(title: "Block User", style: .destructive) { _ in
                self.blockUser(at: indexPath)
            }
            let unfriendAction = UIAlertAction(title: "Unfriend User", style: .destructive) { _ in
                self.unfriendUser(at: indexPath)
            }
            actionSheet.addAction(blockAction)
            actionSheet.addAction(unfriendAction)
        } else {
            let unblockAction = UIAlertAction(title: "Unblock User", style: .default) { _ in
                self.unblockUser(at: indexPath)
            }
            actionSheet.addAction(unblockAction)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func blockUser(at indexPath: IndexPath) {
        let friend = friendList[indexPath.row]
        if let friendID = friend["id"] {
            blockedFriends.insert(friendID)
            saveBlockedFriends()
            friendList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    private func unblockUser(at indexPath: IndexPath) {
        let blocked = blockedList[indexPath.row]
        if let blockedID = blocked["id"] {
            blockedFriends.remove(blockedID)
            saveBlockedFriends()
            blockedList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            // Add back to friend list
            friendList.append(blocked)
        }
    }
    
    private func unfriendUser(at indexPath: IndexPath) {
        friendList.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        // Save the updated friend list
        UserDefaults.standard.set(friendList, forKey: "friendList")
    }
}

protocol FriendTableViewCellDelegate: AnyObject {
    func didTapOptionsButton(at indexPath: IndexPath)
}

class FriendTableViewCell: UITableViewCell {
    
    weak var delegate: FriendTableViewCellDelegate?
    var indexPath: IndexPath?
    
    private let optionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis")?.withTintColor(.black, renderingMode: .alwaysOriginal), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(optionsButton)
        NSLayoutConstraint.activate([
            optionsButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        optionsButton.addTarget(self, action: #selector(optionsButtonTapped), for: .touchUpInside)
    }
    
    @objc private func optionsButtonTapped() {
        guard let indexPath = indexPath else { return }
        delegate?.didTapOptionsButton(at: indexPath)
    }
}
