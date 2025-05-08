import UIKit
import RealityKit

struct FriendAvatar {
    let id: String
    let name: String
    let modelName: String // e.g., "robot", "astronaut"
}

protocol POIsViewControllerDelegate: AnyObject {
    func didDeleteBookmarkList()
    func didCompleteBookmarkList(_ bookmarkList: BookmarkList)
    func centerMapOnPOI(latitude: Double, longitude: Double)
    func didUpdateSharedFriends(for bookmarkList: BookmarkList)
}

class POIsViewController: UIViewController {

    // MARK: - Properties
    var tableView: UITableView!
    var bookmarkList: BookmarkList!
    var sharedWithCount: Int = 0
    var loggedInUser: String = "defaultUser"
    weak var delegate: POIsViewControllerDelegate?
    var infoLabel: UILabel!
    var isFromPastMap: Bool = false
    var scrollView: UIScrollView!
    var arView: ARView!
    var stackView: UIStackView!
    
    // temporary friend avatar
    let mockFriends: [FriendAvatar] = [
            FriendAvatar(id: "123456789", name: "Taro Yamada", modelName: "body"),
            FriendAvatar(id: "987654321", name: "Ichiro Suzuki", modelName: "body"),
            FriendAvatar(id: "111111111", name: "Ken Sato", modelName: "body")
        ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        setupInfoLabel()
        setupScrollViewAndStack()
        setupARView()
        setupTableView()
        setupConstraints()
        
        let key = "sharedFriends_\(bookmarkList.id)"
        if let savedFriends = UserDefaults.standard.array(forKey: key) as? [String] {
            sharedWithCount = savedFriends.count
        }
        
        let sharedIDs = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        // let sharedFriends = mockFriends.filter { sharedIDs.contains($0.id) }

//        for (index, friend) in sharedFriends.enumerated() {
//            loadAvatar(for: friend, index: index)
//        }

        updateInfoLabel()
        loadAvatarModel()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.didUpdateSharedFriends(for: self.bookmarkList)
    }

// MARK: - Setup Methods
    private func setupView() {
        view.backgroundColor = .white
        title = bookmarkList.name
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(dismissModal)
        )
        navigationController?.navigationBar.tintColor = .black

        if !isFromPastMap {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis"),
                style: .plain,
                target: self,
                action: #selector(showMenu)
            )
        }
    }

    private func setupInfoLabel() {
        infoLabel = UILabel()
        infoLabel.font = UIFont.systemFont(ofSize: 16)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        updateInfoLabel()
    }

    private func setupScrollViewAndStack() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
    }

    private func setupARView() {
        arView = ARView(frame: .zero)
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(arViewTapped)))
        stackView.addArrangedSubview(arView)
        arView.environment.background = .color(.firstColor)
    }

    private func setupTableView() {
        tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(POICell.self, forCellReuseIdentifier: "POICell")
        stackView.addArrangedSubview(tableView)
        tableView.heightAnchor.constraint(equalToConstant: 400).isActive = true
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            arView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }

    private func loadAvatarModel() {
            arView.scene.anchors.removeAll()

            if let outfit = bookmarkList?.associatedOutfit {
                let entity = Entity()
                let builder = AvatarBuilder()
                builder.buildAvatar(from: outfit, into: entity)
                entity.scale = SIMD3<Float>(repeating: 0.5)
                let anchor = AnchorEntity(world: [0, 0, -0.5])
                anchor.addChild(entity)
                arView.scene.anchors.append(anchor)
            }

            if let bookmarkList = bookmarkList {
                let key = "sharedFriends_\(bookmarkList.id)"
                let sharedIDs = UserDefaults.standard.array(forKey: key) as? [String] ?? []

                for (i, friendId) in sharedIDs.enumerated() {
                    if let friendAvatar = AvatarBuilder.buildAvatar(for: friendId) {
                        let anchor = AnchorEntity(world: [Float(i + 1) * 0.4, 0, -0.5])
                        friendAvatar.scale = SIMD3<Float>(repeating: 0.5)
                        anchor.addChild(friendAvatar)
                        arView.scene.anchors.append(anchor)
                    }
                }
            }
        }
    
    private func loadAvatar(for friend: FriendAvatar, index: Int) {
        Task {
            do {
                let entity = try await Entity.load(named: friend.modelName)
                print("✅ Loaded entity: \(entity.name), type: \(type(of: entity))")

                // Recursively apply scale to all ModelEntities inside
                applyFixedScale(to: entity, scale: 0.5)

                let anchor = AnchorEntity(world: [Float(index) * 0.4, 0, -0.5])
                anchor.addChild(entity)
                arView.scene.addAnchor(anchor)

            } catch {
                print("❌ Failed to load avatar for \(friend.name): \(error)")
            }
        }
    }
    
    private func applyFixedScale(to entity: Entity, scale: Float) {
        if let model = entity as? ModelEntity {
            model.scale = SIMD3<Float>(repeating: scale)
        }
        for child in entity.children {
            applyFixedScale(to: child, scale: scale)
        }
    }

    // MARK: - Actions
    @objc private func dismissModal() {
        dismiss(animated: true)
    }

    @objc private func showMenu() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // share
        alertController.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            let shareVC = ShareModalViewController()
            shareVC.bookmarkList = self.bookmarkList
            shareVC.modalPresentationStyle = .pageSheet
            shareVC.onSharingConfirmed = { sharedCount in
                self.sharedWithCount = sharedCount
                self.updateInfoLabel()
            }
            if let sheet = shareVC.sheetPresentationController {
                sheet.detents = [.medium()]
            }
            self.present(shareVC, animated: true)
        })

        // complete collection
        alertController.addAction(UIAlertAction(title: "Complete collection", style: .default) { _ in
            self.completeCollection()
            ToastManager.showToast(message: ToastMessages.completedCollection, type: .success)
        })

        // delete collection
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.showDeleteWarning()
        })

        // cancel
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alertController, animated: true)
    }

    @objc private func arViewTapped() {
        let avatarCustomVC = AvatarCustomViewController()
        avatarCustomVC.selectedBookmarkList = bookmarkList

        let navController = UINavigationController(rootViewController: avatarCustomVC)
        navController.modalPresentationStyle = .fullScreen

        avatarCustomVC.avatar3DViewController?.onDismiss = { [weak self] in
            self?.arView.scene.anchors.removeAll()
            self?.loadAvatarModel()
        }

        present(navController, animated: true)
    }

    private func showDeleteWarning() {
        let alert = UIAlertController(
            title: "Warning",
            message: "Are you sure you want to delete this bookmark list? This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteBookmarkList()
            ToastManager.showToast(message: ToastMessages.collectionDeleted, type: .success)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func deleteBookmarkList() {
        BookmarksManager.shared.deleteBookmarkList(bookmarkList)
        delegate?.didDeleteBookmarkList()
        dismiss(animated: true)
    }

    private func completeCollection() {
        BookmarksManager.shared.completeBookmarkList(bookmarkList)
        delegate?.didCompleteBookmarkList(bookmarkList)
        dismiss(animated: true)
    }

    private func updateInfoLabel() {
        let iconSize = CGSize(width: 14, height: 14)
        let text = NSMutableAttributedString()

        func makeIconAttachment(systemName: String) -> NSTextAttachment {
            let image = UIImage(systemName: systemName)?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: iconSize).offsetBy(dx: 0, dy: -2)
            return attachment
        }

        text.append(NSAttributedString(attachment: makeIconAttachment(systemName: "bookmark.fill")))
        text.append(NSAttributedString(string: " \(bookmarkList.bookmarks.count)  ", attributes: [.font: UIFont.systemFont(ofSize: 14)]))
        text.append(NSAttributedString(attachment: makeIconAttachment(systemName: "person.fill")))
        text.append(NSAttributedString(string: " \(sharedWithCount)", attributes: [.font: UIFont.systemFont(ofSize: 14)]))
        text.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(location: 0, length: text.length))

        infoLabel.attributedText = text
    }
}

