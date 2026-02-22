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
                    var eventData: [String: Any] = [
                        "id": eventId,
                        "title": event.title,
                        "startDate": Timestamp(date: event.dateTime.startDate),
                        "endDate": Timestamp(date: event.dateTime.endDate),
                        "location": [
                            "name": event.location.name,
                            "address": event.location.address,
                            "latitude": event.location.coordinates?.latitude ?? 0.0,
                            "longitude": event.location.coordinates?.longitude ?? 0.0
                        ],
                        "details": event.details,
                        "imageURLs": imageURLs, // Store URLs instead of base64
                        "createdAt": Timestamp(date: event.createdAt),
                        "userId": userId,
                        "status": "active",
                        "version": 1
                    ]
                    
                    // Add avatar data if provided
                    if let avatarData = avatarData {
                        eventData["avatarData"] = avatarData.toFirestoreDict()
                    }
                    
                    // Add avatar image URL if uploaded successfully
                    switch avatarResult {
                    case .success(let avatarURL):
                        eventData["avatarImageURL"] = avatarURL
                        print("✅ Avatar image uploaded successfully: \(avatarURL)")
                    case .failure(let error):
                        print("⚠️ Avatar image upload failed: \(error.localizedDescription)")
                        // Continue without avatar image - not critical
                    }
                    
                    let eventRef = self?.db.collection("users")
                        .document(userId)
                        .collection("events")
                        .document(eventId)
                    
                    eventRef?.setData(eventData) { error in
                        if let error = error {
                            print("❌ Error creating event: \(error.localizedDescription)")
                            completion(.failure(error))
                        } else {
                            print("✅ Successfully created event: \(eventId)")
                            print("📊 Event data saved: title=\(eventData["title"] ?? "nil"), status=\(eventData["status"] ?? "nil")")
                            // Clean up temporary avatar image after successful event creation
                            self?.deleteTemporaryAvatarImage()
                            completion(.success(eventId))
                        }
                    }
                }
                
            case .failure(let error):
                print("❌ Error uploading event images: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Event Fetching
    
    /// Fetch all current and future events from all users for map display
    func fetchAllCurrentAndFutureEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        print("🔍 Fetching all current and future events for map")
        let now = Date()
        
        // Query all users' events where endDate is in the future
        db.collectionGroup("events")
            .whereField("status", isEqualTo: "active")
            .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: now))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching all events: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📄 No event documents found")
                    completion(.success([]))
                    return
                }
                
                print("📄 Found \(documents.count) current/future event documents")
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
                        print("⚠️ Skipping event with incomplete data")
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
                    print("✅ Loaded \(events.count) events with images")
                    completion(.success(events))
                }
            }
    }
    
    func fetchEvents(userId: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        print("🔍 Fetching events for user: \(userId)")
        db.collection("users")
            .document(userId)
            .collection("events")
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching events: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📄 No event documents found")
                    completion(.success([]))
                    return
                }
                
                print("📄 Found \(documents.count) event documents")
                let group = DispatchGroup()
                var events: [Event] = []
                
                for document in documents {
                    let data = document.data()
                    
                    print("📋 Parsing event: \(document.documentID)")
                    print("   Keys: \(data.keys.sorted())")
                    
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
                        print("⚠️ Skipping event \(document.documentID) with incomplete data")
                        print("   Missing fields - title: \(data["title"] != nil), startDate: \(data["startDate"] != nil), endDate: \(data["endDate"] != nil)")
                        print("   location: \(data["location"] != nil), details: \(data["details"] != nil), imageURLs: \(data["imageURLs"] != nil)")
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
                    var eventData: [String: Any] = [
                        "title": event.title,
                        "startDate": Timestamp(date: event.dateTime.startDate),
                        "endDate": Timestamp(date: event.dateTime.endDate),
                        "location": [
                            "name": event.location.name,
                            "address": event.location.address,
                            "latitude": event.location.coordinates?.latitude ?? 0.0,
                            "longitude": event.location.coordinates?.longitude ?? 0.0
                        ],
                        "details": event.details,
                        "imageURLs": imageURLs,
                        "updatedAt": FieldValue.serverTimestamp()
                    ]
                    
                    // Add avatar data if provided
                    if let avatarData = avatarData {
                        eventData["avatarData"] = avatarData.toFirestoreDict()
                    }
                    
                    // Add avatar image URL if uploaded successfully
                    switch avatarResult {
                    case .success(let avatarURL):
                        if !avatarURL.isEmpty {
                            eventData["avatarImageURL"] = avatarURL
                            print("✅ Avatar image updated: \(avatarURL)")
                        }
                    case .failure(let error):
                        print("⚠️ Avatar image update failed: \(error.localizedDescription)")
                        // Continue without updating avatar image - not critical
                    }
                    
                    let eventRef = self?.db.collection("users")
                        .document(userId)
                        .collection("events")
                        .document(event.id)
                    
                    eventRef?.updateData(eventData) { error in
                        if let error = error {
                            print("❌ Error updating event: \(error.localizedDescription)")
                            completion(.failure(error))
                        } else {
                            print("✅ Successfully updated event: \(event.id)")
                            // Clean up temporary avatar image after successful update
                            self?.deleteTemporaryAvatarImage()
                            completion(.success(()))
                        }
                    }
                }
                
            case .failure(let error):
                print("❌ Error uploading event images during update: \(error.localizedDescription)")
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
                print("❌ Error deleting event: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Successfully deleted event: \(eventId)")
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
            
            // Upload image with content type metadata
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            let uploadTask = imageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ Error uploading image \(index): \(error.localizedDescription)")
                    uploadErrors.append(error)
                    group.leave()
                    return
                }
                
                // Get download URL
                imageRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ Error getting download URL for image \(index): \(error.localizedDescription)")
                        uploadErrors.append(error)
                    } else if let url = url {
                        imageURLs.append(url.absoluteString)
                        print("✅ Successfully uploaded image \(index): \(url.absoluteString)")
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
                    print("❌ Error downloading image from \(urlString): \(error.localizedDescription)")
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    print("❌ Failed to create image from data for URL: \(urlString)")
                    return
                }
                
                images.append(image)
                print("✅ Successfully downloaded image from: \(urlString)")
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
            print("⚠️ No temporary avatar image found")
            completion(.success(""))
            return
        }
        
        print("📤 Uploading temporary avatar image...")
        print("   File size: \(imageData.count) bytes (\(Double(imageData.count) / 1024.0 / 1024.0) MB)")
        print("   User ID: \(userId)")
        print("   Event ID: \(eventId)")
        
        // Upload to Firebase Storage
        let storageRef = storage.reference()
        let fileName = "event_\(eventId)_avatar_\(UUID().uuidString).png"
        let imageRef = storageRef.child("event_images/\(userId)/\(fileName)")
        
        print("   Storage path: event_images/\(userId)/\(fileName)")
        print("   Full storage URL: gs://nose-a2309.firebasestorage.app/event_images/\(userId)/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        
        let uploadTask = imageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ Error uploading temporary avatar image: \(error.localizedDescription)")
                print("   Error code: \(error._code)")
                print("   Error domain: \(error._domain)")
                if let nsError = error as NSError? {
                    print("   NSError userInfo: \(nsError.userInfo)")
                }
                completion(.failure(error))
                return
            }
            
            // Get download URL
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL for avatar image: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let url = url {
                    print("✅ Successfully uploaded temporary avatar image: \(url.absoluteString)")
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
        print("🗑️ Deleted temporary avatar image")
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
                        print("❌ Error deleting image: \(error.localizedDescription)")
                        deleteErrors.append(error)
                    } else {
                        print("✅ Successfully deleted image: \(urlString)")
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
