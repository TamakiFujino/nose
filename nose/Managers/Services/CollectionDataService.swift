import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import UIKit

/// Service for Firestore operations related to collection places, hearts, events, and members.
/// Extracts data access from CollectionPlacesViewController.
final class CollectionDataService {
    static let shared = CollectionDataService()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Collection Document

    /// Reload a collection document to get latest places.
    func fetchCollection(
        userId: String,
        collectionId: String,
        completion: @escaping (Result<PlaceCollection, Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId, db: db)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = snapshot?.data(),
                      let collection = PlaceCollection(dictionary: data) else {
                    completion(.failure(CollectionDataError.notFound))
                    return
                }
                completion(.success(collection))
            }
    }

    /// Fetch raw collection document data.
    func fetchCollectionData(
        userId: String,
        collectionId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId, db: db)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = snapshot?.data() else {
                    completion(.failure(CollectionDataError.notFound))
                    return
                }
                completion(.success(data))
            }
    }

    // MARK: - Hearts

    /// Load place hearts and members from the owner's collection (single source of truth).
    func loadPlaceHearts(
        ownerId: String,
        collectionId: String,
        completion: @escaping (Result<(hearts: [String: [String]], members: [String]), Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = snapshot?.data() else {
                    completion(.success((hearts: [:], members: [])))
                    return
                }

                let hearts = data["placeHearts"] as? [String: [String]] ?? [:]
                let members = data["members"] as? [String] ?? [ownerId]
                completion(.success((hearts: hearts, members: members)))
            }
    }

    /// Batch write pending heart changes to both user's and owner's collection documents.
    func flushHeartChanges(
        pendingChanges: [String: [String]],
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard !pendingChanges.isEmpty else {
            completion(nil)
            return
        }

        let userRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        let ownerRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

        var updateData: [String: Any] = [:]
        for (placeId, hearts) in pendingChanges {
            updateData["placeHearts.\(placeId)"] = hearts.isEmpty ? FieldValue.delete() : hearts
        }

        let batch = db.batch()
        batch.updateData(updateData, forDocument: userRef)
        batch.updateData(updateData, forDocument: ownerRef)

        batch.commit { error in
            completion(error)
        }
    }

    // MARK: - Events

    /// Load and verify events from a collection, checking each event still exists and is active.
    func loadEvents(
        userId: String,
        collectionId: String,
        completion: @escaping (Result<(events: [Event], rawCount: Int), Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId, db: db)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = snapshot?.data(),
                      let eventsArray = data["events"] as? [[String: Any]] else {
                    completion(.success((events: [], rawCount: 0)))
                    return
                }

                self.verifyEvents(eventsArray: eventsArray) { loadedEvents in
                    completion(.success((events: loadedEvents, rawCount: eventsArray.count)))
                }
            }
    }

    /// Verify each event still exists and is active, loading images for the first available URL.
    private func verifyEvents(
        eventsArray: [[String: Any]],
        completion: @escaping ([Event]) -> Void
    ) {
        let group = DispatchGroup()
        var loadedEvents: [Event] = []
        let appendQueue = DispatchQueue(label: "com.nose.collection.loadedEventsAppend")

        for eventDict in eventsArray {
            guard let eventId = eventDict["eventId"] as? String,
                  let title = eventDict["title"] as? String,
                  let startTimestamp = eventDict["startDate"] as? Timestamp,
                  let endTimestamp = eventDict["endDate"] as? Timestamp,
                  let locationName = eventDict["locationName"] as? String,
                  let locationAddress = eventDict["locationAddress"] as? String,
                  let userId = eventDict["userId"] as? String else {
                Logger.log("Skipping event with incomplete data", level: .warn, category: "CollectionData")
                continue
            }

            let latitude = eventDict["latitude"] as? Double ?? 0.0
            let longitude = eventDict["longitude"] as? Double ?? 0.0
            let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            group.enter()
            FirestorePaths.eventDoc(userId: userId, eventId: eventId, db: db)
                .getDocument { eventSnapshot, _ in
                    guard let eventData = eventSnapshot?.data(),
                          let status = eventData["status"] as? String,
                          status == "active" else {
                        group.leave()
                        return
                    }

                    let details = eventData["details"] as? String ?? ""
                    let createdAtTimestamp = eventData["createdAt"] as? Timestamp ?? Timestamp(date: Date())

                    let completeAndAppend: ([UIImage]) -> Void = { images in
                        let eventDateTime = EventDateTime(
                            startDate: startTimestamp.dateValue(),
                            endDate: endTimestamp.dateValue()
                        )
                        let eventLocation = EventLocation(
                            name: locationName,
                            address: locationAddress,
                            coordinates: coordinates
                        )
                        let event = Event(
                            id: eventId,
                            title: title,
                            dateTime: eventDateTime,
                            location: eventLocation,
                            details: details,
                            images: images,
                            createdAt: createdAtTimestamp.dateValue(),
                            userId: userId
                        )
                        appendQueue.async {
                            loadedEvents.append(event)
                            group.leave()
                        }
                    }

                    if let imageURLs = eventData["imageURLs"] as? [String],
                       let firstImageURL = imageURLs.first,
                       !firstImageURL.isEmpty,
                       let url = URL(string: firstImageURL) {
                        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, _ in
                            if let data = data, let image = UIImage(data: data) {
                                completeAndAppend([image])
                            } else {
                                completeAndAppend([])
                            }
                        }.resume()
                    } else {
                        completeAndAppend([])
                    }
                }
        }

        group.notify(queue: .main) {
            completion(loadedEvents)
        }
    }

    /// Remove stale events from both user's and owner's collection documents.
    func cleanupDeletedEvents(
        activeEventIds: Set<String>,
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let userRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        let ownerRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let data = snapshot?.data(),
                  let eventsArray = data["events"] as? [[String: Any]] else {
                completion?(nil)
                return
            }

            let cleanedEvents = eventsArray.filter { eventDict in
                guard let eventId = eventDict["eventId"] as? String else { return false }
                return activeEventIds.contains(eventId)
            }

            guard cleanedEvents.count != eventsArray.count else {
                completion?(nil)
                return
            }

            let batch = self.db.batch()
            batch.updateData(["events": cleanedEvents], forDocument: userRef)
            batch.updateData(["events": cleanedEvents], forDocument: ownerRef)

            batch.commit { error in
                if let error = error {
                    Logger.log("Error cleaning up deleted events: \(error.localizedDescription)", level: .error, category: "CollectionData")
                }
                completion?(error)
            }
        }
    }

    /// Remove a specific event from both user's and owner's collection documents.
    func deleteEvent(
        eventId: String,
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: @escaping (Error?) -> Void
    ) {
        let userRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        let ownerRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                completion(error)
                return
            }
            guard let data = snapshot?.data(),
                  var eventsArray = data["events"] as? [[String: Any]] else {
                completion(CollectionDataError.noEventsArray)
                return
            }

            eventsArray.removeAll { ($0["eventId"] as? String) == eventId }

            let batch = self.db.batch()
            batch.updateData(["events": eventsArray], forDocument: userRef)
            batch.updateData(["events": eventsArray], forDocument: ownerRef)

            batch.commit { error in
                completion(error)
            }
        }
    }

    // MARK: - Shared Friends Count

    /// Load the number of active (non-blocked) members for a collection.
    func loadSharedFriendsCount(
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        FirestorePaths.blocked(userId: currentUserId, db: db)
            .getDocuments { [weak self] blockedSnapshot, blockedError in
                guard let self = self else { return }
                if let blockedError = blockedError {
                    completion(.failure(blockedError))
                    return
                }

                let blockedUserIds = blockedSnapshot?.documents.map { $0.documentID } ?? []
                let collectionRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

                collectionRef.getDocument { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    if let members = snapshot?.data()?["members"] as? [String] {
                        let activeMembers = members.filter { !blockedUserIds.contains($0) }
                        completion(.success(activeMembers.count))
                    } else {
                        completion(.success(0))
                    }
                }
            }
    }

    // MARK: - Collection Icon

    /// Update the collection icon on both user's and owner's collection documents.
    func updateCollectionIcon(
        iconName: String?,
        iconUrl: String?,
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: @escaping (Error?) -> Void
    ) {
        let userRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        let ownerRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

        var updateData: [String: Any] = [:]

        if let iconUrl = iconUrl, !iconUrl.isEmpty {
            updateData["iconUrl"] = iconUrl
            updateData["iconName"] = FieldValue.delete()
        } else if let iconName = iconName, !iconName.isEmpty {
            updateData["iconName"] = iconName
            updateData["iconUrl"] = FieldValue.delete()
        }

        guard !updateData.isEmpty else {
            completion(nil)
            return
        }

        let batch = db.batch()
        batch.updateData(updateData, forDocument: userRef)
        batch.updateData(updateData, forDocument: ownerRef)

        batch.commit { error in
            completion(error)
        }
    }

    // MARK: - Leave Collection

    /// Delete the current user's copy of a shared collection.
    func leaveCollection(
        currentUserId: String,
        collectionId: String,
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
            .delete { error in
                completion(error)
            }
    }

    // MARK: - Avatar Thumbnails

    /// Fetch avatar thumbnail URL for a collection.
    func fetchAvatarThumbnailURL(
        ownerId: String,
        collectionId: String,
        completion: @escaping (Result<(url: String, timestamp: Timestamp?)?, Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = snapshot?.data(),
                      let urlString = data["avatarThumbnailURL"] as? String else {
                    completion(.success(nil))
                    return
                }
                let timestamp = data["avatarThumbnailUpdatedAt"] as? Timestamp
                completion(.success((url: urlString, timestamp: timestamp)))
            }
    }

    /// Fetch members list from a collection and return ordered user IDs (owner first).
    func fetchOrderedMembers(
        ownerId: String,
        collectionId: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                var orderedIds: [String] = []
                var seen = Set<String>()

                if !ownerId.isEmpty {
                    orderedIds.append(ownerId)
                    seen.insert(ownerId)
                }

                if let members = snapshot?.data()?["members"] as? [String] {
                    for uid in members where !uid.isEmpty && !seen.contains(uid) {
                        orderedIds.append(uid)
                        seen.insert(uid)
                    }
                }

                completion(.success(orderedIds))
            }
    }

    // MARK: - Place Operations

    /// Toggle the visited status of a place in both user's and owner's collection documents.
    func toggleVisitedStatus(
        placeId: String,
        newVisitedStatus: Bool,
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: @escaping (Error?) -> Void
    ) {
        let userRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        let ownerRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                completion(error)
                return
            }
            guard let data = snapshot?.data(),
                  var places = data["places"] as? [[String: Any]] else {
                completion(CollectionDataError.noPlacesArray)
                return
            }

            guard let placeIndex = places.firstIndex(where: { ($0["placeId"] as? String) == placeId }) else {
                completion(CollectionDataError.placeNotFound)
                return
            }

            places[placeIndex]["visited"] = newVisitedStatus

            let batch = self.db.batch()
            batch.updateData(["places": places], forDocument: userRef)
            batch.updateData(["places": places], forDocument: ownerRef)

            batch.commit { error in
                completion(error)
            }
        }
    }

    /// Delete a place from both user's and owner's collection documents.
    func deletePlace(
        placeId: String,
        currentUserId: String,
        ownerId: String,
        collectionId: String,
        completion: @escaping (Error?) -> Void
    ) {
        let userRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: collectionId, db: db)
        let ownerRef = FirestorePaths.collectionDoc(userId: ownerId, collectionId: collectionId, db: db)

        userRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                completion(error)
                return
            }
            guard let data = snapshot?.data(),
                  var places = data["places"] as? [[String: Any]] else {
                completion(CollectionDataError.noPlacesArray)
                return
            }

            places.removeAll { ($0["placeId"] as? String) == placeId }

            let batch = self.db.batch()
            batch.updateData(["places": places], forDocument: userRef)
            batch.updateData(["places": places], forDocument: ownerRef)

            batch.commit { error in
                completion(error)
            }
        }
    }

    // MARK: - Copy Place

    /// Load all active collections for a user (excluding a specific collection).
    func loadOtherCollections(
        userId: String,
        excludingCollectionId: String,
        completion: @escaping (Result<[(id: String, name: String)], Error>) -> Void
    ) {
        FirestorePaths.collections(userId: userId, db: db)
            .whereField("status", isEqualTo: "active")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let collections = (snapshot?.documents ?? []).compactMap { doc -> (id: String, name: String)? in
                    let data = doc.data()
                    guard doc.documentID != excludingCollectionId,
                          let name = data["name"] as? String else {
                        return nil
                    }
                    return (id: doc.documentID, name: name)
                }
                completion(.success(collections))
            }
    }

    /// Copy a place from a source collection to a target collection.
    func copyPlace(
        place: PlaceCollection.Place,
        sourceOwnerId: String,
        sourceCollectionId: String,
        targetCollectionId: String,
        currentUserId: String,
        completion: @escaping (Error?) -> Void
    ) {
        let sourceRef: DocumentReference
        if sourceOwnerId != currentUserId {
            sourceRef = FirestorePaths.collectionDoc(userId: sourceOwnerId, collectionId: sourceCollectionId, db: db)
        } else {
            sourceRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: sourceCollectionId, db: db)
        }

        let targetUserRef = FirestorePaths.collectionDoc(userId: currentUserId, collectionId: targetCollectionId, db: db)

        // Step 1: Get place data from source
        sourceRef.getDocument { [weak self] sourceSnapshot, error in
            guard let self = self else { return }

            guard error == nil,
                  let sourceData = sourceSnapshot?.data(),
                  let placesArray = sourceData["places"] as? [[String: Any]],
                  let placeIndex = placesArray.firstIndex(where: { ($0["placeId"] as? String) == place.placeId }),
                  let placeId = placesArray[placeIndex]["placeId"] as? String,
                  let name = placesArray[placeIndex]["name"] as? String else {
                completion(CollectionDataError.placeNotFound)
                return
            }

            let cleanPlaceData = self.preparePlaceDataForCopy(
                from: placesArray[placeIndex],
                placeId: placeId,
                name: name
            )

            // Step 2: Copy to target
            self.copyPlaceToTarget(
                placeData: cleanPlaceData,
                placeId: placeId,
                targetUserRef: targetUserRef,
                toCollectionId: targetCollectionId,
                currentUserId: currentUserId,
                completion: completion
            )
        }
    }

    /// Prepare place data for copying with correct types.
    private func preparePlaceDataForCopy(from placeData: [String: Any], placeId: String, name: String) -> [String: Any] {
        func toDouble(_ value: Any?) -> Double {
            if let val = value as? Double { return val }
            if let val = value as? Float { return Double(val) }
            if let val = value as? Int { return Double(val) }
            return 0.0
        }

        func toFloat(_ value: Any?) -> Float {
            if let val = value as? Float { return val }
            if let val = value as? Double { return Float(val) }
            if let val = value as? String, let floatVal = Float(val) { return floatVal }
            return 0.0
        }

        return [
            "placeId": placeId,
            "name": name,
            "formattedAddress": placeData["formattedAddress"] as? String ?? "",
            "phoneNumber": placeData["phoneNumber"] as? String ?? "",
            "rating": toFloat(placeData["rating"]),
            "latitude": toDouble(placeData["latitude"]),
            "longitude": toDouble(placeData["longitude"]),
            "visited": placeData["visited"] as? Bool ?? false,
            "addedAt": Timestamp()
        ]
    }

    /// Copy place to the target collection, handling both owned and shared targets.
    private func copyPlaceToTarget(
        placeData: [String: Any],
        placeId: String,
        targetUserRef: DocumentReference,
        toCollectionId: String,
        currentUserId: String,
        completion: @escaping (Error?) -> Void
    ) {
        targetUserRef.getDocument { [weak self] targetSnapshot, error in
            guard let self = self else { return }

            guard error == nil,
                  targetSnapshot?.exists == true,
                  let targetData = targetSnapshot?.data() else {
                completion(CollectionDataError.notFound)
                return
            }

            let targetOwnerId = targetData["userId"] as? String ?? currentUserId
            let isTargetShared = targetOwnerId != currentUserId

            let targetRefToUpdate = isTargetShared ?
                FirestorePaths.collectionDoc(userId: targetOwnerId, collectionId: toCollectionId, db: self.db) :
                targetUserRef

            if isTargetShared {
                targetRefToUpdate.getDocument { [weak self] ownerSnapshot, error in
                    guard let self = self else { return }
                    guard error == nil, ownerSnapshot?.exists == true else {
                        completion(CollectionDataError.notFound)
                        return
                    }
                    self.performCopyWrite(placeData: placeData, targetRef: targetRefToUpdate, userCopyRef: targetUserRef, completion: completion)
                }
            } else {
                let targetPlaces = targetData["places"] as? [[String: Any]] ?? []
                if targetPlaces.contains(where: { ($0["placeId"] as? String) == placeId }) {
                    completion(CollectionDataError.duplicatePlace)
                    return
                }

                var updatedPlaces = targetPlaces
                updatedPlaces.append(placeData)

                let batch = self.db.batch()
                batch.updateData(["places": updatedPlaces], forDocument: targetRefToUpdate)

                batch.commit { error in
                    completion(error)
                }
            }
        }
    }

    /// Perform the array union copy write to both target and user copy refs.
    private func performCopyWrite(
        placeData: [String: Any],
        targetRef: DocumentReference,
        userCopyRef: DocumentReference,
        completion: @escaping (Error?) -> Void
    ) {
        let batch = db.batch()
        batch.updateData(["places": FieldValue.arrayUnion([placeData])], forDocument: targetRef)
        batch.updateData(["places": FieldValue.arrayUnion([placeData])], forDocument: userCopyRef)

        batch.commit { error in
            completion(error)
        }
    }

    // MARK: - Avatar Data

    func fetchAvatarSelections(
        userId: String,
        collectionId: String,
        completion: @escaping (Result<[String: [String: String]]?, Error>) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = snapshot?.data(),
                  let avatarData = data["avatarData"] as? [String: Any],
                  let selections = avatarData["selections"] as? [String: [String: String]] else {
                completion(.success(nil))
                return
            }
            completion(.success(selections))
        }
    }

    func updateAvatarThumbnailURL(
        userId: String,
        collectionId: String,
        url: String,
        completion: @escaping (Error?) -> Void
    ) {
        FirestorePaths.collectionDoc(userId: userId, collectionId: collectionId).setData([
            "avatarThumbnailURL": url,
            "avatarThumbnailUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true, completion: completion)
    }

    // MARK: - Error Types

    enum CollectionDataError: LocalizedError {
        case notFound
        case noEventsArray
        case noPlacesArray
        case placeNotFound
        case duplicatePlace

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Collection not found"
            case .noEventsArray:
                return "No events array found in collection"
            case .noPlacesArray:
                return "No places array found in collection"
            case .placeNotFound:
                return "Place not found in collection"
            case .duplicatePlace:
                return "Place already exists in target collection"
            }
        }
    }
}
