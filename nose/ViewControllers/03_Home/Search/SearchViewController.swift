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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update corner radius based on actual frame height for perfect rounded corners
        let textField = searchBar.searchTextField
        let actualHeight = textField.frame.height
        if actualHeight > 0 {
            textField.layer.cornerRadius = actualHeight / 2
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        // Setup constraints
        let searchBarHeight: CGFloat = 60
        NSLayoutConstraint.activate([
            // Search bar constraints - full width, top aligned
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.heightAnchor.constraint(equalToConstant: searchBarHeight),
            
            // Table view constraints
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Configure search bar appearance after layout
        configureSearchBarAppearance(height: searchBarHeight)
    }
    
    private func configureSearchBarAppearance(height: CGFloat) {
        // Remove default background
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .clear
        
        // Customize search text field for rounded corners
        let textField = searchBar.searchTextField
        textField.backgroundColor = UIColor.systemGray6
        textField.clipsToBounds = true
        textField.font = .systemFont(ofSize: 16)
        
        // Add horizontal padding (12pt on each side)
        let horizontalPadding: CGFloat = 12
        
        // Configure padding and corner radius after layout to ensure correct dimensions
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let textField = self.searchBar.searchTextField
            
            // Set corner radius based on actual frame height for perfect rounded corners
            let actualHeight = textField.frame.height > 0 ? textField.frame.height : height
            textField.layer.cornerRadius = actualHeight / 2
            
            // Create back button (replaces search icon)
            let backButton = UIButton(type: .system)
            backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
            backButton.tintColor = .black
            backButton.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            backButton.addTarget(self, action: #selector(self.closeButtonTapped), for: .touchUpInside)
            
            // Create left container with padding + back button
            let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: horizontalPadding + 20 + horizontalPadding, height: height))
            leftContainer.backgroundColor = .clear
            backButton.center = CGPoint(x: horizontalPadding + 10, y: leftContainer.bounds.midY)
            leftContainer.addSubview(backButton)
            
            textField.leftView = leftContainer
            textField.leftViewMode = .always
            
            // Create clear button with padding
            let clearButton = UIButton(type: .system)
            clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            clearButton.tintColor = .systemGray
            clearButton.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            clearButton.addTarget(self, action: #selector(self.clearSearchText), for: .touchUpInside)
            
            // Create right container with clear button + padding
            let rightContainer = UIView(frame: CGRect(x: 0, y: 0, width: 20 + horizontalPadding, height: height))
            rightContainer.backgroundColor = .clear
            clearButton.center = CGPoint(x: 10, y: rightContainer.bounds.midY)
            rightContainer.addSubview(clearButton)
            
            // Store reference for clear action
            self.clearButton = clearButton
            
            textField.rightView = rightContainer
            // Show clear button when editing and text is present
            textField.rightViewMode = .whileEditing
        }
    }
    
    private var clearButton: UIButton?
    
    @objc private func clearSearchText() {
        searchBar.text = ""
        searchBar.searchTextField.text = ""
        searchBar.searchTextField.resignFirstResponder()
        searchResults = []
        tableView.reloadData()
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
        EventManager.shared.fetchAllCurrentAndFutureEvents { result in
            switch result {
            case .success(let allEvents):
                let filtered = allEvents.filter { event in
                    event.title.lowercased().contains(query.lowercased()) ||
                    event.location.name.lowercased().contains(query.lowercased()) ||
                    event.location.address.lowercased().contains(query.lowercased())
                }
                completion(filtered)
            case .failure(let error):
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
            content.imageProperties.tintColor = .fourthColor
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
                // Sheet presentation is configured in PlaceDetailViewController
                detailVC.modalTransitionStyle = .crossDissolve
                presenter.present(detailVC, animated: true)
            }
        } else {
            // Sheet presentation is configured in PlaceDetailViewController
            detailVC.modalTransitionStyle = .crossDissolve
            self.present(detailVC, animated: true)
        }
    }
}
