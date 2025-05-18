import UIKit
import FirebaseAuth
import FirebaseFirestore

class AddFriendViewController: UIViewController, UITextFieldDelegate {

    let IDTextField = UITextField()
    let confirmButton = CustomButton()
    let userIDLabel = UILabel()
    let copyButton = UIButton(type: .system)
    let friendNameLabel = UILabel()
    
    private var friendAuthUIDToConfirm: String?
    private var myFriendId: String?

    var blockedFriends: Set<String> = []
    var blockedByFriends: Set<String> = []

    private let db = Firestore.firestore()
    private var currentAuthUID: String? { Auth.auth().currentUser?.uid }
    private let friendListDocID = "friendListDoc"
    private let blockListsDocID = "blockListsDoc"

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
        displayMyFriendId()

        // Load blocked friends from Firestore
        loadBlockedListsFromFirestore()

        // Initially hide the confirm button
        confirmButton.isHidden = true
    }

    private func setupNavigationBar() {
        navigationItem.title = "Add Friend by ID"
        self.navigationController?.navigationBar.tintColor = .black
    }

    func setupUI() {
        IDTextField.placeholder = "Enter 9-digit Friend ID"
        IDTextField.borderStyle = .roundedRect
        IDTextField.translatesAutoresizingMaskIntoConstraints = false
        IDTextField.delegate = self
        IDTextField.heightAnchor.constraint(equalToConstant: 45).isActive = true
        IDTextField.autocapitalizationType = .allCharacters
        IDTextField.autocorrectionType = .no
        view.addSubview(IDTextField)

        confirmButton.setTitle("Confirm Friend", for: .normal)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        view.addSubview(confirmButton)

        userIDLabel.text = "Your Friend ID: Fetching..."
        userIDLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        userIDLabel.textColor = .darkGray
        userIDLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(userIDLabel)

        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let iconImage = UIImage(systemName: "doc.on.doc", withConfiguration: configuration)?.withTintColor(.darkGray, renderingMode: .alwaysOriginal)
        copyButton.setImage(iconImage, for: .normal)
        copyButton.addTarget(self, action: #selector(copyMyFriendId), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(copyButton)

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

    private func displayMyFriendId() {
        guard let currentAuthUID = self.currentAuthUID else {
            userIDLabel.text = "Your Friend ID: Not Logged In"
            copyButton.isEnabled = false
            return
        }
        db.collection("users").document(currentAuthUID).getDocument { [weak self] (documentSnapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching your user data: \(error.localizedDescription)")
                self.userIDLabel.text = "Your Friend ID: Error"
                self.copyButton.isEnabled = false
                return
            }
            if let document = documentSnapshot, document.exists,
               let friendId = document.data()?["friendId"] as? String {
                self.myFriendId = friendId
                self.userIDLabel.text = "Your Friend ID: \(friendId)"
                self.copyButton.isEnabled = true
            } else {
                self.userIDLabel.text = "Your Friend ID: Not Set"
                self.copyButton.isEnabled = false
                 print("Friend ID not found for current user.")
            }
        }
    }

    private func loadBlockedListsFromFirestore() {
        guard let currentAuthUID = self.currentAuthUID else {
            print("Not logged in. Cannot load block lists.")
            return
        }

        let blockListRef = db.collection("users").document(currentAuthUID)
                              .collection("userFriendData").document(blockListsDocID)

        blockListRef.getDocument { [weak self] (documentSnapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching block lists: \(error.localizedDescription)")
                // Handle error appropriately, maybe with a default state
                return
            }

            if let document = documentSnapshot, document.exists {
                if let blockedUIDsArray = document.data()?["blockedUIDs"] as? [String] {
                    self.blockedFriends = Set(blockedUIDsArray)
                }
                if let blockedByUIDsArray = document.data()?["blockedByUIDs"] as? [String] {
                    self.blockedByFriends = Set(blockedByUIDsArray)
                }
                print("Blocked lists loaded. Blocked: \(self.blockedFriends.count), Blocked By: \(self.blockedByFriends.count)")
            } else {
                print("Block lists document does not exist. Initializing with empty sets.")
                self.blockedFriends = []
                self.blockedByFriends = []
            }
        }
    }
    
    // Call this function when the user blocks/unblocks someone.
    // The `updatedBlockedSet` should be the complete new set of UIDs the current user has blocked.
    public func saveCurrentUserBlockedListToFirestore(updatedBlockedSet: Set<String>) {
        guard let currentAuthUID = self.currentAuthUID else {
            print("Not logged in. Cannot save block list.")
            // Optionally show an error to the user
            return
        }
        
        let blockListRef = db.collection("users").document(currentAuthUID)
                              .collection("userFriendData").document(blockListsDocID)
        
        let dataToSave: [String: Any] = ["blockedUIDs": Array(updatedBlockedSet)]
        
        blockListRef.setData(dataToSave, merge: true) { error in
            if let error = error {
                print("Error saving blocked list: \(error.localizedDescription)")
                // Optionally show an error to the user
            } else {
                print("Blocked list saved successfully.")
                // Update local set after successful save
                self.blockedFriends = updatedBlockedSet
            }
        }
    }

    @objc func copyMyFriendId() {
        if let id = myFriendId {
            UIPasteboard.general.string = id
            showFlashMessage("Friend ID copied!")
        } else {
            showFlashMessage("Friend ID not available to copy.")
        }
    }

    @objc func confirmButtonTapped() {
        guard let friendAuthUID = friendAuthUIDToConfirm,
              let friendDisplayName = friendNameLabel.text?.replacingOccurrences(of: "Friend's Name: ", with: ""),
              !friendDisplayName.isEmpty else {
            ToastManager.showToast(message: "Could not confirm friend. User details missing.", type: .error)
            return
        }
        addFriendToFirestore(friendAuthUID: friendAuthUID, friendDisplayName: friendDisplayName)
    }

    private func addFriendToFirestore(friendAuthUID: String, friendDisplayName: String) {
        guard let currentUserAuthUID = self.currentAuthUID else {
            ToastManager.showToast(message: "You must be logged in to add friends.", type: .error)
            return
        }

        if friendAuthUID == currentUserAuthUID {
            ToastManager.showToast(message: "You cannot add yourself as a friend.", type: .error)
            return
        }

        let friendDataDocumentRef = db.collection("users").document(currentUserAuthUID)
                                       .collection("userFriendData").document(friendListDocID)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let friendListDocument: DocumentSnapshot
            do {
                try friendListDocument = transaction.getDocument(friendDataDocumentRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            var currentFriendsArray = friendListDocument.data()?["friends"] as? [[String: String]] ?? []

            if currentFriendsArray.contains(where: { $0["id"] == friendAuthUID }) {
                DispatchQueue.main.async {
                    ToastManager.showToast(message: "You are already friends with this user.", type: .info)
                    self.resetUIForNewEntry()
                }
                return nil // Abort transaction by returning a non-nil error or just nil to stop processing
            }

            let newFriendData = ["id": friendAuthUID, "name": friendDisplayName]
            currentFriendsArray.append(newFriendData)
            transaction.setData(["friends": currentFriendsArray], forDocument: friendDataDocumentRef, merge: true) // merge:true is safer if doc has other fields
            return nil
        }) { [weak self] (_, error) in
            guard let self = self else { return }
            if let error = error {
                print("Add friend transaction failed: \(error.localizedDescription)")
                // ToastManager.showToast(message: ToastMessages.friendAddFailed, type: .error)
            } else {
                print("Friend added successfully via transaction.")
                ToastManager.showToast(message: ToastMessages.friendAdded, type: .success)
                self.resetUIForNewEntry()
            }
        }
    }
    
    private func resetUIForNewEntry(){
        IDTextField.text = ""
        friendNameLabel.text = ""
        confirmButton.isHidden = true
        friendAuthUIDToConfirm = nil
    }

    // Fetches a user's Firebase Auth UID and displayName using their friendId
    private func fetchUserDetailsByFriendId(friendId: String, completion: @escaping (_ firebaseUID: String?, _ displayName: String?) -> Void) {
        if friendId.count != 9 { // Basic validation
            completion(nil, nil)
            return
        }
        db.collection("users").whereField("friendId", isEqualTo: friendId).limit(to: 1).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching user by friendId \(friendId): \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                print("No user found with friendId: \(friendId)")
                completion(nil, nil)
                return
            }
            let userDocument = documents.first!
            let firebaseUID = userDocument.documentID
            let displayName = userDocument.data()["displayName"] as? String
            completion(firebaseUID, displayName)
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
        textField.resignFirstResponder()
        guard let enteredId = IDTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !enteredId.isEmpty else {
            showFlashMessage("Please enter a Friend ID.")
            return true
        }
        
        if enteredId.count != 9 {
            showFlashMessage("Friend ID must be 9 characters.")
            resetUIForNewEntry() // Clear any previous search results
            return true
        }

        if let myId = self.myFriendId, enteredId == myId {
            showFlashMessage("You cannot add yourself.")
            resetUIForNewEntry()
            return true
        }

        fetchUserDetailsByFriendId(friendId: enteredId) { [weak self] (firebaseUID, displayName) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let uid = firebaseUID, let name = displayName {
                    // Check if this Firebase Auth UID is in the locally loaded blockedFriends list
                    if self.blockedFriends.contains(uid) {
                        self.showFlashMessage("This user is in your blocked list.")
                        self.resetUIForNewEntry()
                        return
                    }
                    // Check if this Firebase Auth UID is in the locally loaded blockedByFriends list
                    if self.blockedByFriends.contains(uid) {
                        self.showFlashMessage("You are blocked by this user.")
                        self.resetUIForNewEntry()
                        return
                    }

                    self.friendAuthUIDToConfirm = uid
                    self.friendNameLabel.text = "Friend's Name: \(name)"
                    self.confirmButton.isHidden = false
                } else {
                    self.showFlashMessage("User not found with this Friend ID.")
                    self.resetUIForNewEntry()
                }
            }
        }
        return true
    }
}
