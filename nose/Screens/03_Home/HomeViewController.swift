import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces

final class HomeViewController: UIViewController {
    
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var searchResults: [GMSPlace] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var currentLocationMarker: GMSMarker?
    private var currentDotIndex: Int = 1  // Track current dot index (0: left, 1: middle, 2: right)
    
    // Add properties to track dots and line
    private var leftDot: UIView?
    private var middleDot: UIView?
    private var rightDot: UIView?
    private var dotLine: UIView?
    private var containerView: UIView?
    
    private var mapManager: MapManager?
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var dotSlider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        
        // Create container view for dots and line
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        container.layer.cornerRadius = 27.5  // Half of height for perfect round
        view.addSubview(container)
        self.containerView = container
        
        // Create the line
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .firstColor
        container.addSubview(line)
        self.dotLine = line
        
        // Create the dots - middle one selected by default
        let dot1 = createDot(isSelected: false)
        let dot2 = createDot(isSelected: true)  // Middle dot selected
        let dot3 = createDot(isSelected: false)
        
        // Add tap gestures to individual dots
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
        
        dot1.addGestureRecognizer(tap1)
        dot2.addGestureRecognizer(tap2)
        dot3.addGestureRecognizer(tap3)
        
        container.addSubview(dot1)
        container.addSubview(dot2)
        container.addSubview(dot3)
        
        // Store references to dots
        self.leftDot = dot1
        self.middleDot = dot2
        self.rightDot = dot3
        
        // Add swipe gesture recognizers
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        container.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        container.addGestureRecognizer(rightSwipe)
        
