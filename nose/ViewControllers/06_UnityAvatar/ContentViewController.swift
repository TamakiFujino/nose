import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ContentViewController: UIViewController, ContentViewControllerDelegate {
    private var floatingWindow: UIWindow?
    private let collection: PlaceCollection
    // TEMP flag was used to test; re-enable UI now that we forward drags
    private let temporaryDisableNativeUI: Bool = false

    init(collection: PlaceCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.launchUnity() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh selections from Firestore every time we come back to this scene
        applyLatestSelectionsIfVisible()
    }

    private func launchUnity() {
        print("[ContentViewController] Launching Unity...")
        UnityLauncher.shared().launchUnityIfNeeded()
        // TEMP: skip native overlays so touches pass to Unity
        guard !temporaryDisableNativeUI else {
            print("[ContentViewController] TEMP: Native UI disabled; not showing overlays")
            return
        }
        // Show a loading overlay immediately while Unity is preparing and before UI is ready
        showLoadingOverlayWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.createFloatingUI() }
    }

    private func showLoadingOverlayWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if floatingWindow == nil {
            floatingWindow = UIWindow(windowScene: windowScene)
            floatingWindow?.frame = UIScreen.main.bounds
            floatingWindow?.windowLevel = .alert + 1
        }
        guard let floatingWindow = floatingWindow else { return }
        let placeholderVC = UIViewController()
        placeholderVC.view.backgroundColor = .clear
        floatingWindow.rootViewController = placeholderVC
        floatingWindow.isHidden = false
        floatingWindow.makeKeyAndVisible()
        LoadingView.shared.showOverlayLoading(on: placeholderVC.view, message: "Loading avatar...")
        print("[ContentViewController] Loading overlay window shown")
    }

    private func createFloatingUI() {
        print("[ContentViewController] Creating floating UI on top of Unity...")
        guard let floatingWindow = floatingWindow else { return }

        let floatingVC = FloatingUIController()
        floatingVC.delegate = self
        // Ensure a clean Unity state when entering a new collection
        floatingVC.resetAllSlotsInUnity()
        // Load existing avatar data for this collection and apply when available
        fetchExistingSelections { [weak floatingVC] selections in
            guard let floatingVC = floatingVC, let selections = selections else { return }
            DispatchQueue.main.async {
                floatingVC.applyInitialSelections(selections)
            }
        }
        floatingWindow.rootViewController = floatingVC
        floatingWindow.frame = UIScreen.main.bounds
        floatingWindow.windowLevel = .alert + 1
        floatingWindow.isHidden = false
        floatingWindow.makeKeyAndVisible()
        // Keep overlay visible while the floating UI prepares thumbnails
        LoadingView.shared.showOverlayLoading(on: floatingVC.view, message: "Loading avatar...")
        print("[ContentViewController] Floating UI created and visible")
    }

    private func applyLatestSelectionsIfVisible() {
        guard let floatingVC = floatingWindow?.rootViewController as? FloatingUIController else { return }
        fetchExistingSelections { selections in
            guard let selections = selections else { return }
            DispatchQueue.main.async {
                floatingVC.applyInitialSelections(selections)
            }
        }
    }

    private func fetchExistingSelections(completion: @escaping ([String: [String: String]]?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { completion(nil); return }
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("collections")
            .document(collection.id)
            .getDocument { snapshot, error in
                if let error = error {
                    print("[ContentViewController] Failed to fetch existing avatar: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                guard let data = snapshot?.data(),
                      let avatarData = data["avatarData"] as? [String: Any],
                      let selections = avatarData["selections"] as? [String: [String: String]] else {
                    completion(nil)
                    return
                }
                completion(selections)
            }
    }
}

protocol ContentViewControllerDelegate: AnyObject {
    func didRequestClose()
    func didRequestSave(selections: [String: [String: String]])
}

extension ContentViewController {
    func didRequestClose() {
        print("[ContentViewController] didRequestClose() called")
        // Remove floating UI and go back
        floatingWindow?.isHidden = true
        floatingWindow?.rootViewController = nil
        floatingWindow = nil
        // Optionally hide Unity window to reveal host UI
        print("[ContentViewController] Hiding Unity window (no-op)")
        UnityLauncher.shared().hideUnity()
        // Bring host app window to front again
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let normalWindows = windowScene.windows.filter { $0.windowLevel == .normal }
            if let appWindow = normalWindows.first {
                print("[ContentViewController] Making app window key and visible")
                appWindow.makeKeyAndVisible()
            } else {
                print("[ContentViewController] No normal-level app window found")
            }
        } else {
            print("[ContentViewController] No UIWindowScene available")
        }
        if let nav = navigationController {
            print("[ContentViewController] Popping view controller")
            nav.popViewController(animated: true)
        } else {
            print("[ContentViewController] Dismissing view controller")
            dismiss(animated: true)
        }
    }

    func didRequestSave(selections: [String : [String : String]]) {
        print("[ContentViewController] didRequestSave() called with \(selections.count) entries")
        LoadingView.shared.showAlertLoading(title: "Saving", on: self)
        let sanitized = sanitizeSelectionsForSave(selections)
        let avatarData = CollectionAvatar.AvatarData(
            selections: sanitized,
            customizations: [:],
            lastCustomizedAt: Date(),
            customizationVersion: 1
        )
        CollectionManager.shared.updateAvatarData(avatarData, for: collection) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.captureAndUploadThumbnail { uploadResult in
                    LoadingView.shared.hideAlertLoading()
                    switch uploadResult {
                    case .success:
                        self.applyLatestSelectionsIfVisible()
                    case .failure(let error):
                        print("[ContentViewController] Thumbnail upload failed: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                LoadingView.shared.hideAlertLoading()
                print("[ContentViewController] Save error: \(error.localizedDescription)")
            }
        }
    }

    private func captureAndUploadThumbnail(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "ContentViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])));
            return
        }
        // Prefer file-based capture to avoid bridge callback issues
        let relative = "avatar_captures/users/\(uid)/collections/\(collection.id)/avatar.png"
        // High-res capture: 2x device scale of display size (capped by Unity at 4096)
        let scale = UIScreen.main.scale
        let logicalWidth = UIScreen.main.bounds.width - 32
        let targetWidth = Int(min(4096, max(512, logicalWidth * scale * 2)))
        let targetHeight = Int(min(4096, max(400, 300.0 * scale * 2)))
        // Request transparent background
        let message = "\(relative)|\(targetWidth)|\(targetHeight)|1"
        UnityLauncher.shared().sendMessage(
            toUnity: "UnityBridge",
            method: "CaptureAvatarThumbnailToFile",
            message: message
        )

        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fullPath = cachesURL.appendingPathComponent(relative).path
        waitForFile(atPath: fullPath, timeout: 2.0, pollInterval: 0.1) { [weak self] fileResult in
            guard let self = self else { return }
            switch fileResult {
            case .success:
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: fullPath))
                    self.uploadThumbnailData(data, uid: uid) { uploadResult in
                        // Cleanup temp file
                        try? FileManager.default.removeItem(atPath: fullPath)
                        completion(uploadResult)
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure:
                // Fallback to bridge-based base64 capture
                UnityManager.shared.requestAvatarThumbnail { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let data):
                        self.uploadThumbnailData(data, uid: uid, completion: completion)
                    }
                }
            }
        }
    }

    private func uploadThumbnailData(_ data: Data, uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Give the upload time to finish if the app goes to background
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        if bgTask == .invalid {
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "avatarUpload") {}
        }

        let path = "collection_avatars/\(uid)/\(self.collection.id)/avatar.png"
        let ref = Storage.storage().reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"

        // Try up to 3 attempts with exponential backoff
        func attemptUpload(attempt: Int) {
            ref.putData(data, metadata: metadata) { _, error in
                if let error = error {
                    if attempt < 3 {
                        let delay = pow(2.0, Double(attempt - 1)) * 0.5 // 0.5s, 1s, 2s
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                            attemptUpload(attempt: attempt + 1)
                        }
                    } else {
                        if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
                        completion(.failure(error))
                    }
                    return
                }

                // Fetch download URL (also with retry)
                func getURL(attempt: Int) {
                    ref.downloadURL { url, urlErr in
                        if let urlErr = urlErr {
                            if attempt < 3 {
                                let delay = pow(2.0, Double(attempt - 1)) * 0.5
                                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                                    getURL(attempt: attempt + 1)
                                }
                            } else {
                                if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
                                completion(.failure(urlErr))
                            }
                            return
                        }
                        guard let url = url else {
                            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
                            completion(.failure(NSError(domain: "ContentViewController", code: -2, userInfo: [NSLocalizedDescriptionKey: "No download URL"])));
                            return
                        }

                        let db = Firestore.firestore()
                        db.collection("users").document(uid).collection("collections").document(self.collection.id)
                            .setData([
                                "avatarThumbnailURL": url.absoluteString,
                                "avatarThumbnailUpdatedAt": FieldValue.serverTimestamp()
                            ], merge: true) { err in
                                if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
                                if let err = err {
                                    completion(.failure(err))
                                } else {
                                    // Notify listeners to refresh thumbnail
                                    NotificationCenter.default.post(
                                        name: Notification.Name("AvatarThumbnailUpdated"),
                                        object: nil,
                                        userInfo: ["collectionId": self.collection.id]
                                    )
                                    completion(.success(()))
                                }
                            }
                    }
                }
                getURL(attempt: 1)
            }
        }
        attemptUpload(attempt: 1)
    }

    private func waitForFile(atPath path: String, timeout: TimeInterval, pollInterval: TimeInterval, completion: @escaping (Result<Void, Error>) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func poll() {
            if FileManager.default.fileExists(atPath: path) {
                completion(.success(()))
                return
            }
            if Date() > deadline {
                completion(.failure(NSError(domain: "ContentViewController", code: -3, userInfo: [NSLocalizedDescriptionKey: "Capture timeout"])));
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { poll() }
        }
        poll()
    }

    private func sanitizeSelectionsForSave(_ selections: [String: [String: String]]) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        for (key, entry) in selections {
            // key format: "Category_Subcategory"
            let parts = key.split(separator: "_").map(String.init)
            guard parts.count == 2 else { continue }
            let category = parts[0].lowercased()
            let subcategory = parts[1].lowercased()
            if category == "base" && subcategory == "body" {
                // Keep only if pose/model is present
                let pose = (entry["pose"] ?? entry["model"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !pose.isEmpty {
                    result[key] = entry
                }
            } else {
                // Keep only if model is present
                let model = (entry["model"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !model.isEmpty {
                    result[key] = entry
                }
            }
        }
        return result
    }
}
