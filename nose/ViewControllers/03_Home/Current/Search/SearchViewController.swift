import UIKit
import GooglePlaces
import FirebaseFirestore

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ controller: SearchViewController, didSelectPlace place: GMSPlace)
}

enum SearchResult {
    case place(GMSAutocompletePrediction)
    case event(Event)
}

final class SearchViewController: UIViewController {
    
    // MARK: - Properties
    private var searchResults: [SearchResult] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    
    weak var delegate: SearchViewControllerDelegate?
    
    // MARK: - UI Components
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search for places or events"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.becomeFirstResponder()
        return searchBar
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .fourthColor
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        return tableView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        sessionToken = GMSAutocompleteSessionToken()
        
        // Make the view controller full screen
        modalPresentationStyle = .fullScreen
        // Prevent swipe-to-dismiss
        isModalInPresentation = true
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .firstColor
        
        // Add subviews
        view.addSubview(searchBar)
        view.addSubview(closeButton)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Close button constraints
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.sm),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Search bar constraints
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            searchBar.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -DesignTokens.Spacing.sm),
            
            // Table view constraints
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    private func searchPlaces(query: String) {
        // Clear previous results
        searchResults = []
        tableView.reloadData()
        
        // Search both places and events in parallel
        let dispatchGroup = DispatchGroup()
        var placeResults: [SearchResult] = []
        var eventResults: [SearchResult] = []
        
        // Search places using Google Places API
        dispatchGroup.enter()
        PlacesAPIManager.shared.debouncedSearch(query: query) { (results: [GMSAutocompletePrediction]) in
            placeResults = results.map { .place($0) }
            dispatchGroup.leave()
        }
        
        // Search events in Firestore
        dispatchGroup.enter()
        searchEvents(query: query) { events in
            eventResults = events.map { .event($0) }
            dispatchGroup.leave()
        }
        
        // Combine results when both searches complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            // Events first, then places
            self?.searchResults = eventResults + placeResults
            self?.tableView.reloadData()
        }
    }
    
    private func searchEvents(query: String, completion: @escaping ([Event]) -> Void) {
        // Search current and future events by title
        Task {
            do {
                let allEvents = try await EventManager.shared.fetchAllCurrentAndFutureEvents()
                let filtered = allEvents.filter { event in
                    event.title.lowercased().contains(query.lowercased()) ||
                    event.location.name.lowercased().contains(query.lowercased()) ||
                    event.location.address.lowercased().contains(query.lowercased())
                }
                completion(filtered)
            } catch {
                Logger.log("Error searching events: \(error.localizedDescription)", level: .error, category: "Search")
                completion([])
            }
        }
    }
    
    private func fetchPlaceDetails(for prediction: GMSAutocompletePrediction) {
        // Use user interaction priority for search selection
        PlacesAPIManager.shared.fetchPlaceDetailsForUserInteraction(
            placeID: prediction.placeID,
            fields: PlacesAPIManager.FieldConfig.search
        ) { [weak self] place in
            if let place = place {
                Logger.log("Fetched place: \(place.name ?? "Unknown")", level: .info, category: "Search")
                Logger.log("Place ID: \(place.placeID ?? "nil")", level: .debug, category: "Search")
                Logger.log("Photos: \(place.photos?.count ?? 0) rating: \(place.rating) phone? \(place.phoneNumber != nil) hours? \(place.openingHours != nil)", level: .debug, category: "Search")
                
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    if let delegate = strongSelf.delegate {
                        delegate.searchViewController(strongSelf, didSelectPlace: place)
                        strongSelf.dismiss(animated: true)
                    } else {
                        strongSelf.presentPlaceDetail(place)
                    }
                }
            } else {
                Logger.log("Failed to fetch place details for: \(prediction.placeID)", level: .warn, category: "Search")
            }
        }
    }
    
    // Public: programmatically open a place by ID (used by deep links)
    func openPlace(withId placeId: String) {
        PlacesAPIManager.shared.fetchDetailPlaceDetails(placeID: placeId) { [weak self] fetchedPlace in
            guard let self = self, let place = fetchedPlace else { return }
            DispatchQueue.main.async {
                if let delegate = self.delegate {
                    delegate.searchViewController(self, didSelectPlace: place)
                    self.dismiss(animated: true)
                } else {
                    self.presentPlaceDetail(place)
                }
            }
        }
    }

    // Public: programmatically search by text and open the first result
    func startSearchAndAutoOpenFirst(query: String) {
        searchBar.text = query
        PlacesAPIManager.shared.debouncedSearch(query: query) { [weak self] (results: [GMSAutocompletePrediction]) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.searchResults = results.map { .place($0) }
                self.tableView.reloadData()
                if let first = results.first {
                    self.fetchPlaceDetails(for: first)
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults = []
            tableView.reloadData()
            return
        }
        
        searchPlaces(query: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension SearchViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let result = searchResults[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        
        switch result {
        case .place(let prediction):
            content.text = prediction.attributedPrimaryText.string
            content.secondaryText = prediction.attributedSecondaryText?.string
            content.image = UIImage(systemName: "mappin.circle.fill")
            content.imageProperties.tintColor = .fourthColor
            
        case .event(let event):
            content.text = event.title
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd, HH:mm"
            let dateString = dateFormatter.string(from: event.dateTime.startDate)
            content.secondaryText = "⚡ \(dateString) • \(event.location.name)"
            content.image = UIImage(systemName: "bolt.fill")
            content.imageProperties.tintColor = .fifthColor
        }
        
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let result = searchResults[indexPath.row]
        
        switch result {
        case .place(let prediction):
            fetchPlaceDetails(for: prediction)
            
        case .event(let event):
            presentEventDetail(event)
        }
    }
}

// MARK: - Presentation Helpers
private extension SearchViewController {
    func presentPlaceDetail(_ place: GMSPlace) {
        let detailVC = PlaceDetailViewController(place: place, isFromCollection: false)
        // If this VC was presented modally, dismiss it first, then present from the presenter to avoid stacking
        if let presenter = self.presentingViewController {
            self.dismiss(animated: true) {
                if let nav = presenter as? UINavigationController {
                    nav.pushViewController(detailVC, animated: true)
                } else if let nav = presenter.navigationController {
                    nav.pushViewController(detailVC, animated: true)
                } else {
                    presenter.present(detailVC, animated: true)
                }
            }
        } else if let nav = self.navigationController {
            nav.pushViewController(detailVC, animated: true)
        } else {
            self.present(detailVC, animated: true)
        }
    }
    
    func presentEventDetail(_ event: Event) {
        let detailVC = EventDetailViewController(event: event)
        // If this VC was presented modally, dismiss it first, then present from the presenter
        if let presenter = self.presentingViewController {
            self.dismiss(animated: true) {
                detailVC.modalPresentationStyle = .overCurrentContext
                detailVC.modalTransitionStyle = .crossDissolve
                presenter.present(detailVC, animated: true)
            }
        } else {
            detailVC.modalPresentationStyle = .overCurrentContext
            detailVC.modalTransitionStyle = .crossDissolve
            self.present(detailVC, animated: true)
        }
    }
}