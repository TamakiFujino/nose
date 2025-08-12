import UIKit

class ContentViewController: UIViewController, ContentViewControllerDelegate {
    private var floatingWindow: UIWindow?

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.launchUnity() }
    }

    private func launchUnity() {
        print("Launching Unity...")
        UnityLauncher.shared().launchUnityIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.createFloatingUI() }
    }

    private func createFloatingUI() {
        print("Creating floating UI on top of Unity...")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        floatingWindow = UIWindow(windowScene: windowScene)
        guard let floatingWindow = floatingWindow else { return }

        let floatingVC = FloatingUIController()
        floatingVC.delegate = self
        floatingWindow.rootViewController = floatingVC
        floatingWindow.frame = UIScreen.main.bounds
        floatingWindow.windowLevel = .alert + 1
        floatingWindow.isHidden = false
        floatingWindow.makeKeyAndVisible()
    }
}

protocol ContentViewControllerDelegate: AnyObject {}
