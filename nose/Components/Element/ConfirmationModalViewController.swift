import UIKit

/// Reusable two-button confirmation modal (title, message, primary + cancel).
/// Matches MessageModalViewController visual style (overlay, rounded container).
class ConfirmationModalViewController: UIViewController {

    enum PrimaryStyle {
        case `default`  // themeBlue
        case destructive
    }

    private let titleText: String
    private let messageText: String
    private let primaryTitle: String
    private let primaryStyle: PrimaryStyle
    private let cancelTitle: String
    private let onPrimary: () -> Void
    private let onCancel: (() -> Void)?

    private var cancelButton: UIButton?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .fourthColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(
        title: String,
        message: String,
        primaryTitle: String,
        primaryStyle: PrimaryStyle = .default,
        cancelTitle: String = "Cancel",
        onPrimary: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.titleText = title
        self.messageText = message
        self.primaryTitle = primaryTitle
        self.primaryStyle = primaryStyle
        self.cancelTitle = cancelTitle
        self.onPrimary = onPrimary
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBackgroundTap()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let cancel = cancelButton, cancel.bounds.height > 0 {
            cancel.layer.cornerRadius = cancel.bounds.height / 2
        }
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        titleLabel.text = titleText
        messageLabel.text = messageText

        let cancel = UIButton(type: .system)
        cancel.setTitle(cancelTitle, for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancel.setTitleColor(.black, for: .normal)
        cancel.backgroundColor = .secondColor
        cancel.layer.masksToBounds = true
        cancel.layer.cornerRadius = 25  // pill: height 50 / 2
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton = cancel

        let primaryButton = CustomButton()
        primaryButton.setTitle(primaryTitle, for: .normal)
        primaryButton.style = primaryStyle == .destructive ? .destructive : .themeBlue
        primaryButton.size = .large
        primaryButton.isPerfectlyRounded = true
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [cancel, primaryButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 32),
            buttonStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
            buttonStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }

    private func setupBackgroundTap() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
    }

    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !containerView.frame.contains(location) {
            dismissWithCancel()
        }
    }

    @objc private func cancelTapped() {
        dismissWithCancel()
    }

    @objc private func primaryTapped() {
        dismiss(animated: true) { [onPrimary] in
            onPrimary()
        }
    }

    private func dismissWithCancel() {
        dismiss(animated: true) { [onCancel] in
            onCancel?()
        }
    }
}
