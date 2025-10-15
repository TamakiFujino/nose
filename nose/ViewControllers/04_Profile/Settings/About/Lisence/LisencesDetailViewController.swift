import UIKit

class LicenseDetailViewController: UIViewController {

    var licenseText: String = ""
    let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()

        let backButton = UIBarButtonItem()
        backButton.title = ""  // Hide the "Back" text
        self.navigationItem.backBarButtonItem = backButton
        self.navigationController?.navigationBar.tintColor = .sixthColor

        view.backgroundColor = .firstColor

        setupTextView()
    }

    func setupTextView() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.textColor = .sixthColor
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.text = licenseText
        view.addSubview(textView)

        // Constraints for TextView
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -DesignTokens.Spacing.lg)
        ])
    }
}
