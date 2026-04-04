import UIKit
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import AuthenticationServices
import CryptoKit

final class LoginViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var launchLogoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "logo_dark")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var appNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "app_name")
        label.textAlignment = .center
        let font = UIFont(name: "Futura-Medium", size: 66) ?? UIFont.systemFont(ofSize: 66, weight: .medium)
        label.font = font
        label.textColor = .white
        label.alpha = 0 // Initially invisible
        return label
    }()
    
    private lazy var appleButton: CustomGlassButton = {
        let button = CustomGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        setupSocialButton(button: button, iconName: "applelogo", title: String(localized: "apple_login"))
        button.addTarget(self, action: #selector(appleButtonTapped), for: .touchUpInside)
        button.alpha = 0 // Initially invisible
        button.accessibilityIdentifier = "continue_with_apple"
        button.accessibilityLabel = String(localized: "apple_login")
        return button
    }()
    
    private lazy var googleButton: CustomGlassButton = {
        let button = CustomGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        setupSocialButton(button: button, iconName: "google_logo", title: String(localized: "google_login"))
        button.addTarget(self, action: #selector(googleButtonTapped), for: .touchUpInside)
        button.alpha = 0 // Initially invisible
        button.accessibilityIdentifier = "continue_with_google"
        button.accessibilityLabel = String(localized: "google_login")
        return button
    }()
    
    private lazy var termsAndPrivacyTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.alpha = 0 // Initially invisible
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.white,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let base = String(localized: "login_terms_base")
        let terms = String(localized: "login_terms_of_service")
        let and = String(localized: "login_terms_and")
        let privacy = String(localized: "login_privacy_policy")
        let end = String(localized: "login_terms_end")
        let full = base + terms + and + privacy + end
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributed = NSMutableAttributedString(
            string: full,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )
        let termsRange = (full as NSString).range(of: terms)
        let privacyRange = (full as NSString).range(of: privacy)
        attributed.addAttribute(.link, value: "nose://terms", range: termsRange)
        attributed.addAttribute(.link, value: "nose://privacy", range: privacyRange)
        textView.attributedText = attributed
        return textView
    }()
    
    private lazy var sloganStaticLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "login_tagline")
        label.font = .systemFont(ofSize: 22, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.alpha = 0
        return label
    }()

    private lazy var sloganKeywordLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 0
        return label
    }()

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var avatarContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()

    private lazy var loadingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.isHidden = true
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }()
    
    // MARK: - Properties
    private var currentNonce: String?
    private var isLoginMode = false
    private var loginGradientLayer: CAGradientLayer?
    private let avatarImageNames = ["a", "b", "c", "d", "e", "f", "g"]
    private let avatarGradientColors: [(top: UIColor, bottom: UIColor)] = [
        (UIColor(red: 0.85, green: 0.80, blue: 0.90, alpha: 1), UIColor(red: 0.60, green: 0.50, blue: 0.75, alpha: 1)), // a: soft lavender
        (UIColor(red: 0.25, green: 0.30, blue: 0.45, alpha: 1), UIColor(red: 0.15, green: 0.18, blue: 0.35, alpha: 1)), // b: dark navy
        (UIColor(red: 0.65, green: 0.82, blue: 0.55, alpha: 1), UIColor(red: 0.40, green: 0.55, blue: 0.65, alpha: 1)), // c: green-teal
        (UIColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1), UIColor(red: 0.30, green: 0.45, blue: 0.80, alpha: 1)), // d: sporty blue
        (UIColor(red: 0.95, green: 0.80, blue: 0.85, alpha: 1), UIColor(red: 0.75, green: 0.50, blue: 0.60, alpha: 1)), // e: pink blush
        (UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1), UIColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 1)), // f: monochrome gray
        (UIColor(red: 0.55, green: 0.75, blue: 0.72, alpha: 1), UIColor(red: 0.65, green: 0.45, blue: 0.65, alpha: 1)), // g: teal-to-mauve
    ]
    private let avatarEmojis: [[String]] = [
        ["♨️", "🧖", "💆", "🫧", "🧴", "💤", "🌿", "🕯️"],      // a: sauna / relaxing / hotspring
        ["🏙️", "🛹", "🎤", "🔊", "🧢", "👟", "🎧", "💯"],      // b: street / city boy
        ["🧟", "👾", "🎮", "💀", "👻", "🕹️", "🧠", "🦇"],      // c: zombie / monsters / game
        ["🏃‍♀️", "⚽️", "🏅", "💪", "👟", "🔥", "🥇", "🎯"],     // d: running / sports
        ["📚", "🎀", "🍰", "💅", "🧸", "📝", "🩰", "🌸"],      // e: school girl / teen
        ["🖤", "🤍", "🌑", "♟️", "🎬", "🖋️", "⛓️", "🕶️"],     // f: gray / monochrome
        ["🌈", "💖", "🎉", "🦄", "🍬", "🎨", "✨", "🪩"],      // g: colorful / pop
    ]
    private lazy var avatarSloganKeywords: [String] = [
        String(localized: "login_keyword_a"),
        String(localized: "login_keyword_b"),
        String(localized: "login_keyword_c"),
        String(localized: "login_keyword_d"),
        String(localized: "login_keyword_e"),
        String(localized: "login_keyword_f"),
        String(localized: "login_keyword_g"),
    ]
    private lazy var avatarPlaceNames: [[String]] = [
        [String(localized: "login_place_a1"), String(localized: "login_place_a2"), String(localized: "login_place_a3"), String(localized: "login_place_a4"), String(localized: "login_place_a5"), String(localized: "login_place_a6")],
        [String(localized: "login_place_b1"), String(localized: "login_place_b2"), String(localized: "login_place_b3"), String(localized: "login_place_b4"), String(localized: "login_place_b5"), String(localized: "login_place_b6")],
        [String(localized: "login_place_c1"), String(localized: "login_place_c2"), String(localized: "login_place_c3"), String(localized: "login_place_c4"), String(localized: "login_place_c5"), String(localized: "login_place_c6")],
        [String(localized: "login_place_d1"), String(localized: "login_place_d2"), String(localized: "login_place_d3"), String(localized: "login_place_d4"), String(localized: "login_place_d5"), String(localized: "login_place_d6")],
        [String(localized: "login_place_e1"), String(localized: "login_place_e2"), String(localized: "login_place_e3"), String(localized: "login_place_e4"), String(localized: "login_place_e5"), String(localized: "login_place_e6")],
        [String(localized: "login_place_f1"), String(localized: "login_place_f2"), String(localized: "login_place_f3"), String(localized: "login_place_f4"), String(localized: "login_place_f5"), String(localized: "login_place_f6")],
        [String(localized: "login_place_g1"), String(localized: "login_place_g2"), String(localized: "login_place_g3"), String(localized: "login_place_g4"), String(localized: "login_place_g5"), String(localized: "login_place_g6")],
    ]
    private var emojiViews: [UIView] = []
    private var currentAvatarIndex = 0
    private var avatarTimer: Timer?
    private var typingTimer: Timer?
    weak var sceneDelegate: SceneDelegate?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLaunchStyle()
        checkLoginState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        avatarTimer?.invalidate()
        avatarTimer = nil
        typingTimer?.invalidate()
        typingTimer = nil
        emojiViews.forEach { $0.removeFromSuperview() }
        emojiViews.removeAll()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isLoginMode {
            loginGradientLayer?.frame = view.bounds
        }
    }
    
    // MARK: - Setup
    private func setupLaunchStyle() {
        // Start with launch screen style (white background + logo)
        view.backgroundColor = .white
        view.addSubview(launchLogoImageView)
        
        // Setup launch logo constraints
        NSLayoutConstraint.activate([
            launchLogoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            launchLogoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            launchLogoImageView.widthAnchor.constraint(equalToConstant: 221), // Match LaunchScreen size
            launchLogoImageView.heightAnchor.constraint(equalToConstant: 348), // Match LaunchScreen size
        ])
    }
    
    private func setupLoginStyle() {
        // Switch to login style (gradient background + logo above slogan)
        isLoginMode = true
        
        launchLogoImageView.removeFromSuperview()
        view.backgroundColor = .themeLightBlue
        
        let initialColors = avatarGradientColors[0]
        let gradient = CAGradientLayer()
        gradient.colors = [initialColors.top.cgColor, initialColors.bottom.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
        loginGradientLayer = gradient

        let bottomStack = UIStackView(arrangedSubviews: [termsAndPrivacyTextView, appleButton, googleButton])
        bottomStack.axis = .vertical
        bottomStack.alignment = .center
        bottomStack.spacing = 8
        bottomStack.setCustomSpacing(16, after: termsAndPrivacyTextView)
        bottomStack.translatesAutoresizingMaskIntoConstraints = false

        avatarContainerView.addSubview(avatarImageView)

        view.addSubview(sloganStaticLabel)
        view.addSubview(sloganKeywordLabel)
        view.addSubview(avatarContainerView)
        view.addSubview(bottomStack)
        view.addSubview(loadingView)

        appleButton.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true
        appleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        googleButton.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true
        googleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        avatarContainerView.alpha = 0

        NSLayoutConstraint.activate([
            sloganStaticLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sloganStaticLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            sloganKeywordLabel.topAnchor.constraint(equalTo: sloganStaticLabel.bottomAnchor, constant: 2),
            sloganKeywordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            avatarContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.72),
            avatarContainerView.heightAnchor.constraint(equalTo: avatarContainerView.widthAnchor, multiplier: 1.2),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainerView.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainerView.bottomAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarContainerView.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor),
            termsAndPrivacyTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            termsAndPrivacyTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Set initial avatar image and slogan
        currentAvatarIndex = 0
        avatarImageView.image = UIImage(named: avatarImageNames[currentAvatarIndex])
        sloganKeywordLabel.text = ""
        sloganKeywordLabel.alpha = 1

        UIView.animate(withDuration: 0.5) {
            self.avatarContainerView.alpha = 1
            self.sloganStaticLabel.alpha = 1
            self.termsAndPrivacyTextView.alpha = 1
            self.appleButton.alpha = 1
            self.googleButton.alpha = 1
        } completion: { _ in
            self.typeKeyword(self.avatarSloganKeywords[self.currentAvatarIndex])
            self.spawnEmojiViews()
        }

        startAvatarCarousel()
    }
    
    private func startAvatarCarousel() {
        avatarTimer?.invalidate()
        avatarTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.slideToNextAvatar()
        }
    }

    private func slideToNextAvatar() {
        let nextIndex = (currentAvatarIndex + 1) % avatarImageNames.count
        let nextImage = UIImage(named: avatarImageNames[nextIndex])
        let nextColors = avatarGradientColors[nextIndex]

        // Animate gradient transition
        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = loginGradientLayer?.colors
        colorAnimation.toValue = [nextColors.top.cgColor, nextColors.bottom.cgColor]
        colorAnimation.duration = 0.6
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        loginGradientLayer?.colors = [nextColors.top.cgColor, nextColors.bottom.cgColor]
        loginGradientLayer?.add(colorAnimation, forKey: "colorChange")

        // Remove old emoji and clear keyword
        removeEmojiViews()
        typingTimer?.invalidate()
        sloganKeywordLabel.text = ""

        let slideDistance = view.bounds.width

        // Create incoming image view matching avatarImageView's layout
        let nextImageView = UIImageView(image: nextImage)
        nextImageView.contentMode = .scaleAspectFit
        nextImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarContainerView.insertSubview(nextImageView, belowSubview: avatarImageView)
        NSLayoutConstraint.activate([
            nextImageView.topAnchor.constraint(equalTo: avatarContainerView.topAnchor),
            nextImageView.bottomAnchor.constraint(equalTo: avatarContainerView.bottomAnchor),
            nextImageView.leadingAnchor.constraint(equalTo: avatarContainerView.leadingAnchor),
            nextImageView.trailingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor),
        ])

        // Position next image off-screen to the right
        nextImageView.transform = CGAffineTransform(translationX: slideDistance, y: 0)

        // Current image slides out left with dramatic ease-in (slow start, fast exit)
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: .curveEaseIn
        ) {
            self.avatarImageView.transform = CGAffineTransform(translationX: -slideDistance, y: 0)
        }

        // Next image slides in from right with dramatic ease-out (fast entry, gentle stop)
        UIView.animate(
            withDuration: 0.7,
            delay: 0.1,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.9,
            options: .curveEaseOut
        ) {
            nextImageView.transform = .identity
        } completion: { _ in
            self.avatarImageView.image = nextImage
            self.avatarImageView.transform = .identity
            self.currentAvatarIndex = nextIndex
            nextImageView.removeFromSuperview()
            self.typeKeyword(self.avatarSloganKeywords[nextIndex])
            self.spawnEmojiViews()
        }
    }

    private func typeKeyword(_ text: String) {
        typingTimer?.invalidate()
        sloganKeywordLabel.text = ""
        let characters = Array(text)
        var index = 0
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if index < characters.count {
                self.sloganKeywordLabel.text?.append(characters[index])
                index += 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func spawnEmojiViews() {
        let emojiCount = Int.random(in: 3...4)
        let placeCount = Int.random(in: 2...3)
        let totalCount = emojiCount + placeCount
        let shuffledEmojis = avatarEmojis[currentAvatarIndex].shuffled()
        let shuffledPlaces = avatarPlaceNames[currentAvatarIndex].shuffled()
        let bounds = avatarContainerView.bounds
        var placedFrames: [CGRect] = []

        let containerInScreen = avatarContainerView.convert(bounds, to: view)
        let screenBounds = view.bounds

        // Balanced zones: place tags first (they need more space), then emoji
        let zones = balancedZones(count: totalCount, bounds: bounds)

        var animationIndex = 0

        // Spawn place name tags FIRST so they get priority placement
        for i in 0..<placeCount {
            let placeName = shuffledPlaces[i]
            let tag = makePlaceTag(name: placeName)
            let tagSize = tag.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

            // Try assigned zone first, then fall back to all other zones
            guard let position = findPositionWithFallback(
                preferredZone: zones[animationIndex],
                bounds: bounds,
                itemSize: tagSize,
                placedFrames: placedFrames,
                containerInScreen: containerInScreen,
                screenBounds: screenBounds
            ) else { animationIndex += 1; continue }

            let frame = CGRect(x: position.x, y: position.y, width: tagSize.width, height: tagSize.height)
            placedFrames.append(frame)
            tag.frame = frame

            tag.transform = CGAffineTransform(scaleX: 0, y: 0)
            avatarContainerView.insertSubview(tag, belowSubview: avatarImageView)
            emojiViews.append(tag)

            let delay = Double(animationIndex) * 0.08
            UIView.animate(
                withDuration: 0.4, delay: delay,
                usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
                options: .curveEaseOut
            ) {
                tag.transform = .identity
            } completion: { _ in
                self.startFloating(tag)
            }

            animationIndex += 1
        }

        // Spawn emoji
        for i in 0..<emojiCount {
            let emoji = shuffledEmojis[i]
            let bubbleSize: CGFloat = CGFloat.random(in: 44...56)

            guard let position = findPositionWithFallback(
                preferredZone: zones[animationIndex],
                bounds: bounds,
                itemSize: CGSize(width: bubbleSize, height: bubbleSize),
                placedFrames: placedFrames,
                containerInScreen: containerInScreen,
                screenBounds: screenBounds
            ) else { animationIndex += 1; continue }

            let frame = CGRect(x: position.x, y: position.y, width: bubbleSize, height: bubbleSize)
            placedFrames.append(frame)

            let bubble = UIView(frame: frame)
            bubble.backgroundColor = .white
            bubble.layer.cornerRadius = bubbleSize / 2
            bubble.layer.shadowColor = UIColor.black.cgColor
            bubble.layer.shadowOpacity = 0.12
            bubble.layer.shadowOffset = CGSize(width: 0, height: 2)
            bubble.layer.shadowRadius = 4

            let label = UILabel(frame: bubble.bounds)
            label.text = emoji
            label.font = .systemFont(ofSize: bubbleSize * 0.55)
            label.textAlignment = .center
            bubble.addSubview(label)

            bubble.transform = CGAffineTransform(scaleX: 0, y: 0)
            avatarContainerView.insertSubview(bubble, belowSubview: avatarImageView)
            emojiViews.append(bubble)

            let delay = Double(animationIndex) * 0.08
            UIView.animate(
                withDuration: 0.4, delay: delay,
                usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
                options: .curveEaseOut
            ) {
                bubble.transform = .identity
            } completion: { _ in
                self.startFloating(bubble)
            }

            animationIndex += 1
        }
    }

    private func startFloating(_ view: UIView) {
        let dx = CGFloat.random(in: -4...4)
        let dy = CGFloat.random(in: -4...4)
        let duration = Double.random(in: 1.8...2.5)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut, .allowUserInteraction]
        ) {
            view.transform = CGAffineTransform(translationX: dx, y: dy)
        }
    }

    private func makePlaceTag(name: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 14
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.12
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4

        let pinIcon = UIImageView()
        pinIcon.translatesAutoresizingMaskIntoConstraints = false
        pinIcon.image = UIImage(systemName: "mappin.circle.fill")
        pinIcon.tintColor = .darkGray
        pinIcon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = name
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .darkGray

        container.addSubview(pinIcon)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            pinIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            pinIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            pinIcon.widthAnchor.constraint(equalToConstant: 16),
            pinIcon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: pinIcon.trailingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 28),
        ])

        return container
    }

    /// Returns zone indices distributed so items spread across different sides
    private func balancedZones(count: Int, bounds: CGRect) -> [Int] {
        // 0=top-left, 1=top-right, 2=left, 3=right
        var available = [0, 1, 2, 3].shuffled()
        var result: [Int] = []
        for _ in 0..<count {
            if available.isEmpty {
                available = [0, 1, 2, 3].shuffled()
            }
            result.append(available.removeFirst())
        }
        return result
    }

    private func findPositionWithFallback(
        preferredZone: Int,
        bounds: CGRect,
        itemSize: CGSize,
        placedFrames: [CGRect],
        containerInScreen: CGRect,
        screenBounds: CGRect
    ) -> CGPoint? {
        // Try preferred zone first
        if let pos = findPositionInZone(zone: preferredZone, bounds: bounds, itemSize: itemSize, placedFrames: placedFrames, containerInScreen: containerInScreen, screenBounds: screenBounds) {
            return pos
        }
        // Fall back to all other zones
        for fallback in [0, 1, 2, 3].shuffled() where fallback != preferredZone {
            if let pos = findPositionInZone(zone: fallback, bounds: bounds, itemSize: itemSize, placedFrames: placedFrames, containerInScreen: containerInScreen, screenBounds: screenBounds) {
                return pos
            }
        }
        return nil
    }

    private func findPositionInZone(
        zone: Int,
        bounds: CGRect,
        itemSize: CGSize,
        placedFrames: [CGRect],
        containerInScreen: CGRect,
        screenBounds: CGRect
    ) -> CGPoint? {
        let margin: CGFloat = 10
        let screenPadding: CGFloat = 16
        let maxY = bounds.height * 0.67 - itemSize.height

        let rawZone: (xMin: CGFloat, xMax: CGFloat, yMin: CGFloat, yMax: CGFloat)
        switch zone {
        case 0: // top-left
            rawZone = (0, bounds.width * 0.25, 0, bounds.height * 0.18)
        case 1: // top-right
            rawZone = (bounds.width * 0.6, bounds.width - itemSize.width, 0, bounds.height * 0.18)
        case 2: // left
            rawZone = (-itemSize.width * 0.3, bounds.width * 0.1, bounds.height * 0.2, maxY)
        default: // right
            rawZone = (bounds.width * 0.75, bounds.width - itemSize.width * 0.2, bounds.height * 0.2, maxY)
        }

        // Clamp so lowerBound <= upperBound
        let xMin = min(rawZone.xMin, rawZone.xMax)
        let xMax = max(rawZone.xMin, rawZone.xMax)
        let yMin = min(rawZone.yMin, rawZone.yMax)
        let yMax = max(rawZone.yMin, rawZone.yMax)

        for _ in 0..<15 {
            let x = CGFloat.random(in: xMin...xMax)
            let y = CGFloat.random(in: yMin...yMax)
            let candidate = CGRect(x: x, y: y, width: itemSize.width, height: itemSize.height)

            let overlaps = placedFrames.contains { existing in
                existing.insetBy(dx: -margin, dy: -margin).intersects(candidate)
            }
            if overlaps { continue }

            let screenRect = CGRect(
                x: containerInScreen.origin.x + x,
                y: containerInScreen.origin.y + y,
                width: itemSize.width,
                height: itemSize.height
            )
            if screenRect.minX < screenPadding ||
               screenRect.maxX > screenBounds.width - screenPadding ||
               screenRect.minY < screenPadding ||
               screenRect.maxY > screenBounds.height - screenPadding {
                continue
            }

            return CGPoint(x: x, y: y)
        }
        return nil
    }

    private func removeEmojiViews() {
        let views = emojiViews
        emojiViews.removeAll()
        for bubble in views {
            UIView.animate(withDuration: 0.2, animations: {
                bubble.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                bubble.alpha = 0
            }) { _ in
                bubble.removeFromSuperview()
            }
        }
    }

    private func checkLoginState() {
        // Check if user is already logged in
        if let currentUser = Auth.auth().currentUser {
            // User is logged in, check if they have a profile
            UserManager.shared.getUser(id: currentUser.uid) { [weak self] user, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if user != nil {
                        // User exists, replace root with home screen
                        self.transitionToHome()
                    } else {
                        // User doesn't have a profile yet, show login UI
                        self.setupLoginStyle()
                    }
                }
            }
        } else {
            // No user logged in, show login UI after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.setupLoginStyle()
            }
        }
    }
    
    private func setupSocialButton(button: CustomGlassButton, iconName: String, title: String) {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        if iconName == "applelogo" {
            // Use SF Symbol for Apple logo
            iconImageView.image = UIImage(systemName: "apple.logo")?.withRenderingMode(.alwaysTemplate)
        } else {
            // Use asset catalog for other icons
            iconImageView.image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
        }
        iconImageView.tintColor = .firstColor
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .firstColor
        
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconName == "applelogo" ? 24 : 20),
            iconImageView.heightAnchor.constraint(equalToConstant: iconName == "applelogo" ? 24 : 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        button.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }
    
    // MARK: - Helper Methods
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            Logger.log("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)", level: .error, category: "Login")
            return ""
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func showLoading() {
        loadingView.isHidden = false
        [appleButton, googleButton].forEach { $0.isEnabled = false }
    }
    
    private func hideLoading() {
        loadingView.isHidden = true
        [appleButton, googleButton].forEach { $0.isEnabled = true }
    }
    
    private func checkExistingUserAndNavigate() {
        guard let firebaseUser = Auth.auth().currentUser else {
            Logger.log("No user is signed in", level: .debug, category: "Login")
            hideLoading()
            return
        }
        
        UserManager.shared.getUser(id: firebaseUser.uid) { [weak self] user, error in
            guard let self = self else { return }
            self.hideLoading()
            
            if let error = error {
                Logger.log("Error checking user: \(error.localizedDescription)", level: .error, category: "Login")
                self.showError(message: String(localized: "login_error_check_user"))
                return
            }
            
            if user != nil {
                Logger.log("User already exists, navigating to home screen", level: .debug, category: "Login")
                self.transitionToHome()
            } else {
                Logger.log("New user, navigating to name registration", level: .debug, category: "Login")
                let nameRegistrationVC = NameRegistrationViewController()
                nameRegistrationVC.modalPresentationStyle = .fullScreen
                self.present(nameRegistrationVC, animated: true)
            }
        }
    }
    
    private func transitionToHome() {
        guard let window = view.window else { return }
        let homeViewController = HomeViewController()
        let navigationController = UINavigationController(rootViewController: homeViewController)
        
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = navigationController
        } completion: { _ in
            self.sceneDelegate?.didFinishAuthentication()
        }
    }
    
    private func showError(message: String) {
        let messageModal = MessageModalViewController(title: String(localized: "modal_error_title"), message: message)
        present(messageModal, animated: true)
    }
    
    // MARK: - Actions
    @objc private func googleButtonTapped() {
        showLoading()
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            hideLoading()
            showError(message: String(localized: "login_error_google_config"))
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Google Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
                self.hideLoading()
                // Check if user cancelled
                if let gidError = error as NSError?,
                   gidError.domain == "com.google.GIDSignIn",
                   gidError.code == -5 { // GIDSignInErrorCode.canceled
                    // User cancelled - don't show error
                    return
                }
                self.showError(message: String(format: String(localized: "login_error_google_signin_format"), error.localizedDescription))
                return
            }
            
            guard let authentication = result?.user,
                  let idToken = authentication.idToken?.tokenString else {
                Logger.log("Failed to get Google credentials", level: .error, category: "Login")
                self.hideLoading()
                self.showError(message: String(localized: "login_error_google_credentials"))
                return
            }
            
            // accessToken is non-optional GIDToken, so we can access it directly
            let accessTokenString = authentication.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessTokenString
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Firebase Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
                    self.hideLoading()
                    self.showError(message: String(format: String(localized: "login_error_firebase_auth_format"), error.localizedDescription))
                    return
                }
                
                Logger.log("Successfully signed in with Google", level: .info, category: "Login")
                self.checkExistingUserAndNavigate()
            }
        }
    }
    
    @objc private func appleButtonTapped() {
        showLoading()
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                Logger.log("Invalid state: A login callback was received, but no login request was sent.", level: .error, category: "Login")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                Logger.log("Unable to fetch identity token", level: .debug, category: "Login")
                hideLoading()
                return
            }
            
            let credential = OAuthProvider.credential(
                providerID: .apple,
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.log("Firebase Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
                    self.hideLoading()
                    return
                }
                
                Logger.log("Successfully signed in with Apple", level: .info, category: "Login")
                self.checkExistingUserAndNavigate()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.log("Apple Sign In error: \(error.localizedDescription)", level: .error, category: "Login")
        hideLoading()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: - UITextViewDelegate
extension LoginViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "nose" {
            if URL.host == "terms" {
                let termsVC = ToSViewController()
                termsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPresentedPolicyOrTerms))
                let nav = UINavigationController(rootViewController: termsVC)
                present(nav, animated: true)
            } else if URL.host == "privacy" {
                let privacyVC = PrivacyPolicyViewController()
                privacyVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPresentedPolicyOrTerms))
                let nav = UINavigationController(rootViewController: privacyVC)
                present(nav, animated: true)
            }
            return false
        }
        return true
    }
    
    @objc private func dismissPresentedPolicyOrTerms() {
        presentedViewController?.dismiss(animated: true)
    }
} 
