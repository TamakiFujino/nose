import UIKit
import GooglePlaces
import FirebaseFirestore
import FirebaseAuth
import RealityKit

class CollectionPlacesViewController: UIViewController {

    // MARK: - Properties

    private let collection: PlaceCollection
    private var places: [PlaceCollection.Place] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var collectionAvatar: CollectionAvatar?
    private var avatarPreviewView: ARView?
    private var baseEntity: ModelEntity?

    // MARK: - UI Components

    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        return view
    }()

    private lazy var avatarContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var customizeAvatarButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        button.setImage(UIImage(systemName: "pencil", withConfiguration: config), for: .normal)
        button.setTitle(" Customize Avatar", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.tintColor = .fourthColor
        button.addTarget(self, action: #selector(avatarButtonTapped), for: .touchUpInside)
        button.contentHorizontalAlignment = .right
        return button
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaceTableViewCell.self, forCellReuseIdentifier: "PlaceCell")
        tableView.backgroundColor = .systemBackground
        tableView.rowHeight = 100
        return tableView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = collection.name
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    // MARK: - Initialization

    init(collection: PlaceCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPlaces()
        loadCollectionAvatar()
        sessionToken = GMSAutocompleteSessionToken()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAvatarPreview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        avatarPreviewView?.session.pause()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(avatarContainerView)
        headerView.addSubview(customizeAvatarButton)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 300),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            avatarContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            avatarContainerView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            avatarContainerView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            avatarContainerView.heightAnchor.constraint(equalToConstant: 180),

            customizeAvatarButton.topAnchor.constraint(equalTo: avatarContainerView.bottomAnchor, constant: 4),
            customizeAvatarButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            customizeAvatarButton.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupAvatarPreview() {
        avatarPreviewView?.removeFromSuperview()
        avatarPreviewView = nil

        let arView = ARView(frame: avatarContainerView.bounds)
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.backgroundColor = .clear

        avatarContainerView.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: avatarContainerView.topAnchor),
            arView.leadingAnchor.constraint(equalTo: avatarContainerView.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: avatarContainerView.bottomAnchor)
        ])

        view.backgroundColor = .secondColor
        arView.environment.background = .color(.secondColor)

        // Camera setup
        let cameraEntity = PerspectiveCamera()
        cameraEntity.transform.translation = SIMD3<Float>(0, 3, 7)
        let cameraAnchor = AnchorEntity()
        cameraAnchor.addChild(cameraEntity)
        arView.scene.anchors.append(cameraAnchor)

        // Directional light
        let lightAnchor = AnchorEntity(world: [0, 2.0, 0])
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.light.color = .white
        light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10.0, depthBias: 0.005)
        light.orientation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
        lightAnchor.addChild(light)
        arView.scene.anchors.append(lightAnchor)

        loadAvatarModel()
        avatarPreviewView = arView
    }

    // MARK: - Avatar Loading

    private func loadAvatarModel() {
        guard let avatar = collectionAvatar else {
            print("DEBUG: No avatar data, loading default avatar")
            loadDefaultAvatar()
            return
        }

        print("DEBUG: Loading avatar model with data: \(avatar.avatarData.selections)")

        do {
            baseEntity = try Entity.loadModel(named: "body_2") as? ModelEntity
            guard let baseEntity = baseEntity else { return }
            baseEntity.name = "Avatar"

            // Apply avatar color
            if let color = UIColor(named: avatar.avatarData.color) {
                print("DEBUG: Applying color: \(avatar.avatarData.color)")
                var material = SimpleMaterial()
                material.baseColor = .color(color)
                material.roughness = 0.3
                material.metallic = 0.0
                baseEntity.model?.materials = [material]
            }

            // Load additional avatar components
            loadAvatarComponents(avatar.avatarData)

            // Transform setup
            applyFixedScale(to: baseEntity, scale: 1.0)
            baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
            avatarPreviewView?.scene.anchors.removeAll()
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(baseEntity)
            avatarPreviewView?.scene.anchors.append(anchor)

            // Animation
            let rotation = Transform(scale: .one, rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0]), translation: .zero)
            baseEntity.move(to: rotation, relativeTo: baseEntity.parent, duration: 20, timingFunction: .linear)
        } catch {
            print("DEBUG: Error loading avatar model: \(error)")
            loadDefaultAvatar()
        }
    }

    private func loadDefaultAvatar() {
        Task {
            do {
                let entity = try await Entity.load(named: "body_2")
                applyFixedScale(to: entity, scale: 1.0)
                if let modelEntity = entity as? ModelEntity {
                    var material = SimpleMaterial()
                    material.baseColor = .color(.systemPink)
                    material.roughness = 0.3
                    material.metallic = 0.0
                    modelEntity.model?.materials = [material]
                    modelEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
                }
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(entity)
                avatarPreviewView?.scene.anchors.append(anchor)
                baseEntity = entity as? ModelEntity
            } catch {
                print("Error loading default avatar: \(error.localizedDescription)")
            }
        }
    }

    private func applyFixedScale(to entity: Entity, scale: Float) {
        if let modelEntity = entity as? ModelEntity {
            modelEntity.scale = SIMD3<Float>(scale, scale, scale)
        }
        for child in entity.children {
            applyFixedScale(to: child, scale: scale)
        }
    }

    private func loadAvatarComponents(_ avatarData: CollectionAvatar.AvatarData) {
        // Placeholder for loading additional avatar components
        // e.g., styles and accessories if needed
    }

    // MARK: - Data Loading

    private func loadPlaces() {
        places = collection.places
        tableView.reloadData()
    }

    private func loadCollectionAvatar() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Access the avatar from the user's collections subcollection
        let userRef = db.collection("users").document(currentUserId)
        let collectionRef = userRef.collection("collections").document(collection.id)
        
        print("DEBUG: Loading avatar from path: users/\(currentUserId)/collections/\(collection.id)")
        
        collectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error loading collection avatar: \(error.localizedDescription)")
                return
            }
            
            print("DEBUG: Collection document data: \(snapshot?.data() ?? [:])")
            
            if let data = snapshot?.data(),
               let avatarDict = data["avatarData"] as? [String: Any] {
                print("DEBUG: Found avatar data: \(avatarDict)")
                if let avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarDict) {
                    print("DEBUG: Successfully parsed avatar data")
                    self?.collectionAvatar = CollectionAvatar(
                        collectionId: self?.collection.id ?? "",
                        avatarData: avatarData,
                        createdAt: Date()
                    )
                    // Update the avatar preview
                    DispatchQueue.main.async {
                        self?.setupAvatarPreview()
                    }
                } else {
                    print("DEBUG: Failed to parse avatar data")
                }
            } else {
                print("DEBUG: No avatar data found in collection")
            }
        }
    }

    // MARK: - Actions

    @objc private func avatarButtonTapped() {
        let avatarVC = AvatarCustomViewController(collectionId: collection.id)
        avatarVC.delegate = self
        if let existingAvatar = collectionAvatar {
            avatarVC.setInitialAvatarData(existingAvatar.avatarData)
        }
        if let nav = navigationController {
            nav.pushViewController(avatarVC, animated: true)
        } else {
            let navVC = UINavigationController(rootViewController: avatarVC)
            navVC.modalPresentationStyle = .fullScreen
            present(navVC, animated: true, completion: nil)
        }
    }
}