        return view
    }()
    
    private func createDot(isSelected: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true  // Enable interaction for container
        
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = .firstColor
        dot.layer.cornerRadius = 6
        dot.isUserInteractionEnabled = true  // Enable interaction for dot
        
        container.addSubview(dot)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        if isSelected {
            container.layer.borderWidth = 2
            container.layer.borderColor = UIColor.firstColor.cgColor
            container.layer.cornerRadius = 10
        }
        
        return container
    }
    
    private lazy var profileButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "person.fill"), for: .normal)
        button.tintColor = .firstColor
        button.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        button.layer.cornerRadius = 27.5
        button.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        button.tintColor = .firstColor
        button.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        button.layer.cornerRadius = 27.5
        button.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var sparkButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "sparkle"), for: .normal)
        button.tintColor = .firstColor
        button.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        button.layer.cornerRadius = 27.5
        button.addTarget(self, action: #selector(sparkButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private lazy var boxButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "archivebox.fill"), for: .normal)
        button.tintColor = .firstColor
        button.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        button.layer.cornerRadius = 27.5
        button.addTarget(self, action: #selector(boxButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private lazy var mapView: GMSMapView = {
        let camera = GMSCameraPosition.camera(
            withLatitude: 35.6812,  // Tokyo coordinates as default
            longitude: 139.7671,
            zoom: 15
        )
        
        // Create map options with Map ID
        let mapOptions = GMSMapViewOptions()
        mapOptions.camera = camera
        mapOptions.frame = .zero
        mapOptions.mapID = GMSMapID(identifier: "7f9a1d61a6b1809f")
        
        let mapView = GMSMapView(options: mapOptions)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.settings.myLocationButton = false  // Disable default location button
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.delegate = self
        return mapView
    }()
    
    private lazy var searchResultsTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.isHidden = true
        tableView.layer.cornerRadius = 8
        tableView.layer.masksToBounds = true
        return tableView
    }()
    
    private lazy var currentLocationButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "location.fill"), for: .normal)
        button.backgroundColor = .white
        button.tintColor = .firstColor
        button.layer.cornerRadius = 27.5
        button.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        button.addTarget(self, action: #selector(currentLocationButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var messageView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        view.layer.cornerRadius = 12
        view.alpha = 0
        // Add shadow
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .black.withAlphaComponent(0.7)
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocationManager()
        sessionToken = GMSAutocompleteSessionToken()
        mapManager = MapManager(mapView: mapView)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Add subviews in correct order
        view.addSubview(mapView)
        view.addSubview(headerView)
        view.addSubview(dotSlider)
        view.addSubview(searchButton)
        view.addSubview(sparkButton)
        view.addSubview(boxButton)
        view.addSubview(searchResultsTableView)
        view.addSubview(currentLocationButton)
        view.addSubview(profileButton)
        view.addSubview(messageView)
        messageView.addSubview(titleLabel)
        messageView.addSubview(subtitleLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Map view constraints
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header view constraints
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: dotSlider.bottomAnchor, constant: 16),
            
            // Dot slider constraints
            dotSlider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            dotSlider.heightAnchor.constraint(equalToConstant: 55),
            
            // Container view constraints
            containerView!.topAnchor.constraint(equalTo: dotSlider.topAnchor),
            containerView!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView!.heightAnchor.constraint(equalToConstant: 55),
            
            // Line constraints
            dotLine!.centerYAnchor.constraint(equalTo: containerView!.centerYAnchor),
            dotLine!.leadingAnchor.constraint(equalTo: leftDot!.centerXAnchor),
            dotLine!.trailingAnchor.constraint(equalTo: rightDot!.centerXAnchor),
            dotLine!.heightAnchor.constraint(equalToConstant: 2),
            
            // Dot constraints
            leftDot!.centerYAnchor.constraint(equalTo: containerView!.centerYAnchor),
            leftDot!.leadingAnchor.constraint(equalTo: containerView!.leadingAnchor, constant: 16),
            leftDot!.widthAnchor.constraint(equalToConstant: 20),
            leftDot!.heightAnchor.constraint(equalToConstant: 20),
            
            middleDot!.centerYAnchor.constraint(equalTo: containerView!.centerYAnchor),
            middleDot!.centerXAnchor.constraint(equalTo: containerView!.centerXAnchor),
            middleDot!.widthAnchor.constraint(equalToConstant: 20),
            middleDot!.heightAnchor.constraint(equalToConstant: 20),
            
            rightDot!.centerYAnchor.constraint(equalTo: containerView!.centerYAnchor),
            rightDot!.trailingAnchor.constraint(equalTo: containerView!.trailingAnchor, constant: -16),
            rightDot!.widthAnchor.constraint(equalToConstant: 20),
            rightDot!.heightAnchor.constraint(equalToConstant: 20),
            
            // Profile button constraints
            profileButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            profileButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            profileButton.widthAnchor.constraint(equalToConstant: 55),
            profileButton.heightAnchor.constraint(equalToConstant: 55),
            
            // Search button constraints
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchButton.widthAnchor.constraint(equalToConstant: 55),
            searchButton.heightAnchor.constraint(equalToConstant: 55),
            
            // Box button constraints
            boxButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            boxButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            boxButton.widthAnchor.constraint(equalToConstant: 55),
            boxButton.heightAnchor.constraint(equalToConstant: 55),
            
            // Spark button constraints
            sparkButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            sparkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sparkButton.widthAnchor.constraint(equalToConstant: 55),
            sparkButton.heightAnchor.constraint(equalToConstant: 55),
            
            // Search results table view constraints
            searchResultsTableView.topAnchor.constraint(equalTo: searchButton.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchResultsTableView.heightAnchor.constraint(equalToConstant: 200),
            
            // Current location button constraints
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            currentLocationButton.widthAnchor.constraint(equalToConstant: 50),
            currentLocationButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Message view constraints
            messageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -64),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -24),
            
            // Subtitle label constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -24),
            subtitleLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Actions
    @objc private func currentLocationButtonTapped() {
        mapManager?.moveToCurrentLocation()
    }
    
    @objc private func profileButtonTapped() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        let searchViewController = SearchViewController()
        searchViewController.delegate = self
        searchViewController.modalPresentationStyle = .fullScreen
        present(searchViewController, animated: true)
    }
    
    @objc private func sparkButtonTapped() {
        let collectionsVC = CollectionsViewController()
        if let sheet = collectionsVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(collectionsVC, animated: true)
    }
    
    @objc private func boxButtonTapped() {
        let boxVC = BoxViewController()
        if let sheet = boxVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(boxVC, animated: true)
    }
    
    private func showMessage(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        // Fade in
        UIView.animate(withDuration: 0.3, animations: {
            self.messageView.alpha = 1
        }) { _ in
            // Fade out after delay
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                self.messageView.alpha = 0
            })
        }
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let newIndex: Int
        
        switch gesture.direction {
        case .left:
            newIndex = min(currentDotIndex + 1, 2)
        case .right:
            newIndex = max(currentDotIndex - 1, 0)
        default:
            return
        }
        
        if newIndex != currentDotIndex {
            switchToDot(at: newIndex)
        }
    }
    
    private func switchToDot(at index: Int) {
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Update dots
        leftDot?.layer.borderWidth = index == 0 ? 2 : 0
        leftDot?.layer.borderColor = index == 0 ? UIColor.firstColor.cgColor : nil
        leftDot?.layer.cornerRadius = index == 0 ? 10 : 0
        
        middleDot?.layer.borderWidth = index == 1 ? 2 : 0
        middleDot?.layer.borderColor = index == 1 ? UIColor.firstColor.cgColor : nil
        middleDot?.layer.cornerRadius = index == 1 ? 10 : 0
        
        rightDot?.layer.borderWidth = index == 2 ? 2 : 0
        rightDot?.layer.borderColor = index == 2 ? UIColor.firstColor.cgColor : nil
        rightDot?.layer.cornerRadius = index == 2 ? 10 : 0
        
        // Update current index
        currentDotIndex = index
        
        // Always show the map view
        mapView.isHidden = false
        
        // Show message based on selected dot
        switch index {
        case 0:
            showMessage(title: "Past", subtitle: "relive the moments")
        case 1:
            showMessage(title: "Current", subtitle: "explore what's happening")
        case 2:
            showMessage(title: "Future", subtitle: "plan and get ready")
        default:
            break
        }
        
        // Handle different dot selections with fade animation
        UIView.animate(withDuration: 0.3, animations: {
            switch index {
            case 0: // Left dot - show box
                self.searchButton.alpha = 0
                self.sparkButton.alpha = 0
                self.boxButton.alpha = 1
                self.boxButton.isHidden = false
            case 1: // Middle dot - show search
                self.searchButton.alpha = 1
                self.sparkButton.alpha = 0
                self.boxButton.alpha = 0
                self.searchButton.isHidden = false
            case 2: // Right dot - show collections
                self.searchButton.alpha = 0
                self.sparkButton.alpha = 1
                self.boxButton.alpha = 0
                self.sparkButton.isHidden = false
            default:
                break
            }
        }) { _ in
            // Update visibility after fade
            self.searchButton.isHidden = index != 1
            self.sparkButton.isHidden = index != 2
            self.boxButton.isHidden = index != 0
        }
    }
    
    @objc private func dotTapped(_ gesture: UITapGestureRecognizer) {
        guard let dot = gesture.view else { return }
        
        // Determine which dot was tapped
        let segment: Int
        if dot == leftDot {
            segment = 0
        } else if dot == middleDot {
            segment = 1
        } else if dot == rightDot {
            segment = 2
        } else {
            return
        }
        
        print("Dot tapped: \(segment)")  // Debug print
        
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Update current index
        currentDotIndex = segment
        
        // Update dots using stored references
        leftDot?.layer.borderWidth = segment == 0 ? 2 : 0
        leftDot?.layer.borderColor = segment == 0 ? UIColor.firstColor.cgColor : nil
        leftDot?.layer.cornerRadius = segment == 0 ? 10 : 0
        
        middleDot?.layer.borderWidth = segment == 1 ? 2 : 0
        middleDot?.layer.borderColor = segment == 1 ? UIColor.firstColor.cgColor : nil
        middleDot?.layer.cornerRadius = segment == 1 ? 10 : 0
        
        rightDot?.layer.borderWidth = segment == 2 ? 2 : 0
        rightDot?.layer.borderColor = segment == 2 ? UIColor.firstColor.cgColor : nil
        rightDot?.layer.cornerRadius = segment == 2 ? 10 : 0
        
        // Always show the map view
        mapView.isHidden = false
        
        // Show message based on selected dot
        switch segment {
        case 0:
            showMessage(title: "Past", subtitle: "relive the moments")
        case 1:
            showMessage(title: "Current", subtitle: "explore what's happening")
        case 2:
            showMessage(title: "Future", subtitle: "plan and get ready")
        default:
            break
        }
        
        // First hide all buttons
        searchButton.isHidden = true
        sparkButton.isHidden = true
        boxButton.isHidden = true
        
        // Then show and animate the appropriate button
        UIView.animate(withDuration: 0.3, animations: {
            switch segment {
            case 0: // Left dot - show box
                self.boxButton.alpha = 1
                self.boxButton.isHidden = false
                self.searchButton.alpha = 0
                self.sparkButton.alpha = 0
            case 1: // Middle dot - show search
                self.searchButton.alpha = 1
                self.searchButton.isHidden = false
                self.sparkButton.alpha = 0
                self.boxButton.alpha = 0
            case 2: // Right dot - show collections
                self.sparkButton.alpha = 1
                self.sparkButton.isHidden = false
                self.searchButton.alpha = 0
                self.boxButton.alpha = 0
            default:
                break
            }
        })
    }
    
    // MARK: - Helper Methods
    private func searchPlaces(query: String) {
        mapManager?.searchPlaces(query: query) { [weak self] results in
            self?.searchResults = results
            self?.searchResultsTableView.reloadData()
        }
    }
    
    private func showPlaceOnMap(_ place: GMSPlace) {
        mapManager?.showPlaceOnMap(place)
        
        // Present place detail view controller
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        
        // Add a slight delay to ensure proper presentation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.present(detailViewController, animated: true)
        }
    }
    
    private func updateCurrentLocationMarker(at location: CLLocation) {
        // Remove existing marker if any
        currentLocationMarker?.map = nil
        
        // Create custom marker
        let marker = GMSMarker(position: location.coordinate)
        
        // Create custom marker view
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        markerView.backgroundColor = .clear
        
        // Create outer circle (pulse effect)
        let outerCircle = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        outerCircle.backgroundColor = UIColor.firstColor.withAlphaComponent(0.2)
        outerCircle.layer.cornerRadius = 20
        outerCircle.layer.masksToBounds = true
        markerView.addSubview(outerCircle)
        
        // Create inner circle (solid)
        let innerCircle = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        innerCircle.backgroundColor = .firstColor
        innerCircle.layer.cornerRadius = 10
        innerCircle.layer.masksToBounds = true
        markerView.addSubview(innerCircle)
        
        // Add pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.2
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        // Ensure the animation maintains the circular shape
        outerCircle.layer.add(pulseAnimation, forKey: "pulse")
        outerCircle.layer.allowsEdgeAntialiasing = true
        
        // Set the custom marker view
        marker.iconView = markerView
        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        marker.map = mapView
        
        // Store reference to marker
        currentLocationMarker = marker
    }
}

