import UIKit

// MARK: - Avatar Data Handling
extension CreateEventViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Check if we have avatar data from the temporary collection
        checkForAvatarData()
    }

    private func checkForAvatarData() {
        // Check if we have avatar data stored locally from a previous customization session
        if let savedData = UserDefaults.standard.data(forKey: tempAvatarDataKey),
           let avatarData = try? JSONDecoder().decode(CollectionAvatar.AvatarData.self, from: savedData) {
            self.avatarData = avatarData

            // Load and display the temporary avatar image if it exists
            DispatchQueue.main.async { [weak self] in
                self?.loadTemporaryAvatarImage()
            }

            Logger.log("Retrieved saved avatar data for event: \(avatarData.selections.count) categories", level: .info, category: "CreateEvent")
        } else {
            Logger.log("No saved avatar data found - user can customize avatar", level: .debug, category: "CreateEvent")
        }
    }

    func saveAvatarDataLocally(_ avatarData: CollectionAvatar.AvatarData) {
        // Save avatar data locally so it persists across app sessions
        if let data = try? JSONEncoder().encode(avatarData) {
            UserDefaults.standard.set(data, forKey: tempAvatarDataKey)
            Logger.log("Saved avatar data locally", level: .info, category: "CreateEvent")
        }
    }

    // MARK: - Temporary Avatar Image Storage

    func loadTemporaryAvatarImage() {
        // Try to load the temporary avatar image from local storage
        let tempImagePath = getTemporaryAvatarImagePath()

        if FileManager.default.fileExists(atPath: tempImagePath.path),
           let image = UIImage(contentsOfFile: tempImagePath.path) {
            // Display the temporary avatar image
            avatarImageView.image = image
            avatarImageView.contentMode = .scaleAspectFit
            Logger.log("Loaded temporary avatar image from local storage", level: .info, category: "CreateEvent")
        } else {
            // Fallback to default avatar if no temporary image exists
            avatarImageView.image = UIImage(named: "avatar") ?? UIImage(systemName: "person.crop.circle")
            Logger.log("No temporary avatar image found, using default", level: .debug, category: "CreateEvent")
        }
    }

    func saveTemporaryAvatarImage(_ image: UIImage) {
        // Save the avatar image temporarily to local storage
        let tempImagePath = getTemporaryAvatarImagePath()

        // Create directory if it doesn't exist
        let directory = tempImagePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        // Save image as PNG to preserve quality
        if let imageData = image.pngData() {
            do {
                try imageData.write(to: tempImagePath)
                Logger.log("Saved temporary avatar image to: \(tempImagePath.path)", level: .info, category: "CreateEvent")
            } catch {
                Logger.log("Failed to save temporary avatar image: \(error.localizedDescription)", level: .error, category: "CreateEvent")
            }
        }
    }

    private func getTemporaryAvatarImagePath() -> URL {
        // Create a unique path for the temporary event avatar image
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDirectory.appendingPathComponent("temp_event_avatar.png")
    }

    private func deleteTemporaryAvatarImage() {
        // Delete the temporary avatar image file
        let tempImagePath = getTemporaryAvatarImagePath()
        try? FileManager.default.removeItem(at: tempImagePath)
        Logger.log("Deleted temporary avatar image", level: .debug, category: "CreateEvent")
    }

    func clearTemporaryAvatarState() {
        // Reset in-memory avatar
        avatarData = nil

        // Remove any locally saved avatar data
        UserDefaults.standard.removeObject(forKey: tempAvatarDataKey)
        Logger.log("Cleared saved temporary avatar data", level: .debug, category: "CreateEvent")

        // Delete the temporary avatar image file
        deleteTemporaryAvatarImage()

        // No Firestore cleanup needed - we never create a collection there
    }

    func dismissSelf() {
        if let nav = navigationController {
            nav.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    func setupNotifications() {
        // Listen for avatar data updates from ContentViewController
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avatarDataUpdated(_:)),
            name: NSNotification.Name("AvatarDataUpdated"),
            object: nil
        )
    }

    @objc func avatarDataUpdated(_ notification: Notification) {
        // Handle avatar data update from ContentViewController
        guard let userInfo = notification.userInfo,
              let selections = userInfo["selections"] as? [String: [String: String]] else {
            return
        }

        let avatarData = CollectionAvatar.AvatarData(
            selections: selections,
            customizations: [:],
            lastCustomizedAt: Date(),
            customizationVersion: 1
        )

        updateAvatarData(avatarData)
        saveAvatarDataLocally(avatarData)

        // Update the avatar image view to reflect the new avatar
        updateAvatarImageView()

        Logger.log("Avatar data updated via notification: \(selections.count) categories", level: .info, category: "CreateEvent")
    }
}
