import UIKit
import GoogleMaps
import CoreLocation
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth

final class HomeViewController: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let standardPadding: CGFloat = 16
        static let buttonSize: CGFloat = 55
        static let searchResultsHeight: CGFloat = 200
        static let messageViewPadding: CGFloat = 24
        static let messageViewSpacing: CGFloat = 8
    }
    
    // MARK: - Properties
    private var searchResults: [GMSPlace] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var currentDotIndex: Int = 1  // Track current dot index (0: left, 1: middle, 2: right)
    private var collections: [PlaceCollection] = []
    
    // Add properties to track dots and line
    private var leftDot: UIView?
    private var middleDot: UIView?
    private var rightDot: UIView?
    private var dotLine: UIView?
    private var containerView: UIView?
    
    private var mapManager: GoogleMapManager?
    private var searchManager: SearchManager?
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var dotSlider: TimelineSliderView = {
        let view = TimelineSliderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private lazy var profileButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "person.fill"),
            action: #selector(profileButtonTapped),
            target: self
        )
    }()
    
    private lazy var searchButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "magnifyingglass"),
            action: #selector(searchButtonTapped),
            target: self
        )
    }()
    
    private lazy var sparkButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "sparkle"),
            action: #selector(sparkButtonTapped),
            target: self
        )
    }()
    
    private lazy var boxButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "archivebox.fill"),
            action: #selector(boxButtonTapped),
            target: self
        )
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
    
    private lazy var currentLocationButton: IconButton = {
        IconButton(
            image: UIImage(systemName: "location.fill"),
            action: #selector(currentLocationButtonTapped),
            target: self,
            size: Constants.buttonSize
        )
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
        setupManagers()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        setupSubviews()
        setupConstraints()
        
        // Set initial button visibility based on default selected dot (middle dot, index 1)
        searchButton.isHidden = false
        searchButton.alpha = 1
        sparkButton.isHidden = true
        sparkButton.alpha = 0
        boxButton.isHidden = true
        boxButton.alpha = 0
    }
    
    private func setupSubviews() {
        [mapView, headerView, dotSlider, searchButton, sparkButton, boxButton,
         searchResultsTableView, currentLocationButton, profileButton, messageView].forEach {
            view.addSubview($0)
        }
        
        [titleLabel, subtitleLabel].forEach {
            messageView.addSubview($0)
        }
    }
    
    private func setupConstraints() {
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
            dotSlider.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            dotSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dotSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Profile button constraints
            profileButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            profileButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            profileButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            profileButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Search button constraints
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            searchButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            searchButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Box button constraints
            boxButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            boxButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            boxButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            boxButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Spark button constraints
            sparkButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            sparkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            sparkButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            sparkButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Search results table view constraints
            searchResultsTableView.topAnchor.constraint(equalTo: searchButton.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.standardPadding),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            searchResultsTableView.heightAnchor.constraint(equalToConstant: Constants.searchResultsHeight),
            
            // Current location button constraints
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.standardPadding),
            currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.standardPadding),
            currentLocationButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            currentLocationButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // Message view constraints
            messageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -64),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: Constants.messageViewPadding),
            titleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: Constants.messageViewPadding),
            titleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -Constants.messageViewPadding),
            
            // Subtitle label constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Constants.messageViewSpacing),
            subtitleLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: Constants.messageViewPadding),
            subtitleLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -Constants.messageViewPadding),
            subtitleLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -Constants.messageViewPadding)
        ])
    }
    
    private func setupManagers() {
        sessionToken = GMSAutocompleteSessionToken()
        mapManager = GoogleMapManager(mapView: mapView)
        searchManager = SearchManager()
        searchManager?.delegate = self
        
        // Load collections
        loadCollections()
    }
    
    private func loadCollections() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        CollectionManager.shared.fetchCollections(userId: userId) { [weak self] result in
            switch result {
            case .success(let collections):
                self?.collections = collections
                print("✅ Loaded \(collections.count) collections")
            case .failure(let error):
                print("❌ Failed to load collections: \(error.localizedDescription)")
                self?.showMessage(title: "Error", subtitle: "Failed to load collections")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func currentLocationButtonTapped() {
        mapManager?.moveToCurrentLocation()
    }
    
    @objc private func profileButtonTapped() {
        let settingVC = SettingsViewController()
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        let searchVC = SearchViewController()
        searchVC.delegate = self
        searchVC.modalPresentationStyle = .fullScreen
        present(searchVC, animated: true)
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
    
    // MARK: - Helper Methods
    private func searchPlaces(query: String) {
        mapManager?.searchPlaces(query: query) { [weak self] (results: [GMSPlace]) in
            self?.searchResults = results
            self?.searchResultsTableView.reloadData()
        }
    }
    
    private func showPlaceOnMap(_ place: GMSPlace) {
        mapManager?.showPlaceOnMap(place)
        
        // Create a Place object from GMSPlace
        let placeData: [String: Any] = [
            "id": UUID().uuidString,
            "name": place.name ?? "",
            "latitude": place.coordinate.latitude,
            "longitude": place.coordinate.longitude,
            "address": place.formattedAddress ?? "",
            "placeId": place.placeID ?? "",
            "types": place.types ?? [],
            "rating": place.rating,
            "userRatingsTotal": place.userRatingsTotal,
            "priceLevel": place.priceLevel.rawValue,
            "photos": (place.photos ?? []).map { photo in
                [
                    "width": photo.maxSize.width,
                    "height": photo.maxSize.height,
                    "attributions": photo.attributions?.string ?? ""
                ]
            },
            "createdAt": Timestamp(date: Date())
        ]
        
        // Present place detail view controller
        let detailViewController = PlaceDetailViewController(place: place, isFromCollection: false)
        
        // Add a slight delay to ensure proper presentation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.present(detailViewController, animated: true)
        }
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

// MARK: - TimelineSliderViewDelegate
extension HomeViewController: TimelineSliderViewDelegate {
    func timelineSliderView(_ view: TimelineSliderView, didSelectDotAt index: Int) {
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
        
        // First hide all buttons
        searchButton.isHidden = true
        sparkButton.isHidden = true
        boxButton.isHidden = true
        
        // Then show and animate the appropriate button
        UIView.animate(withDuration: 0.3, animations: {
            switch index {
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
}

// MARK: - SearchManagerDelegate
extension HomeViewController: SearchManagerDelegate {
    func searchManager(_ manager: SearchManager, didUpdateResults results: [GMSPlace]) {
        searchResults = results
        searchResultsTableView.reloadData()
    }
    
    func searchManager(_ manager: SearchManager, didSelectPlace place: GMSPlace) {
        showPlaceOnMap(place)
    }
}
