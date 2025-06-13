import UIKit
import FirebaseAuth
import FirebaseFirestore

final class AddFriendViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let buttonHeight: CGFloat = 50
        static let cornerRadius: CGFloat = 10
    }
    
    // MARK: - Properties
    private var currentUser: User?
    
    // MARK: - UI Components
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Enter User ID"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = .label
        return searchBar
    }()
    
    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Add Friend", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = Constants.cornerRadius
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var messageView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = Constants.cornerRadius
        view.alpha = 0
        return view
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .label
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentUser()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .firstColor
        title = "Add Friend"
        navigationController?.navigationBar.tintColor = .label
        navigationItem.largeTitleDisplayMode = .never
        
        setupSubviews()
        setupConstraints()
    }
    
    private func setupSubviews() {
        [searchBar, addButton, messageView].forEach {
            view.addSubview($0)
        }
        messageView.addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.standardPadding),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            
            addButton.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: Constants.standardPadding),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            addButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight),
            
            messageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            messageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            
            messageLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: Constants.standardPadding),
            messageLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: Constants.standardPadding),
            messageLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -Constants.standardPadding),
            messageLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -Constants.standardPadding)
        ])
    }
    
    // MARK: - Data Loading
    private func loadCurrentUser() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        UserManager.shared.getUser(id: currentUserId) { [weak self] user, error in
            if let error = error {
                self?.handleSearchError(error)
                return
            }
            
            self?.currentUser = user
        }
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        guard let userId = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else {
            showMessage(title: "Error", subtitle: "Please enter a User ID")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            showMessage(title: "Error", subtitle: "Please sign in to add friends")
            return
        }
        
        // First check if the user exists
        UserManager.shared.getUser(id: userId) { [weak self] user, error in
            if let error = error {
                self?.handleSearchError(error)
                return
            }
            
            guard let user = user else {
                self?.showMessage(title: "Error", subtitle: "User not found")
                return
            }
            
            // Add friend
            UserManager.shared.addFriend(currentUserId: currentUserId, friendId: userId) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self?.showMessage(title: "Success", subtitle: "Friend added successfully")
                        self?.searchBar.text = ""
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.handleSearchError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleSearchError(_ error: Error) {
        let message: String
        if let nsError = error as NSError? {
            switch nsError.code {
            case 1:
                message = "User is blocked"
            case 2:
                message = "User not found"
            default:
                message = error.localizedDescription
            }
        } else {
            message = error.localizedDescription
        }
        showMessage(title: "Error", subtitle: message)
    }
    
    private func showMessage(title: String, subtitle: String) {
        messageLabel.text = "\(title)\n\(subtitle)"
        
        UIView.animate(withDuration: 0.3, animations: {
            self.messageView.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                UIView.animate(withDuration: 0.3) {
                    self.messageView.alpha = 0
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension AddFriendViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        addButtonTapped()
    }
}
