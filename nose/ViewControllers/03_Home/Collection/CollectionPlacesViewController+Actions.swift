import UIKit
import FirebaseAuth

// MARK: - Actions

extension CollectionPlacesViewController {

    @objc func menuButtonTapped() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if collection.isOwner {
            let editAction = UIAlertAction(title: "Edit Collection", style: .default) { [weak self] _ in
                self?.editCollection()
            }
            editAction.setValue(UIImage(systemName: "pencil"), forKey: "image")
            alertController.addAction(editAction)

            let shareAction = UIAlertAction(title: "Share with Friends", style: .default) { [weak self] _ in
                self?.shareCollection()
            }
            shareAction.setValue(UIImage(systemName: "square.and.arrow.up"), forKey: "image")
            alertController.addAction(shareAction)

            let shareLinkAction = UIAlertAction(title: "Share the link", style: .default) { [weak self] _ in
                self?.shareCollectionLink()
            }
            shareLinkAction.setValue(UIImage(systemName: "link"), forKey: "image")
            alertController.addAction(shareLinkAction)

            let deleteAction = UIAlertAction(title: "Delete Collection", style: .destructive) { [weak self] _ in
                self?.confirmDeleteCollection()
            }
            deleteAction.setValue(UIImage(systemName: "trash"), forKey: "image")
            alertController.addAction(deleteAction)
        } else {
            let leaveAction = UIAlertAction(title: "Leave this collection", style: .destructive) { [weak self] _ in
                self?.confirmLeaveCollection()
            }
            leaveAction.setValue(UIImage(systemName: "rectangle.portrait.and.arrow.right"), forKey: "image")
            alertController.addAction(leaveAction)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancelAction)

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = menuButton
            popoverController.sourceRect = menuButton.bounds
        }

        present(alertController, animated: true)
    }

    func editCollection() {
        let editModal = EditCollectionModalViewController(collection: collection)
        editModal.delegate = self
        editModal.modalPresentationStyle = .overFullScreen
        editModal.modalTransitionStyle = .crossDissolve
        present(editModal, animated: true)
    }

    @objc func avatarImageTapped() {
        let vc = ContentViewController(collection: collection)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
    }

    @objc func customizeAvatarTapped() {
        let vc = ContentViewController(collection: collection)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
    }

    func updateCollectionIcon(iconName: String?, iconUrl: String?) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let alert = UIAlertController(title: "Updating icon...", message: nil, preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true)

        CollectionDataService.shared.updateCollectionIcon(
            iconName: iconName,
            iconUrl: iconUrl,
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        ) { [weak self] error in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    guard let self = self else { return }
                    if let error = error {
                        Logger.log("Error updating collection icon: \(error.localizedDescription)", level: .error, category: "Collection")
                        ToastManager.showToast(message: "Failed to update icon", type: .error)
                    } else {
                        self.currentIconName = iconName
                        self.currentIconUrl = iconUrl
                        self.updateCollectionIconDisplay()
                        ToastManager.showToast(message: "Icon updated", type: .success)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
    }

    func shareCollection() {
        let shareVC = ShareCollectionViewController(collection: collection)
        shareVC.delegate = self
        let navController = UINavigationController(rootViewController: shareVC)
        present(navController, animated: true)
    }

    func shareCollectionLink() {
        let link = DeepLinkManager.generateCollectionLink(collectionId: collection.id, userId: collection.userId)
        let shareText = "Check out this collection: \(collection.name)\n\(link)"

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = menuButton
            popoverController.sourceRect = menuButton.bounds
        }

        present(activityVC, animated: true)
    }

    func confirmDeleteCollection() {
        let alertController = UIAlertController(
            title: "Delete Collection",
            message: "Are you sure you want to delete '\(collection.name)'? This action cannot be undone.",
            preferredStyle: .alert
        )

        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCollection()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    func deleteCollection() {
        showLoadingAlert(title: "Deleting Collection")

        CollectionContainerManager.shared.deleteCollection(collection) { [weak self] error in
            self?.dismiss(animated: true) {
                if error != nil {
                    ToastManager.showToast(message: "Failed to delete collection", type: .error)
                } else {
                    ToastManager.showToast(message: "Collection deleted", type: .success)
                    self?.dismiss(animated: true) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    }
                }
            }
        }
    }

    func confirmLeaveCollection() {
        let alertController = UIAlertController(
            title: "Leave Collection",
            message: "Are you sure you want to leave '\(collection.name)'? You can rejoin later if you have the link.",
            preferredStyle: .alert
        )

        let leaveAction = UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
            self?.leaveCollection()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(leaveAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    func leaveCollection() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.leaveCollection(currentUserId: currentUserId, collectionId: collection.id) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    Logger.log("Error leaving collection: \(error.localizedDescription)", level: .error, category: "Collection")
                    ToastManager.showToast(message: "Failed to leave collection", type: .error)
                } else {
                    Logger.log("Successfully left collection: \(self.collection.name)", level: .info, category: "Collection")
                    ToastManager.showToast(message: "You left the collection", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                    self.dismiss(animated: true)
                }
            }
        }
    }

    // MARK: - Place/Event Actions

    func confirmDeleteEvent(at indexPath: IndexPath) {
        guard indexPath.row < events.count else { return }
        let event = events[indexPath.row]
        let alertController = UIAlertController(
            title: "Remove Event",
            message: "Are you sure you want to remove '\(event.title)' from this collection?",
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let deleteAction = UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.deleteEvent(at: indexPath)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        present(alertController, animated: true)
    }

    func confirmDeletePlace(at indexPath: IndexPath) {
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        let alertController = UIAlertController(
            title: "Delete Place",
            message: "Are you sure you want to remove '\(place.name)' from this collection?",
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deletePlace(at: indexPath)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        present(alertController, animated: true)
    }

    func showCopyOptions(for place: PlaceCollection.Place, at indexPath: IndexPath) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            ToastManager.showToast(message: "Please sign in to move places", type: .error)
            return
        }

        CollectionDataService.shared.loadOtherCollections(userId: currentUserId, excludingCollectionId: collection.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let otherCollections):
                if otherCollections.isEmpty {
                    ToastManager.showToast(message: "No other collections to move to", type: .info)
                    return
                }
                DispatchQueue.main.async {
                    self.presentCopyActionSheet(for: place, at: indexPath, collections: otherCollections)
                }
            case .failure(let error):
                Logger.log("Error loading collections: \(error.localizedDescription)", level: .error, category: "Collection")
                ToastManager.showToast(message: "Failed to load collections", type: .error)
            }
        }
    }

    func presentCopyActionSheet(for place: PlaceCollection.Place, at indexPath: IndexPath, collections: [(id: String, name: String)]) {
        let actionSheet = UIAlertController(
            title: "Copy to Collection",
            message: "Select a collection to copy '\(place.name)' to:",
            preferredStyle: .actionSheet
        )

        for collection in collections {
            let action = UIAlertAction(title: collection.name, style: .default) { [weak self] _ in
                self?.confirmCopyPlace(place, at: indexPath, toCollection: collection)
            }
            actionSheet.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(cancelAction)

        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        present(actionSheet, animated: true)
    }

    func confirmCopyPlace(_ place: PlaceCollection.Place, at indexPath: IndexPath, toCollection targetCollection: (id: String, name: String)) {
        let alertController = UIAlertController(
            title: "Copy Place",
            message: "Copy '\(place.name)' to '\(targetCollection.name)'?",
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let copyAction = UIAlertAction(title: "Copy", style: .default) { [weak self] _ in
            self?.copyPlace(place, toCollectionId: targetCollection.id)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(copyAction)
        present(alertController, animated: true)
    }

    func copyPlace(_ place: PlaceCollection.Place, toCollectionId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        showLoadingAlert(title: "Copying place...")

        CollectionDataService.shared.copyPlace(
            place: place,
            sourceOwnerId: collection.userId,
            sourceCollectionId: collection.id,
            targetCollectionId: toCollectionId,
            currentUserId: currentUserId
        ) { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    if case CollectionDataService.CollectionDataError.duplicatePlace = error {
                        ToastManager.showToast(message: "Place already in collection", type: .info)
                    } else {
                        Logger.log("Error copying place: \(error.localizedDescription)", level: .error, category: "Collection")
                        ToastManager.showToast(message: "Failed to copy place", type: .error)
                    }
                } else {
                    ToastManager.showToast(message: "Place copied successfully", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
            }
        }
    }

    func deleteEvent(at indexPath: IndexPath) {
        guard indexPath.row < events.count else { return }
        let event = events[indexPath.row]
        showLoadingAlert(title: "Removing Event")

        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.deleteEvent(
            eventId: event.id,
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        ) { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    Logger.log("Error removing event: \(error.localizedDescription)", level: .error, category: "Collection")
                    ToastManager.showToast(message: "Failed to remove event", type: .error)
                } else {
                    self?.events.remove(at: indexPath.row)
                    self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self?.updatePlacesCountLabel()
                    ToastManager.showToast(message: "Event removed", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
            }
        }
    }

    func toggleVisitedStatus(at indexPath: IndexPath) {
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        let newVisitedStatus = !place.visited
        let actionTitle = newVisitedStatus ? "Marking as visited" : "Marking as unvisited"
        showLoadingAlert(title: actionTitle)

        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.toggleVisitedStatus(
            placeId: place.placeId,
            newVisitedStatus: newVisitedStatus,
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        ) { [weak self] error in
            LoadingView.shared.hideAlertLoading()
            guard let self = self else { return }
            if let error = error {
                Logger.log("Error updating place status: \(error.localizedDescription)", level: .error, category: "Collection")
                ToastManager.showToast(message: "Failed to update place status", type: .error)
            } else {
                self.places[indexPath.row].visited = newVisitedStatus
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                ToastManager.showToast(message: newVisitedStatus ? "Marked as visited" : "Marked as unvisited", type: .success)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
            }
        }
    }

    func deletePlace(at indexPath: IndexPath) {
        guard indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        showLoadingAlert(title: "Removing Place")

        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        CollectionDataService.shared.deletePlace(
            placeId: place.placeId,
            currentUserId: currentUserId,
            ownerId: collection.userId,
            collectionId: collection.id
        ) { [weak self] error in
            self?.dismiss(animated: true) {
                if let error = error {
                    Logger.log("Error removing place: \(error.localizedDescription)", level: .error, category: "Collection")
                    ToastManager.showToast(message: "Failed to remove place", type: .error)
                } else {
                    self?.places.remove(at: indexPath.row)
                    self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self?.updatePlacesCountLabel()
                    ToastManager.showToast(message: "Place removed", type: .success)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCollections"), object: nil)
                }
            }
        }
    }

    // MARK: - Maps Integration

    func openPlaceInMapsByName(_ name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name

        let sheet = UIAlertController(title: "Open in Maps", message: name, preferredStyle: .actionSheet)

        if let appleURL = URL(string: "maps://?q=\(encoded)") {
            sheet.addAction(UIAlertAction(title: "Apple Maps", style: .default, handler: { _ in
                UIApplication.shared.open(appleURL, options: [:]) { success in
                    if !success, let webURL = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                        UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                    }
                }
            }))
        }

        if let gmapsURL = URL(string: "comgooglemaps://?q=\(encoded)&zoom=16"), UIApplication.shared.canOpenURL(gmapsURL) {
            sheet.addAction(UIAlertAction(title: "Google Maps", style: .default, handler: { _ in
                UIApplication.shared.open(gmapsURL, options: [:], completionHandler: nil)
            }))
        }

        if let wazeURL = URL(string: "waze://?q=\(encoded)&navigate=yes"), UIApplication.shared.canOpenURL(wazeURL) {
            sheet.addAction(UIAlertAction(title: "Waze", style: .default, handler: { _ in
                UIApplication.shared.open(wazeURL, options: [:], completionHandler: nil)
            }))
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = sheet.popoverPresentationController {
            pop.sourceView = self.view
            pop.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    @objc func didTapMapAccessory(_ sender: UIButton) {
        let row = sender.tag
        guard row >= 0 && row < places.count else { return }
        let place = places[row]
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: place.placeId) {
            openPlaceInMapsByName(cachedPlace.name ?? place.name)
        } else {
            openPlaceInMapsByName(place.name)
        }
    }
}
