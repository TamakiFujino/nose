import UIKit
import GooglePlaces

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    var searchBar: UISearchBar!
    var tableView: UITableView!
    var placesClient = GMSPlacesClient.shared()
    var predictions: [GMSAutocompletePrediction] = []
    var backButton: UIButton!
    
    weak var mainViewController: HomeViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .black
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        
        searchBar = UISearchBar()
        searchBar.placeholder = "Search for a place"
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchBar.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let filter = GMSAutocompleteFilter()
        placesClient.findAutocompletePredictions(fromQuery: searchText, filter: filter, sessionToken: nil) { [weak self] (results, error) in
            if let error = error {
                print("Autocomplete error: \(error.localizedDescription)")
                return
            }
            self?.predictions = results ?? []
            self?.tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let prediction = predictions[indexPath.row]
        cell.textLabel?.text = prediction.attributedPrimaryText.string
        cell.detailTextLabel?.text = prediction.attributedSecondaryText?.string
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let prediction = predictions[indexPath.row]
        dismiss(animated: true) {
            self.mainViewController?.fetchPlaceDetailsAndPresent(placeID: prediction.placeID, name: prediction.attributedPrimaryText.string, location: nil)
        }
    }
}
