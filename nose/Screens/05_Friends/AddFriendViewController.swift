import UIKit
import FirebaseAuth

class AddFriendViewController: UIViewController, UITextFieldDelegate {

    let IDTextField = UITextField()
    let confirmButton = CustomButton()
    let userIDLabel = UILabel()
    let copyButton = UIButton(type: .system)
    let friendNameLabel = UILabel()
    var friendID: String?
    var blockedFriends: Set<String> = []
    var blockedByFriends: Set<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        let gradientView = CustomGradientView(frame: view.bounds)
        view.addSubview(gradientView)

        // Set up navigation bar
        setupNavigationBar()

        // Set up UI
        setupUI()

        // Layout
        setupConstraints()

        // Load the saved user ID and display it
        loadUserID()

        // Load blocked friends
        loadBlockedFriends()

        // Load friends who have blocked the current user
        loadBlockedByFriends()

        // Initially hide the confirm button
        confirmButton.isHidden = true
    }

    private func setupNavigationBar() {
        navigationItem.title = "Add a Friend"
        self.navigationController?.navigationBar.tintColor = .black
    }

    func setupUI() {
        IDTextField.placeholder = "Enter friend's ID"
        IDTextField.borderStyle = .roundedRect
        IDTextField.translatesAutoresizingMaskIntoConstraints = false
        IDTextField.isUserInteractionEnabled = true
        IDTextField.delegate = self
        IDTextField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        view.addSubview(IDTextField)

        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        confirmButton.isUserInteractionEnabled = true
        view.addSubview(confirmButton)

        // User ID Label
        userIDLabel.text = "Your ID: "
        userIDLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        userIDLabel.textColor = .darkGray
        userIDLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(userIDLabel)

        // Copy Button
        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let iconImage = UIImage(systemName: "doc.on.doc", withConfiguration: configuration)?.withTintColor(.darkGray, renderingMode: .alwaysOriginal)
        copyButton.setImage(iconImage, for: .normal)
        copyButton.addTarget(self, action: #selector(copyUserID), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(copyButton)

        // Friend Name Label
        friendNameLabel.text = ""
        friendNameLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        friendNameLabel.textColor = .black
        friendNameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(friendNameLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ID text field constraints
            IDTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            IDTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            IDTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),

            // User ID label constraints
            userIDLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            userIDLabel.topAnchor.constraint(equalTo: IDTextField.bottomAnchor, constant: 20),

            // Copy button constraints
            copyButton.leadingAnchor.constraint(equalTo: userIDLabel.trailingAnchor, constant: 10),
            copyButton.centerYAnchor.constraint(equalTo: userIDLabel.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 20),
            copyButton.heightAnchor.constraint(equalToConstant: 20),

            // Friend name label constraints
            friendNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            friendNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            friendNameLabel.topAnchor.constraint(equalTo: userIDLabel.bottomAnchor, constant: 20),

            // Confirm button constraints
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func loadUserID() {
        if let userID = UserDefaults.standard.string(forKey: "userID") {
            userIDLabel.text = "Your ID: \(userID)"
        } else {
            userIDLabel.text = "Your ID: Unset"
        }
    }

    private func loadBlockedFriends() {
        if let savedBlockedFriends = UserDefaults.standard.array(forKey: "blockedFriends") as? [String] {
            blockedFriends = Set(savedBlockedFriends)
        }
    }

    private func loadBlockedByFriends() {
        // Mock implementation - replace this with actual implementation to load friends who blocked the current user
        if let savedBlockedByFriends = UserDefaults.standard.array(forKey: "blockedByFriends") as? [String] {
            blockedByFriends = Set(savedBlockedByFriends)
        }
    }

    @objc func copyUserID() {
        if let userID = UserDefaults.standard.string(forKey: "userID") {
            UIPasteboard.general.string = userID
            showFlashMessage("ID copied")
        }
    }

    @objc func confirmButtonTapped() {
        guard let friendID = friendID else { return }

        // Add friend to the friend list
        addFriend(friendID, name: friendNameLabel.text?.replacingOccurrences(of: "Friend's Name: ", with: "") ?? "")
        ToastManager.showToast(message: ToastMessages.friendAdded, type: .success)

        // Reset UI
        friendNameLabel.text = ""
        confirmButton.isHidden = true
        IDTextField.text = ""
    }

    private func addFriend(_ friendID: String, name: String) {
        // Retrieve the current friend list from UserDefaults
        var friendList = UserDefaults.standard.array(forKey: "friendList") as? [[String: String]] ?? []

        // Add the new friend to the list
        friendList.append(["id": friendID, "name": name])

        // Save the updated friend list back to UserDefaults
        UserDefaults.standard.set(friendList, forKey: "friendList")
    }

    private func getUserNameByID(_ userID: String, completion: @escaping (String?) -> Void) {
        // Mock data
        let mockUserDatabase = [
            "123456789": "Taro Yamada",
            "987654321": "Ichiro Suzuki",
            "111111111": "Ken Sato"
        ]

        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let userName = mockUserDatabase[userID]
            completion(userName)
        }
    }

    private func showFlashMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)

        // Duration in seconds
        let duration: Double = 1.5

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            alert.dismiss(animated: true, completion: nil)
        }
    }

    // UITextFieldDelegate method
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // Dismiss keyboard when return key is pressed

        guard let friendID = IDTextField.text, !friendID.isEmpty else {
            showFlashMessage("Please enter an ID")
            return true
        }

        // Check if the user is blocked or being blocked
        if blockedFriends.contains(friendID) {
            showFlashMessage("This user is blocked")
            return true
        }

        if blockedByFriends.contains(friendID) {
            showFlashMessage("You are blocked by this user")
            return true
        }

        // Search for the user by ID
        getUserNameByID(friendID) { [weak self] userName in
            guard let self = self else { return }
            if let userName = userName {
                self.friendID = friendID
                self.friendNameLabel.text = "Friend's Name: \(userName)"
                self.confirmButton.isHidden = false
            } else {
                self.friendID = nil
                self.friendNameLabel.text = ""
                self.confirmButton.isHidden = true
                self.showFlashMessage("User not found")
            }
        }

        return true
    }
}
