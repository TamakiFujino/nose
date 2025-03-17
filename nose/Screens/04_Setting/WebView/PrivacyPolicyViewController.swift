import UIKit
import WebKit

class PrivacyPolicyViewController: UIViewController {
    var webView: WKWebView!

    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Replace with your Notion link
        let urlString = "https://www.notion.so/nose-developer/19eb49fb8acf806abc10d55cdcdd41ac"

        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}