// MARK: - AvatarCustomViewControllerDelegate

extension CollectionPlacesViewController: AvatarCustomViewControllerDelegate {
    func avatarCustomViewController(_ controller: AvatarCustomViewController, didSaveAvatar avatarData: CollectionAvatar.AvatarData) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        // Build the avatarData dictionary for all categories
        let avatarDict: [String: Any] = avatarData.toFirestoreDict()

        // Use the correct path: users/{userId}/collections/{collectionId}
        let userRef = db.collection("users").document(currentUserId)
        let collectionRef = userRef.collection("collections").document(collection.id)
        
        print("DEBUG: Saving avatar in delegate")
        print("DEBUG: Path: users/\(currentUserId)/collections/\(collection.id)")
        print("DEBUG: Avatar data: \(avatarDict)")

        // First get the current collection data
        collectionRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error getting collection data in delegate: \(error.localizedDescription)")
                return
            }
            
            var data: [String: Any] = [
                "avatarData": avatarDict,
                "userId": currentUserId,
                "name": snapshot?.data()?["name"] as? String ?? "Untitled Collection"
            ]
            
            print("DEBUG: Prepared data for saving in delegate: \(data)")
            
            // If the collection exists, preserve its other fields
            if let existingData = snapshot?.data() {
                print("DEBUG: Found existing collection data in delegate: \(existingData)")
                for (key, value) in existingData {
                    if !["avatarData", "userId", "name"].contains(key) {
                        data[key] = value
                    }
                }
            }
            
            collectionRef.setData(data, merge: true) { error in
                if let error = error {
                    print("Error saving collection avatar in delegate: \(error.localizedDescription)")
                    return
                }
                print("DEBUG: Successfully saved collection avatar in delegate")
                // Update local cache
                self?.collectionAvatar = CollectionAvatar(collectionId: self?.collection.id ?? "", avatarData: avatarData, createdAt: Date())
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension CollectionPlacesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        places.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaceCell", for: indexPath) as! PlaceTableViewCell
        cell.configure(with: places[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let place = places[indexPath.row]
        let placesClient = GMSPlacesClient.shared()
        let fields: GMSPlaceField = [.name, .coordinate, .formattedAddress, .phoneNumber, .rating, .openingHours, .photos, .placeID]

        placesClient.fetchPlace(fromPlaceID: place.placeId, placeFields: fields, sessionToken: sessionToken) { [weak self] place, error in
            if let place = place {
                DispatchQueue.main.async {
                    let detailVC = PlaceDetailViewController(place: place)
                    self?.present(detailVC, animated: true)
                }
            }
        }
    }
}

// MARK: - PlaceTableViewCell

class PlaceTableViewCell: UITableViewCell {
    private let placeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(placeImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)

        NSLayoutConstraint.activate([
            placeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            placeImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 80),
            placeImageView.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            ratingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            ratingLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 16),
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with place: PlaceCollection.Place) {
        nameLabel.text = place.name
        ratingLabel.text = "Rating: \(String(format: "%.1f", place.rating))"

        let placesClient = GMSPlacesClient.shared()
        let fields: GMSPlaceField = [.photos]

        placesClient.fetchPlace(fromPlaceID: place.placeId, placeFields: fields, sessionToken: nil) { [weak self] place, error in
            if let photoMetadata = place?.photos?.first {
                placesClient.loadPlacePhoto(photoMetadata) { [weak self] photo, _ in
                    DispatchQueue.main.async {
                        self?.placeImageView.image = photo
                    }
                }
            }
        }
    }
}
