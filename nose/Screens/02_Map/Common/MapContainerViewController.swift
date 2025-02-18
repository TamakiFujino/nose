import UIKit
import GoogleMaps
import GooglePlaces

class MapContainerViewController: UIViewController {
    
    var mapView: GMSMapView!
    var slider: CustomSlider!
    private let shadowBackground = BackShadowView()
    var profileButton: IconButton!
    var searchButton: IconButton!
    
    var mapID = GMSMapID(identifier: "7f9a1d61a6b1809f")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupShadowBackground()
        setupSlider()
        setupProfileButton()
        setupSearchButton()
        setupConstraints()
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
    }
    
    private func setupProfileButton() {
        profileButton = IconButton(image: UIImage(systemName: "person.fill"), action: #selector(dummyAction), target: self)
        view.addSubview(profileButton)
    }
    
    private func setupSearchButton() {
        searchButton = IconButton(image: UIImage(systemName: "magnifyingglass"), action: #selector(dummyAction), target: self)
        view.addSubview(searchButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Search button at the top-right corner
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            
            // Profile button closer to the search button
            profileButton.topAnchor.constraint(equalTo: searchButton.topAnchor),
            profileButton.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -10),
            
            // Slider closer to the buttons
            slider.topAnchor.constraint(equalTo: searchButton.bottomAnchor, constant: 10),
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    @objc private func dummyAction() {
        // Dummy action to satisfy selector requirement
    }
}
