import UIKit
import GoogleMaps
import GooglePlaces

class MapContainerViewController: UIViewController {

    var mapView: GMSMapView!
    var slider: CustomSlider!
    private let shadowBackground = BackShadowView()
    var profileButton: IconButton!
    var buttonA: IconButton!
    var searchButton: IconButton!
    var savedButton: IconButton!
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private var isFirstTouch = true

    var mapID = GMSMapID(identifier: "7f9a1d61a6b1809f")

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupShadowBackground()
        setupSlider()
        setupProfileButton()
        setupButtonA()
        setupSearchButton()
        setupSavedButton()
        setupConstraints()

        // Prepare the feedback generator
        feedbackGenerator.prepare()

        // Ensure the correct button is displayed based on the initial slider value
        sliderValueChanged(slider)
    }

    private func setupMapView() {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12.0)
        mapView = GMSMapView(frame: self.view.bounds, mapID: mapID, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        view.addSubview(mapView)
        view.sendSubviewToBack(mapView)
    }

    private func setupShadowBackground() {
        shadowBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shadowBackground)

        NSLayoutConstraint.activate([
            shadowBackground.topAnchor.constraint(equalTo: view.topAnchor),
            shadowBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            shadowBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shadowBackground.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.22)
        ])
    }

    private func setupSlider() {
        slider = CustomSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(slider)

        // Add target-action pair to the slider
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchDown(_:)), for: .touchDown)
    }

    private func setupProfileButton() {
        profileButton = IconButton(image: UIImage(systemName: "person.fill"), action: #selector(dummyAction), target: self)
        view.addSubview(profileButton)
    }

    private func setupButtonA() {
        buttonA = IconButton(image: UIImage(systemName: "archivebox.fill"), action: #selector(reflectButtonTapped), target: self)
        buttonA.setTitle("Reflect", for: .normal)
        buttonA.setTitleColor(.black, for: .normal)
        buttonA.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        buttonA.tintColor = .label
        buttonA.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        buttonA.contentHorizontalAlignment = .leading
        view.addSubview(buttonA)
    }

    private func setupSearchButton() {
        searchButton = IconButton(image: UIImage(systemName: "magnifyingglass"), action: #selector(dummyAction), target: self)
        searchButton.setTitle("Explore", for: .normal)
        searchButton.setTitleColor(.black, for: .normal)
        searchButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        searchButton.tintColor = .label
        searchButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        searchButton.contentHorizontalAlignment = .leading
        searchButton.isHidden = true // Initially hidden
        view.addSubview(searchButton)
    }

    private func setupSavedButton() {
        savedButton = IconButton(image: UIImage(systemName: "sparkle"), action: #selector(savedButtonTapped), target: self)
        savedButton.setTitle("Gear up", for: .normal)
        savedButton.setTitleColor(.black, for: .normal)
        savedButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        savedButton.tintColor = .label
        savedButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        savedButton.contentHorizontalAlignment = .leading
        savedButton.isHidden = true // Initially hidden
        view.addSubview(savedButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Profile button at the top-left corner
            profileButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            profileButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),

            // ButtonA at the top-right corner
            buttonA.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            buttonA.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            buttonA.widthAnchor.constraint(greaterThanOrEqualToConstant: 100), // Ensure enough width for text

            // Search button at the top-right corner (same position as buttonA)
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            searchButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100), // Ensure enough width for text

            // Saved button at the top-right corner (same position as buttonA)
            savedButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            savedButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            savedButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 105), // Ensure enough width for text

            // Slider closer to the buttons
            slider.topAnchor.constraint(equalTo: buttonA.bottomAnchor, constant: 10),
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func dummyAction() {
        // Dummy action to satisfy selector requirement
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        // Using threshold comparison instead of exact value checking
        let epsilon: Float = 0.5 // Small threshold for floating point comparison

        if abs(sender.value - 0) < epsilon || abs(sender.value - 50) < epsilon || abs(sender.value - 100) < epsilon {
            feedbackGenerator.impactOccurred()
            feedbackGenerator.prepare() // Prepare for the next impact
        }

        UIView.transition(with: buttonA, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.buttonA.isHidden = !(sender.value == 0)
        })

        UIView.transition(with: searchButton, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.searchButton.isHidden = !(sender.value == 50)
        })

        UIView.transition(with: savedButton, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.savedButton.isHidden = !(sender.value == 100)
        })
    }

    @objc private func sliderTouchDown(_ sender: UISlider) {
        if isFirstTouch {
            feedbackGenerator.impactOccurred()
            feedbackGenerator.prepare() // Prepare for the next impact
            isFirstTouch = false
        }
    }

    @objc private func savedButtonTapped() {
        let savedBookmarksVC = SavedBookmarksViewController()
        let navigationController = UINavigationController(rootViewController: savedBookmarksVC)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
    }

    @objc private func reflectButtonTapped() {
        let pastMapVC = PastMapMainViewController()
        let navigationController = UINavigationController(rootViewController: pastMapVC)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(navigationController, animated: true, completion: nil)
    }
}