// MARK: - UITableViewDataSource & Delegate
extension POIsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        bookmarkList.bookmarks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "POICell", for: indexPath) as! POICell
        let poi = bookmarkList.bookmarks[indexPath.row]
        cell.poi = poi
        cell.checkbox.tag = indexPath.row
        cell.checkbox.addTarget(self, action: #selector(checkboxTapped(_:)), for: .touchUpInside)
        return cell
    }

    @objc private func checkboxTapped(_ sender: UIButton) {
        let index = sender.tag
        bookmarkList.bookmarks[index].visited.toggle()

        let isVisited = bookmarkList.bookmarks[index].visited
        sender.setImage(UIImage(systemName: isVisited ? "checkmark.circle.fill" : "circle"), for: .normal)
        sender.tintColor = .fourthColor

        if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? POICell {
            cell.contentView.backgroundColor = isVisited ? UIColor.fourthColor.withAlphaComponent(0.1) : .clear
        }

        BookmarksManager.shared.saveBookmarkList(bookmarkList)

        if isVisited {
            ToastManager.showToast(message: ToastMessages.markSpotVisited, type: .success)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let poi = bookmarkList.bookmarks[indexPath.row]

        let detailVC = POIDetailViewController()
        detailVC.placeID = poi.placeID
        detailVC.placeName = poi.name
        detailVC.address = poi.address
        detailVC.phoneNumber = poi.phoneNumber
        detailVC.website = poi.website
        detailVC.rating = poi.rating
        detailVC.openingHours = poi.openingHours
        detailVC.latitude = poi.latitude
        detailVC.longitude = poi.longitude
        detailVC.showBookmarkIcon = false

        BookmarksManager.shared.savePOI(for: loggedInUser, placeID: poi.placeID)
        delegate?.centerMapOnPOI(latitude: poi.latitude, longitude: poi.longitude)

        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium()]
        }

        present(detailVC, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let poi = bookmarkList.bookmarks[indexPath.row]
            BookmarksManager.shared.deletePOI(for: loggedInUser, placeID: poi.placeID)
            bookmarkList.bookmarks.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            BookmarksManager.shared.saveBookmarkList(bookmarkList)
            updateInfoLabel()
            ToastManager.showToast(message: ToastMessages.removeSpotFromCollection, type: .info)
        }
    }
}
