import UIKit

class LaunchScreenViewController: UIViewController {

    @IBOutlet weak var loadingLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func transitionToMainApp() {
        // Transition to the main app, e.g., by setting the root view controller
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let mainViewController = mainStoryboard.instantiateViewController(withIdentifier: "MainViewController")
            appDelegate.window?.rootViewController = mainViewController
        }
    }
}
