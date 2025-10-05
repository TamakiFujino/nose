import UIKit
import GooglePlaces

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ controller: SearchViewController, didSelectPlace place: GMSPlace)
}

final class SearchViewController: UIViewController {
    
    // MARK: - Properties
    private var searchResults: [GMSAutocompletePrediction] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    
    weak var delegate: SearchViewControllerDelegate?
    
    // MARK: - UI Components
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search for a place"
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
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(searchBar)
        view.addSubview(closeButton)
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Close button constraints
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Search bar constraints
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
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
        
        // Use debounced search to prevent rapid-fire API calls
        PlacesAPIManager.shared.debouncedSearch(query: query) { [weak self] (results: [GMSAutocompletePrediction]) in
            DispatchQueue.main.async {
                self?.searchResults = results
                self?.tableView.reloadData()
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
                print("Successfully fetched place: \(place.name ?? "Unknown")")
                print("Place ID: \(place.placeID ?? "nil")")
                print("Has photos: \(place.photos?.count ?? 0)")
                print("Has rating: \(place.rating)")
                print("Has phone: \(place.phoneNumber != nil)")
                print("Has opening hours: \(place.openingHours != nil)")
                
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
                print("Failed to fetch place details for: \(prediction.placeID)")
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
                self.searchResults = results
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
        let prediction = searchResults[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = prediction.attributedPrimaryText.string
        content.secondaryText = prediction.attributedSecondaryText?.string
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let prediction = searchResults[indexPath.row]
        fetchPlaceDetails(for: prediction)
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
}