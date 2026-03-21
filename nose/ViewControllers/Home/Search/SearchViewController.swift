import UIKit
import GooglePlaces

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
    /// Wrapper used as table header: holds the search bar and reserves space for its shadow so the shadow isn't cut by the table.
    private lazy var searchHeaderView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = false
        return view
    }()
    
    private lazy var searchContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 30
        view.layer.masksToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var searchTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = String(localized: "search_placeholder")
        field.font = .systemFont(ofSize: 16)
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        field.delegate = self
        return field
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
        
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
        
        searchTextField.becomeFirstResponder()
    }
    
    private static let searchBarHeight: CGFloat = 60
    private static let searchHeaderShadowSpace: CGFloat = 14
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        searchHeaderView.addSubview(searchContainerView)
        searchContainerView.addSubview(backButton)
        searchContainerView.addSubview(searchTextField)
        
        let h = SearchViewController.searchBarHeight
        let headerHeight = h + SearchViewController.searchHeaderShadowSpace
        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: searchHeaderView.topAnchor, constant: 8),
            searchContainerView.leadingAnchor.constraint(equalTo: searchHeaderView.leadingAnchor, constant: 16),
            searchContainerView.trailingAnchor.constraint(equalTo: searchHeaderView.trailingAnchor, constant: -16),
            searchContainerView.heightAnchor.constraint(equalToConstant: h),
            
            backButton.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 20),
            backButton.heightAnchor.constraint(equalToConstant: 20),
            
            searchTextField.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            searchTextField.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -20),
            searchTextField.topAnchor.constraint(equalTo: searchContainerView.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor),
        ])
        
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        searchHeaderView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: headerHeight)
        tableView.tableHeaderView = searchHeaderView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = tableView.tableHeaderView, header.bounds.width != tableView.bounds.width {
            var frame = header.frame
            frame.size.width = tableView.bounds.width
            frame.size.height = SearchViewController.searchBarHeight + SearchViewController.searchHeaderShadowSpace
            header.frame = frame
            tableView.tableHeaderView = header
        }
        let r = searchContainerView.bounds
        if r.width > 0, r.height > 0 {
            searchContainerView.layer.shadowPath = UIBezierPath(roundedRect: r, cornerRadius: 30).cgPath
        }
    }
    
    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""
        if text.isEmpty {
            searchResults = []
            tableView.reloadData()
            return
        }
        searchPlaces(query: text)
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
        searchTextField.text = query
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

// MARK: - UITextFieldDelegate
extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
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
