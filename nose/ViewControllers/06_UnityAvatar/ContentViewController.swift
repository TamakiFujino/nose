import UIKit
import FirebaseAuth
import FirebaseFirestore

class ContentViewController: UIViewController, ContentViewControllerDelegate {
    private var floatingWindow: UIWindow?
    private let collection: PlaceCollection

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

    private func launchUnity() {
        print("[ContentViewController] Launching Unity...")
        UnityLauncher.shared().launchUnityIfNeeded()
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
        // Load existing avatar data for this collection and apply when available
        fetchExistingSelections { [weak floatingVC] selections in
            guard let floatingVC = floatingVC, let selections = selections else { return }
            DispatchQueue.main.async {
                floatingVC.initialSelections = selections
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
        let avatarData = CollectionAvatar.AvatarData(
            selections: selections,
            customizations: [:],
            lastCustomizedAt: Date(),
            customizationVersion: 1
        )
        CollectionManager.shared.updateAvatarData(avatarData, for: collection) { [weak self] result in
            guard let self = self else { return }
            LoadingView.shared.hideAlertLoading()
            switch result {
            case .success:
                let alert = UIAlertController(title: "Saved", message: "Avatar customization saved.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            case .failure(let error):
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}
