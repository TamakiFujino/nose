import UIKit
import FirebaseFirestore
import FirebaseAuth

class FriendListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let customTabBar = CustomTabBar()
    let tableView = UITableView()
    var friendList: [[String: String]] = [] // Filtered list for "Friends" tab
    var blockedList: [[String: String]] = [] // Filtered list for "Blocked" tab
    
    private var allFriendsFromFirestore: [[String: String]] = []
    private var blockedFriends: Set<String> = [] // UIDs of users I have blocked
    private var blockedByFriends: Set<String> = [] // UIDs of users who have blocked me

    private let db = Firestore.firestore()
    private var currentUserID: String? { Auth.auth().currentUser?.uid }
    private let friendListDocID = "friendListDoc"
    private let blockListsDocID = "blockListsDoc"

    override func viewDidLoad() {
        super.viewDidLoad()

        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)

        // Set up navigation bar
        setupNavigationBar()

        // Set up custom tab bar
        setupCustomTabBar()

        // Set up UI
        setupUI()

        // Layout
        setupConstraints()

        // Load initial data
        loadBlockedListsFromFirestore() // Load the set of blocked friend UIDs from Firestore
        // fetchAllFriendsAndRefreshDisplay will be called in viewWillAppear
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchAllFriendsAndRefreshDisplay() // Refresh data every time the view appears
        self.navigationController?.navigationBar.tintColor = .black
    }

    private func setupNavigationBar() {
        navigationItem.title = "Friend list"
        let addFriendButton = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus.fill"), style: .plain, target: self, action: #selector(addFriendButtonTapped))
        navigationItem.rightBarButtonItem = addFriendButton

        // Hide the "Back" text in the back button
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }

    private func setupCustomTabBar() {
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        customTabBar.configureItems(["Friends", "Blocked"])
        view.addSubview(customTabBar)

        // Set up segmented control action
        customTabBar.segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
    }

    private func setupUI() {
        // Add table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FriendTableViewCell.self, forCellReuseIdentifier: "friendCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear // Remove the background color
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Custom tab bar constraints
            customTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customTabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customTabBar.heightAnchor.constraint(equalToConstant: 50), // Adjust height as needed

            // Table view constraints
            tableView.topAnchor.constraint(equalTo: customTabBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadBlockedListsFromFirestore() {
        guard let currentAuthUID = self.currentUserID else {
            print("Not logged in. Cannot load block lists.")
            self.blockedFriends = [] // Reset local cache
            self.blockedByFriends = []
            return
        }

        let blockListRef = db.collection("users").document(currentAuthUID).collection("userFriendData").document(blockListsDocID)

        blockListRef.getDocument { [weak self] (documentSnapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching block lists: \(error.localizedDescription)")
                self.blockedFriends = [] // Reset on error
                self.blockedByFriends = []
                // We still need to refresh the display even if block lists fail to load
                self.fetchAllFriendsAndRefreshDisplay()
                return
            }

            if let document = documentSnapshot, document.exists {
                if let blockedUIDsArray = document.data()?["blockedUIDs"] as? [String] {
                    self.blockedFriends = Set(blockedUIDsArray)
                } else {
                    self.blockedFriends = [] // Field might not exist yet
                }
                if let blockedByUIDsArray = document.data()?["blockedByUIDs"] as? [String] {
                    self.blockedByFriends = Set(blockedByUIDsArray)
                } else {
                    self.blockedByFriends = [] // Field might not exist yet
                }
                print("Blocked lists loaded. Blocked: \(self.blockedFriends.count), Blocked By: \(self.blockedByFriends.count)")
            } else {
                print("Block lists document does not exist for user \(currentAuthUID). Initializing with empty sets.")
                self.blockedFriends = []
                self.blockedByFriends = []
            }
            // Crucially, refresh the main friend list display after block lists are loaded (or failed to load)
            // because fetchAllFriendsAndRefreshDisplay depends on an up-to-date blockedFriends set.
            self.fetchAllFriendsAndRefreshDisplay()
        }
    }

    private func saveCurrentUserBlockedListToFirestore() {
        guard let currentAuthUID = self.currentUserID else {
            print("Not logged in. Cannot save block list.")
            // Optionally show an error to the user
            return
        }
        
        let blockListRef = db.collection("users").document(currentAuthUID).collection("userFriendData").document(blockListsDocID)
        
        // We save the current state of `self.blockedFriends`
        let dataToSave: [String: Any] = ["blockedUIDs": Array(self.blockedFriends)]
        
        blockListRef.setData(dataToSave, merge: true) { error in // merge:true to not overwrite blockedByUIDs
            if let error = error {
                print("Error saving blocked list: \(error.localizedDescription)")
                ToastManager.showToast(message: "Failed to update block list.", type: .error)
            } else {
                print("Blocked list saved successfully to Firestore.")
                // ToastManager.showToast(message: "Block list updated.", type: .success) // Optional
            }
        }
    }

    private func fetchAllFriendsAndRefreshDisplay() {
        guard let userID = currentUserID else {
            print("Error: Current user ID is nil. Cannot fetch friends.")
            // Optionally clear local lists and reload table if user logs out
            self.allFriendsFromFirestore = []
            refreshFilteredListsAndTable()
            return
        }

        db.collection("users").document(userID).collection("userFriendData").document("friendListDoc").getDocument { [weak self] (documentSnapshot, error) in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching friends from Firestore: \(error.localizedDescription)")
                // Keep existing local data or clear it, depending on desired behavior on error
                // For now, we'll clear it to reflect that we couldn't fetch.
                self.allFriendsFromFirestore = []
                self.refreshFilteredListsAndTable()
                return
            }

            if let document = documentSnapshot, document.exists {
                self.allFriendsFromFirestore = document.data()?["friends"] as? [[String: String]] ?? []
            } else {
                print("Friend list document does not exist for user \(userID). Initializing as empty.")
                self.allFriendsFromFirestore = [] // No document means no friends or an error in path
            }
            self.refreshFilteredListsAndTable()
        }
    }

    private func saveAllFriendsToFirestore() {
        guard let userID = currentUserID else {
            print("Error: Current user ID is nil. Cannot save friends.")
            return
        }
        guard !allFriendsFromFirestore.isEmpty else {
            // If the list is empty, we might want to delete the document or save an empty array
            // For consistency, saving an empty array.
            let friendsData = ["friends": []]
            db.collection("users").document(userID).collection("userFriendData").document("friendListDoc").setData(friendsData) { error in
                if let error = error {
                    print("Error saving empty friend list to Firestore: \(error.localizedDescription)")
                } else {
                    print("Successfully saved empty friend list to Firestore.")
                }
            }
            return
        }

        let friendsData = ["friends": self.allFriendsFromFirestore]
        db.collection("users").document(userID).collection("userFriendData").document("friendListDoc").setData(friendsData) { error in
            if let error = error {
                print("Error saving friend list to Firestore: \(error.localizedDescription)")
                ToastManager.showToast(message: "Failed to sync friends.", type: .error)
            } else {
                print("Successfully saved friend list to Firestore.")
                // ToastManager.showToast(message: "Friends synced.", type: .success) // Optional: success feedback
            }
        }
    }
    
    private func refreshFilteredListsAndTable() {
        self.friendList = self.allFriendsFromFirestore.filter { !blockedFriends.contains($0["id"] ?? "") }
        self.blockedList = self.allFriendsFromFirestore.filter { blockedFriends.contains($0["id"] ?? "") }
        self.tableView.reloadData()
    }

    @objc private func addFriendButtonTapped() {
        let addFriendVC = AddFriendViewController()
        navigationController?.pushViewController(addFriendVC, animated: true)
    }

    @objc private func segmentedControlChanged() {
        // The lists are already filtered, just need to reload the table
        // to reflect the correct segment's data source.
        tableView.reloadData()
    }

    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if customTabBar.segmentedControl.selectedSegmentIndex == 0 {
            return friendList.count
        } else {
            return blockedList.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "friendCell", for: indexPath) as! FriendTableViewCell
        let data = customTabBar.segmentedControl.selectedSegmentIndex == 0 ? friendList[indexPath.row] : blockedList[indexPath.row]
        cell.textLabel?.text = data["name"]
        cell.delegate = self
        cell.indexPath = indexPath
        cell.backgroundColor = .clear // Remove the background color of each cell
        return cell
    }

    // UITableViewDelegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let data = customTabBar.segmentedControl.selectedSegmentIndex == 0 ? friendList[indexPath.row] : blockedList[indexPath.row]
        let alert = UIAlertController(title: "Info", message: "ID: \(data["id"] ?? "")\nName: \(data["name"] ?? "")", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension FriendListViewController: FriendTableViewCellDelegate {
    func didTapOptionsButton(at indexPath: IndexPath) {
        let data = customTabBar.segmentedControl.selectedSegmentIndex == 0 ? friendList[indexPath.row] : blockedList[indexPath.row]
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if customTabBar.segmentedControl.selectedSegmentIndex == 0 {
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
        let friendToBlock = friendList[indexPath.row] // Friend is from the displayed (unblocked) list
        if let friendID = friendToBlock["id"] {
            blockedFriends.insert(friendID)
            saveCurrentUserBlockedListToFirestore() // Save updated blocked set to Firestore
            refreshFilteredListsAndTable() // Re-filter and update UI
            ToastManager.showToast(message: ToastMessages.userBlocked, type: .success)
        } else {
            ToastManager.showToast(message: ToastMessages.userBlockFailed, type: .error)
        }
    }
    
    private func unblockUser(at indexPath: IndexPath) {
        let friendToUnblock = blockedList[indexPath.row] // User is from the displayed blocked list
        if let friendID = friendToUnblock["id"] {
            blockedFriends.remove(friendID)
            saveCurrentUserBlockedListToFirestore() // Save updated blocked set to Firestore
            refreshFilteredListsAndTable() // Re-filter and update UI
            ToastManager.showToast(message: ToastMessages.userUnblocked, type: .success)
        } else {
            ToastManager.showToast(message: ToastMessages.userUnblockFailed, type: .error)
        }
    }
    
    private func unfriendUser(at indexPath: IndexPath) {
        // Ensure the operation is on the correct list based on the current tab
        guard customTabBar.segmentedControl.selectedSegmentIndex == 0, indexPath.row < friendList.count else {
            ToastManager.showToast(message: ToastMessages.userUnfriendFailed, type: .error)
            return
        }
        
        let friendToRemove = friendList[indexPath.row]
        
        // Remove from the source list
        if let friendIDToRemove = friendToRemove["id"] {
            allFriendsFromFirestore.removeAll { $0["id"] == friendIDToRemove }
        } else {
            // Fallback if ID is missing, though this shouldn't happen with valid data
            allFriendsFromFirestore.remove(at: indexPath.row) // This might be incorrect if IDs are not guaranteed
        }

        saveAllFriendsToFirestore() // Save the modified full list to Firestore
        // refreshFilteredListsAndTable() will be called by fetchAllFriendsAndRefreshDisplay via saveAllFriendsToFirestore's completion or if we call it directly.
        // For immediate UI update after local change before Firestore confirms:
        refreshFilteredListsAndTable()

        ToastManager.showToast(message: ToastMessages.userUnfrined, type: .success)
        // Removed UserDefaults.standard.set(friendList, forKey: "friendList")
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
