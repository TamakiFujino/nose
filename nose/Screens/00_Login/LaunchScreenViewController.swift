import UIKit

class LaunchScreenViewController: UIViewController {
    
    @IBOutlet weak var loadingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start updating the loading percentage
        updateLoadingPercentage()
    }
    
    func updateLoadingPercentage() {
        var percentage = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            percentage += 1
            self.loadingLabel.text = "Loading \(percentage)%"
            
            if percentage >= 100 {
                timer.invalidate()
                self.transitionToMainApp()
            }
        }
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
