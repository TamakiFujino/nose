import UIKit
import WebKit

class ToSViewController: UIViewController {
    var webView: WKWebView!

    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Replace with your Notion link
        let urlString = "https://www.notion.so/nose-developer/Term-of-Service-19eb49fb8acf80df900bef5232d993a4"

        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}
