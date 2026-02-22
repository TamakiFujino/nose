import UIKit
import FirebaseAuth

// MARK: - PlaceTableViewCellDelegate

extension CollectionPlacesViewController: PlaceTableViewCellDelegate {
    func placeTableViewCell(_ cell: PlaceTableViewCell, didTapHeart placeId: String, isHearted: Bool) {
        toggleHeart(for: placeId, isHearted: isHearted)
    }
}

// MARK: - EditCollectionModalViewControllerDelegate

extension CollectionPlacesViewController: EditCollectionModalViewControllerDelegate {
    func editCollectionModalViewController(_ controller: EditCollectionModalViewController, didUpdateCollection collection: PlaceCollection) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.fetchCollectionData(userId: currentUserId, collectionId: collection.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                if let name = data["name"] as? String {
                    self.titleLabel.text = name
                }
                if let iconUrl = data["iconUrl"] as? String, !iconUrl.isEmpty {
                    self.currentIconUrl = iconUrl
                    self.currentIconName = nil
                } else if let iconName = data["iconName"] as? String, !iconName.isEmpty {
                    self.currentIconName = iconName
                    self.currentIconUrl = nil
                }
                self.updateCollectionIconDisplay()
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                ToastManager.showToast(message: "Collection updated", type: .success)
            case .failure(let error):
                Logger.log("Error fetching updated collection: \(error.localizedDescription)", level: .error, category: "Collection")
            }
        }
    }
}

// MARK: - ShareCollectionViewControllerDelegate

extension CollectionPlacesViewController: ShareCollectionViewControllerDelegate {
    func shareCollectionViewController(_ controller: ShareCollectionViewController, didSelectFriends friends: [User]) {
        LoadingView.shared.showOverlayLoading(on: view, message: "Sharing Collection...")

        CollectionContainerManager.shared.shareCollection(collection, with: friends) { [weak self] error in
            DispatchQueue.main.async {
                LoadingView.shared.hideOverlayLoading()

                if let error = error {
                    Logger.log("Error sharing collection: \(error.localizedDescription)", level: .error, category: "Collection")
                    ToastManager.showToast(message: "Failed to share collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection shared successfully", type: .success)
                    self?.loadSharedFriendsCount()
                }
            }
        }
    }
}
