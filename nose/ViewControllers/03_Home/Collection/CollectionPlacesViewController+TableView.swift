import UIKit
import FirebaseAuth

// MARK: - UITableViewDelegate & UITableViewDataSource

extension CollectionPlacesViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        switch selectedTab {
        case .places:
            return 1
        case .events:
            let hasFutureEvents = !futureEvents.isEmpty
            let hasPastEvents = !pastEvents.isEmpty
            if hasFutureEvents && hasPastEvents {
                return 2
            } else if hasFutureEvents || hasPastEvents {
                return 1
            }
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch selectedTab {
        case .places:
            return nil
        case .events:
            let hasFutureEvents = !futureEvents.isEmpty
            let hasPastEvents = !pastEvents.isEmpty

            if hasFutureEvents && hasPastEvents {
                return section == 0 ? "Upcoming Events" : "Past Events"
            } else if hasFutureEvents {
                return "Upcoming Events"
            } else if hasPastEvents {
                return "Past Events"
            }
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if selectedTab == .places {
            return 0
        }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch selectedTab {
        case .places:
            return places.count
        case .events:
            let hasFutureEvents = !futureEvents.isEmpty
            let hasPastEvents = !pastEvents.isEmpty

            if hasFutureEvents && hasPastEvents {
                return section == 0 ? futureEvents.count : pastEvents.count
            } else if hasFutureEvents {
                return futureEvents.count
            } else if hasPastEvents {
                return pastEvents.count
            }
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch selectedTab {
        case .places:
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
            let place = places[indexPath.row]

            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            let canHeart = collectionMembers.contains(currentUserId)

            let heartedUserIds = placeHearts[place.placeId] ?? []
            let isHearted = heartedUserIds.contains(currentUserId)
            let heartCount = heartedUserIds.count

            cell.configure(with: place, isHearted: isHearted, heartCount: heartCount, showHeartButton: canHeart)
            cell.delegate = self
            return cell

        case .events:
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell

            let hasFutureEvents = !futureEvents.isEmpty
            let event: Event
            if hasFutureEvents && indexPath.section == 0 {
                event = futureEvents[indexPath.row]
            } else {
                event = pastEvents[indexPath.row]
            }

            cell.configureWithEvent(event)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch selectedTab {
        case .places:
            let place = places[indexPath.row]

            if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: place.placeId) {
                let detailVC = PlaceDetailViewController(place: cachedPlace, isFromCollection: true)
                present(detailVC, animated: true)
                return
            }

            PlacesAPIManager.shared.fetchCollectionPlaceDetails(placeID: place.placeId) { [weak self] fetchedPlace in
                if let fetchedPlace = fetchedPlace {
                    DispatchQueue.main.async {
                        let detailVC = PlaceDetailViewController(place: fetchedPlace, isFromCollection: true)
                        self?.present(detailVC, animated: true)
                    }
                } else {
                    DispatchQueue.main.async {
                        let messageModal = MessageModalViewController(
                            title: "Unable to Load Details",
                            message: "Could not load complete details for \(place.name). Please try again later."
                        )
                        self?.present(messageModal, animated: true)
                    }
                }
            }

        case .events:
            let hasFutureEvents = !futureEvents.isEmpty
            let event: Event
            if hasFutureEvents && indexPath.section == 0 {
                event = futureEvents[indexPath.row]
            } else {
                event = pastEvents[indexPath.row]
            }
            let detailVC = EventDetailViewController(event: event)
            present(detailVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard selectedTab == .places, indexPath.row < places.count else { return }
        let place = places[indexPath.row]
        if let cachedPlace = PlacesCacheManager.shared.getCachedPlace(for: place.placeId) {
            openPlaceInMapsByName(cachedPlace.name ?? place.name)
        } else {
            openPlaceInMapsByName(place.name)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Handle events section
        if indexPath.section == 0 {
            guard indexPath.row < events.count else {
                return UISwipeActionsConfiguration(actions: [])
            }

            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
                self?.confirmDeleteEvent(at: indexPath)
                completion(false)
            }
            deleteAction.backgroundColor = .fourthColor
            deleteAction.image = UIImage(systemName: "trash")

            return UISwipeActionsConfiguration(actions: [deleteAction])
        }

        // Handle places section
        guard indexPath.row < places.count else {
            return UISwipeActionsConfiguration(actions: [])
        }

        let place = places[indexPath.row]

        let mapAction = UIContextualAction(style: .normal, title: "Map") { [weak self] (action, view, completion) in
            self?.openPlaceInMapsByName(place.name)
            completion(true)
        }
        mapAction.backgroundColor = .systemGreen
        mapAction.image = UIImage(systemName: "map")

        let visitedAction = UIContextualAction(style: .normal, title: place.visited ? "Unvisited" : "Visited") { [weak self] (action, view, completion) in
            self?.toggleVisitedStatus(at: indexPath)
            completion(true)
        }
        visitedAction.backgroundColor = UIColor.blueColor
        visitedAction.image = UIImage(systemName: place.visited ? "xmark.circle" : "checkmark.circle")

        let copyAction = UIContextualAction(style: .normal, title: "Copy") { [weak self] (action, view, completion) in
            self?.showCopyOptions(for: place, at: indexPath)
            completion(true)
        }
        copyAction.backgroundColor = .systemOrange
        copyAction.image = UIImage(systemName: "doc.on.doc")

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            self?.confirmDeletePlace(at: indexPath)
            completion(false)
        }
        deleteAction.backgroundColor = .fourthColor
        deleteAction.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [deleteAction, copyAction, visitedAction, mapAction])
    }
}