// MARK: - UISearchBarDelegate
extension HomeViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults = []
            searchResultsTableView.isHidden = true
            return
        }
        
        searchResultsTableView.isHidden = false
        searchPlaces(query: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let place = searchResults[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = place.name
        content.secondaryText = place.formattedAddress
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let place = searchResults[indexPath.row]
        showPlaceOnMap(place)
    }
}

// MARK: - CLLocationManagerDelegate
extension HomeViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            mapView.isMyLocationEnabled = true
        case .denied, .restricted:
            // Show alert to enable location services
            let alert = UIAlertController(
                title: "Location Access Required",
                message: "Please enable location access in Settings to use this feature.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Update custom marker
        updateCurrentLocationMarker(at: location)
        
        // Update camera position to user's location
        let camera = GMSCameraPosition.camera(
            withLatitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            zoom: 15
        )
        mapView.animate(to: camera)
        
        // Stop updating location after first update
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

// MARK: - GMSMapViewDelegate
extension HomeViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        // Hide search results when tapping on the map
        searchResultsTableView.isHidden = true
    }
    
    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        print("Map style successfully loaded")
    }
}

// MARK: - SearchViewControllerDelegate
extension HomeViewController: SearchViewControllerDelegate {
    func searchViewController(_ controller: SearchViewController, didSelectPlace place: GMSPlace) {
        showPlaceOnMap(place)
    }
}
