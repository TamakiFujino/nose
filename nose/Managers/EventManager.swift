import Foundation
import FirebaseFirestore
import FirebaseAuth
import Firebase
import FirebaseStorage
import CoreLocation

class EventManager {
    static let shared = EventManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}

    // MARK: - Helpers (centralize common Firestore payloads)
    private func buildLocationDict(for event: Event) -> [String: Any] {
        return [
            "name": event.location.name,
            "address": event.location.address,
            "latitude": event.location.coordinates?.latitude ?? 0.0,
            "longitude": event.location.coordinates?.longitude ?? 0.0
        ]
    }

    private func buildCreateEventData(
        event: Event,
        userId: String,
        eventId: String,
        imageURLs: [String],
        avatarData: CollectionAvatar.AvatarData?,
        avatarURL: String?
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": eventId,
            "title": event.title,
            "startDate": Timestamp(date: event.dateTime.startDate),
            "endDate": Timestamp(date: event.dateTime.endDate),
            "location": buildLocationDict(for: event),
            "details": event.details,
            "imageURLs": imageURLs,
            "createdAt": Timestamp(date: event.createdAt),
            "userId": userId,
            "status": "active",
            "version": 1
        ]
        if let avatarData = avatarData { data["avatarData"] = avatarData.toFirestoreDict() }
        if let avatarURL = avatarURL, !avatarURL.isEmpty { data["avatarImageURL"] = avatarURL }
        return data
    }

    private func buildUpdateEventData(
        event: Event,
        imageURLs: [String],
        avatarData: CollectionAvatar.AvatarData?,
        avatarURL: String?
    ) -> [String: Any] {
        var data: [String: Any] = [
            "title": event.title,
            "startDate": Timestamp(date: event.dateTime.startDate),
            "endDate": Timestamp(date: event.dateTime.endDate),
            "location": buildLocationDict(for: event),
            "details": event.details,
            "imageURLs": imageURLs,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let avatarData = avatarData { data["avatarData"] = avatarData.toFirestoreDict() }
        if let avatarURL = avatarURL, !avatarURL.isEmpty { data["avatarImageURL"] = avatarURL }
        return data
    }
    
    private func handleAuthError() -> NSError {
        return NSError(domain: "EventManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }
    
    // MARK: - Event Creation and Saving
    func createEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        let eventId = UUID().uuidString
        
        // First, upload event images to Firebase Storage
        uploadEventImages(event.images, eventId: eventId, userId: userId) { [weak self] result in
            switch result {
            case .success(let imageURLs):
                // Upload temporary avatar image if it exists
                self?.uploadTemporaryAvatarImage(eventId: eventId, userId: userId) { avatarResult in
                    // Create event data with image URLs instead of base64
                    let avatarURL: String? = {
                        if case .success(let url) = avatarResult { return url }
                        Logger.log("Avatar image upload failed or missing", level: .warn, category: "Event")
                        return nil
                    }()
                    let eventData = self?.buildCreateEventData(
                        event: event,
                        userId: userId,
                        eventId: eventId,
                        imageURLs: imageURLs,
                        avatarData: avatarData,
                        avatarURL: avatarURL
                    ) ?? [:]
                    
                    let eventRef = self?.db.collection("users")
                        .document(userId)
                        .collection("events")
                        .document(eventId)
                    
                    eventRef?.setData(eventData) { error in
                        if let error = error {
                            Logger.log("Create error: \(error.localizedDescription)", level: .error, category: "Event")
                            completion(.failure(error))
                        } else {
                            Logger.log("Created: \(eventId) title=\(event.title)", level: .info, category: "Event")
                            // Clean up temporary avatar image after successful event creation
                            self?.deleteTemporaryAvatarImage()
                            completion(.success(eventId))
                        }
                    }
                }
                
            case .failure(let error):
                Logger.log("Image upload error: \(error.localizedDescription)", level: .error, category: "Event")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Async/Await wrappers
    func createEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.createEvent(event, avatarData: avatarData) { result in
                switch result {
                case .success(let id): continuation.resume(returning: id)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAllCurrentAndFutureEvents() async throws -> [Event] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchAllCurrentAndFutureEvents { result in
                switch result {
                case .success(let events): continuation.resume(returning: events)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchEvents(userId: String) async throws -> [Event] {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchEvents(userId: userId) { result in
                switch result {
                case .success(let events): continuation.resume(returning: events)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.updateEvent(event, avatarData: avatarData) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteEvent(eventId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.deleteEvent(eventId: eventId) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Event Fetching
    
    /// Fetch all current and future events from all users for map display
    func fetchAllCurrentAndFutureEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        Logger.log("Fetch all current/future events", level: .debug, category: "Event")
        let now = Date()
        
        // Query all users' events where endDate is in the future
        db.collectionGroup("events")
            .whereField("status", isEqualTo: "active")
            .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: now))
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.log("Fetch all error: \(error.localizedDescription)", level: .error, category: "Event")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Logger.log("No events found", level: .info, category: "Event")
                    completion(.success([]))
                    return
                }
                
                Logger.log("Found \(documents.count) future events", level: .debug, category: "Event")
                let group = DispatchGroup()
                var events: [Event] = []
                
                for document in documents {
                    let data = document.data()
                    
                    // Parse the event data
                    guard let title = data["title"] as? String,
                          let startTimestamp = data["startDate"] as? Timestamp,
                          let endTimestamp = data["endDate"] as? Timestamp,
                          let locationDict = data["location"] as? [String: Any],
                          let locationName = locationDict["name"] as? String,
                          let locationAddress = locationDict["address"] as? String,
                          let details = data["details"] as? String,
                          let createdAtTimestamp = data["createdAt"] as? Timestamp,
                          let imageURLs = data["imageURLs"] as? [String],
                          let userId = data["userId"] as? String else {
                        Logger.log("Skip event: incomplete data", level: .warn, category: "Event")
                        continue
                    }
                    
                    // Parse location coordinates
                    let latitude = locationDict["latitude"] as? Double ?? 0.0
                    let longitude = locationDict["longitude"] as? Double ?? 0.0
                    let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    
                    // Download images from Firebase Storage URLs
                    group.enter()
                    self.downloadEventImages(from: imageURLs) { images in
                        // Create event objects
                        let eventDateTime = EventDateTime(startDate: startTimestamp.dateValue(), endDate: endTimestamp.dateValue())
                        let eventLocation = EventLocation(name: locationName, address: locationAddress, coordinates: coordinates)
                        
                        let event = Event(
                            id: document.documentID,
                            title: title,
                            dateTime: eventDateTime,
                            location: eventLocation,
                            details: details,
                            images: images,
                            createdAt: createdAtTimestamp.dateValue(),
                            userId: userId
                        )
                        
                        events.append(event)
                        group.leave()
                    }
                }
                
                // Wait for all images to download before completing
                group.notify(queue: .main) {
                    Logger.log("Loaded \(events.count) events (with images)", level: .info, category: "Event")
                    completion(.success(events))
                }
            }
    }
    
    func fetchEvents(userId: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        Logger.log("Fetch events for user: \(userId)", level: .debug, category: "Event")
        db.collection("users")
            .document(userId)
            .collection("events")
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.log("Fetch user events error: \(error.localizedDescription)", level: .error, category: "Event")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Logger.log("No user events found", level: .info, category: "Event")
                    completion(.success([]))
                    return
                }
                
                Logger.log("Found \(documents.count) events", level: .debug, category: "Event")
                let group = DispatchGroup()
                var events: [Event] = []
                
                for document in documents {
                    let data = document.data()
                    
                    Logger.log("Parsing event: \(document.documentID)", level: .debug, category: "Event")
                    
                    // Parse the event data
                    guard let title = data["title"] as? String,
                          let startTimestamp = data["startDate"] as? Timestamp,
                          let endTimestamp = data["endDate"] as? Timestamp,
                          let locationDict = data["location"] as? [String: Any],
                          let locationName = locationDict["name"] as? String,
                          let locationAddress = locationDict["address"] as? String,
                          let details = data["details"] as? String,
                          let createdAtTimestamp = data["createdAt"] as? Timestamp,
                          let imageURLs = data["imageURLs"] as? [String] else {
                        Logger.log("Skip event \(document.documentID): incomplete fields", level: .warn, category: "Event")
                        continue
                    }
                    
                    // Parse location coordinates
                    let latitude = locationDict["latitude"] as? Double ?? 0.0
                    let longitude = locationDict["longitude"] as? Double ?? 0.0
                    let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    
                    // Download images from Firebase Storage URLs
                    group.enter()
                    self.downloadEventImages(from: imageURLs) { images in
                        // Create event objects
                        let eventDateTime = EventDateTime(startDate: startTimestamp.dateValue(), endDate: endTimestamp.dateValue())
                        let eventLocation = EventLocation(name: locationName, address: locationAddress, coordinates: coordinates)
                        
                        let event = Event(
                            id: document.documentID,
                            title: title,
                            dateTime: eventDateTime,
                            location: eventLocation,
                            details: details,
                            images: images,
                            createdAt: createdAtTimestamp.dateValue(),
                            userId: userId
                        )
                        
                        events.append(event)
                        group.leave()
                    }
                }
                
                // Wait for all images to download before completing
                group.notify(queue: .main) {
                    completion(.success(events))
                }
            }
    }
    
    // MARK: - Event Updates
    func updateEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        // First, upload event images to Firebase Storage (if any)
        uploadEventImages(event.images, eventId: event.id, userId: userId) { [weak self] result in
            switch result {
            case .success(let imageURLs):
                // Upload temporary avatar image if it exists
                self?.uploadTemporaryAvatarImage(eventId: event.id, userId: userId) { avatarResult in
                    // Create event update data with image URLs
                    let avatarURL: String? = {
                        if case .success(let url) = avatarResult { return url }
                        return nil
                    }()
                    let eventData = self?.buildUpdateEventData(
                        event: event,
                        imageURLs: imageURLs,
                        avatarData: avatarData,
                        avatarURL: avatarURL
                    ) ?? [:]
                    
                    let eventRef = self?.db.collection("users")
                        .document(userId)
                        .collection("events")
                        .document(event.id)
                    
                    eventRef?.updateData(eventData) { error in
                        if let error = error {
                            Logger.log("Update error: \(error.localizedDescription)", level: .error, category: "Event")
                            completion(.failure(error))
                        } else {
                            Logger.log("Updated: \(event.id)", level: .info, category: "Event")
                            // Clean up temporary avatar image after successful update
                            self?.deleteTemporaryAvatarImage()
                            completion(.success(()))
                        }
                    }
                }
                
            case .failure(let error):
                Logger.log("Image upload error (update): \(error.localizedDescription)", level: .error, category: "Event")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Event Deletion
    func deleteEvent(eventId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(handleAuthError()))
            return
        }
        
        let eventRef = db.collection("users")
            .document(userId)
            .collection("events")
            .document(eventId)
        
        eventRef.updateData(["status": "deleted", "deletedAt": FieldValue.serverTimestamp()]) { error in
            if let error = error {
                Logger.log("Delete error: \(error.localizedDescription)", level: .error, category: "Event")
                completion(.failure(error))
            } else {
                Logger.log("Deleted: \(eventId)", level: .info, category: "Event")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Image Optimization
    private func optimizeImageForUpload(_ image: UIImage) -> UIImage {
        // Target dimensions for event images (balance between quality and file size)
        let targetMaxDimension: CGFloat = 1920 // Max width or height
        
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height
        
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            // Landscape
            if originalSize.width > targetMaxDimension {
                newSize = CGSize(width: targetMaxDimension, height: targetMaxDimension / aspectRatio)
            } else {
                return image // No need to resize
            }
        } else {
            // Portrait or square
            if originalSize.height > targetMaxDimension {
                newSize = CGSize(width: targetMaxDimension * aspectRatio, height: targetMaxDimension)
            } else {
                return image // No need to resize
            }
        }
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - Image Upload and Download
    private func uploadEventImages(_ images: [UIImage], eventId: String, userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        guard !images.isEmpty else {
            completion(.success([]))
            return
        }
        
        let storageRef = storage.reference()
        let group = DispatchGroup()
        var imageURLs: [String] = []
        var uploadErrors: [Error] = []
        
        for (index, image) in images.enumerated() {
            group.enter()
            
            // Create a unique filename for each image
            let imageName = "event_\(eventId)_\(index)_\(UUID().uuidString).jpg"
            let imageRef = storageRef.child("event_images/\(userId)/\(imageName)")
            
            // Compress and resize image to optimize storage
            let optimizedImage = self.optimizeImageForUpload(image)
            guard let imageData = optimizedImage.jpegData(compressionQuality: 0.7) else {
                uploadErrors.append(NSError(domain: "EventManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"]))
                group.leave()
                continue
            }
            
            // Check final size before upload (additional safety check)
            if imageData.count > 3 * 1024 * 1024 { // 3MB limit
                uploadErrors.append(NSError(domain: "EventManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image too large after compression"]))
                group.leave()
                continue
            }
            
            // Upload image
            let uploadTask = imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    Logger.log("Image \(index) upload error: \(error.localizedDescription)", level: .error, category: "Event")
                    uploadErrors.append(error)
                    group.leave()
                    return
                }
                
                // Get download URL
                imageRef.downloadURL { url, error in
                    if let error = error {
                        Logger.log("Image \(index) URL error: \(error.localizedDescription)", level: .error, category: "Event")
                        uploadErrors.append(error)
                    } else if let url = url {
                        imageURLs.append(url.absoluteString)
                        Logger.log("Image \(index) uploaded", level: .debug, category: "Event")
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if uploadErrors.isEmpty {
                completion(.success(imageURLs))
            } else {
                completion(.failure(uploadErrors.first!))
            }
        }
    }
    
    private func downloadEventImages(from urls: [String], completion: @escaping ([UIImage]) -> Void) {
        guard !urls.isEmpty else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var images: [UIImage] = []
        
        for urlString in urls {
            group.enter()
            
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                
                if let error = error {
                    Logger.log("Image download error: \(urlString)", level: .error, category: "Event")
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    Logger.log("Image decode failed: \(urlString)", level: .warn, category: "Event")
                    return
                }
                
                images.append(image)
                Logger.log("Image downloaded: \(urlString)", level: .debug, category: "Event")
            }.resume()
        }
        
        group.notify(queue: .main) {
            completion(images)
        }
    }
    
    // MARK: - Temporary Avatar Image Management
    
    private func uploadTemporaryAvatarImage(eventId: String, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Check if temporary avatar image exists
        let tempImagePath = getTemporaryAvatarImagePath()
        
        guard FileManager.default.fileExists(atPath: tempImagePath.path),
              let imageData = try? Data(contentsOf: tempImagePath) else {
            // No temporary avatar image - return success without URL
            Logger.log("No temp avatar image found", level: .warn, category: "Event")
            completion(.success(""))
            return
        }
        
        Logger.log("Upload temp avatar image (\(imageData.count) bytes) for event=\(eventId)", level: .debug, category: "Event")
        
        // Upload to Firebase Storage
        let storageRef = storage.reference()
        let fileName = "event_\(eventId)_avatar_\(UUID().uuidString).png"
        let imageRef = storageRef.child("event_images/\(userId)/\(fileName)")
        
        Logger.log("Storage path: event_images/\(userId)/\(fileName)", level: .debug, category: "Event")
        
        let uploadTask = imageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                Logger.log("Temp avatar upload error: \(error.localizedDescription)", level: .error, category: "Event")
                completion(.failure(error))
                return
            }
            
            // Get download URL
            imageRef.downloadURL { url, error in
                if let error = error {
                    Logger.log("Avatar URL error: \(error.localizedDescription)", level: .error, category: "Event")
                    completion(.failure(error))
                } else if let url = url {
                    Logger.log("Temp avatar uploaded", level: .info, category: "Event")
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "EventManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
    
    private func getTemporaryAvatarImagePath() -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDirectory.appendingPathComponent("temp_event_avatar.png")
    }
    
    private func deleteTemporaryAvatarImage() {
        let tempImagePath = getTemporaryAvatarImagePath()
        try? FileManager.default.removeItem(at: tempImagePath)
        Logger.log("Deleted temp avatar image", level: .debug, category: "Event")
    }
    
    // MARK: - Image Cleanup
    func deleteEventImages(imageURLs: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard !imageURLs.isEmpty else {
            completion(.success(()))
            return
        }
        
        let storageRef = storage.reference()
        let group = DispatchGroup()
        var deleteErrors: [Error] = []
        
        for urlString in imageURLs {
            group.enter()
            
            // Extract the path from the URL
            if let url = URL(string: urlString) {
                let imageRef = storageRef.child(url.path)
                
                imageRef.delete { error in
                    if let error = error {
                        Logger.log("Delete image error: \(error.localizedDescription)", level: .error, category: "Event")
                        deleteErrors.append(error)
                    } else {
                        Logger.log("Deleted image: \(urlString)", level: .debug, category: "Event")
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if deleteErrors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(deleteErrors.first!))
            }
        }
    }
}
