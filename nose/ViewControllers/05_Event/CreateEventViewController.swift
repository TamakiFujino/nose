import UIKit
import GooglePlaces
import FirebaseAuth
protocol CreateEventViewControllerDelegate: AnyObject {
    func createEventViewController(_ controller: CreateEventViewController, didCreateEvent event: Event)
}

final class CreateEventViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: CreateEventViewControllerDelegate?
    var selectedLocation: EventLocation?
    var selectedImages: [UIImage] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    var selectedStartDate: Date = Date()
    var selectedEndDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    var locationPredictions: [GMSAutocompletePrediction] = []
    var avatarData: CollectionAvatar.AvatarData?
    let tempAvatarCollectionId = "temp_event_avatar"
    let tempAvatarDataKey = "temp_event_avatar_data"
    
    // Editing mode
    private var eventToEdit: Event?
    private var isEditMode: Bool {
        return eventToEdit != nil
    }
    
    // MARK: - Initializers
    convenience init(eventToEdit: Event) {
        self.init()
        self.eventToEdit = eventToEdit
    }
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Avatar Section
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .clear
        // Set default placeholder
        imageView.image = UIImage(named: "avatar") ?? UIImage(systemName: "person.crop.circle")
        return imageView
    }()
    
    private lazy var customizeAvatarButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Customize avatar", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .fourthColor
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(customizeAvatarTapped), for: .touchUpInside)
        return button
    }()
    
    // Title Section
    private lazy var titleSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Title"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    lazy var titleTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter title (max 25 characters)"
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)
        textField.delegate = self
        return textField
    }()
    
    lazy var titleCharCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0/25"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // Date & Time Section
    private lazy var dateTimeSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Date & Time"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private lazy var startDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "From"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private lazy var startDateButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 5 // UITextField roundedRect uses 5pt radius
        button.layer.borderWidth = 0.5 // UITextField roundedRect uses 0.5pt border
        button.layer.borderColor = UIColor.systemGray3.cgColor // UITextField roundedRect uses systemGray3
        button.contentHorizontalAlignment = .left
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8) // UITextField roundedRect uses 8pt padding
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.addTarget(self, action: #selector(startDateButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var endDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "To"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private lazy var endDateButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 5 // UITextField roundedRect uses 5pt radius
        button.layer.borderWidth = 0.5 // UITextField roundedRect uses 0.5pt border
        button.layer.borderColor = UIColor.systemGray3.cgColor // UITextField roundedRect uses systemGray3
        button.contentHorizontalAlignment = .left
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8) // UITextField roundedRect uses 8pt padding
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.addTarget(self, action: #selector(endDateButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var durationDisplayLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Duration: 1h"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .fourthColor
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.backgroundColor = .fourthColor.withAlphaComponent(0.1)
        return label
    }()
    
    // Location Section
    private lazy var locationSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Location"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    lazy var locationTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Search for location"
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)
        textField.delegate = self
        return textField
    }()
    
    lazy var locationTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LocationCell")
        tableView.isHidden = true
        tableView.layer.cornerRadius = 8
        tableView.layer.borderWidth = 1
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.backgroundColor = .systemBackground
        // Ensure it appears above other elements
        tableView.layer.zPosition = 1000
        return tableView
    }()
    
    // Details Section
    private lazy var detailsSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Details"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    lazy var detailsTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 16)
        textView.layer.borderColor = UIColor.systemGray3.cgColor // Match other fields
        textView.layer.borderWidth = 0.5 // Match other fields
        textView.layer.cornerRadius = 5 // Match other fields
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.delegate = self
        return textView
    }()
    
    lazy var detailsPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Describe the event... (max 1000 characters)"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .placeholderText
        return label
    }()
    
    lazy var detailsCharCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0/1000"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // Images Section
    private lazy var imagesSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Images"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private lazy var imagesLimitLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Upload 1 image"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    lazy var imagesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 12
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImageCollectionViewCell.self, forCellWithReuseIdentifier: "ImageCell")
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    
    // Buttons
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemRed, for: .normal)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemRed.cgColor
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var createButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(isEditMode ? "Update Event" : "Create Event", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .fourthColor
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSessionToken()
        setupKeyboardObservers()
        setupDatePickers()
        setupNotifications()
        
        // Populate fields if in edit mode
        if isEditMode {
            populateFieldsForEditing()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = isEditMode ? "Edit Event" : "Create Event"
        
        // Add navigation bar close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        [avatarImageView, customizeAvatarButton,
         titleSectionLabel, titleTextField, titleCharCountLabel,
         dateTimeSectionLabel, startDateLabel, startDateButton, endDateLabel, endDateButton, durationDisplayLabel,
         locationSectionLabel, locationTextField, locationTableView,
         detailsSectionLabel, detailsTextView, detailsPlaceholderLabel, detailsCharCountLabel,
         imagesSectionLabel, imagesLimitLabel, imagesCollectionView,
         createButton].forEach {
            containerView.addSubview($0)
        }
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Container view
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Avatar section
            avatarImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            avatarImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 200),
            avatarImageView.heightAnchor.constraint(equalToConstant: 200),
            
            customizeAvatarButton.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 12),
            customizeAvatarButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            customizeAvatarButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Title section
            titleSectionLabel.topAnchor.constraint(equalTo: customizeAvatarButton.bottomAnchor, constant: 30),
            titleSectionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleSectionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            titleTextField.topAnchor.constraint(equalTo: titleSectionLabel.bottomAnchor, constant: 8),
            titleTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            titleTextField.heightAnchor.constraint(equalToConstant: 44),
            
            titleCharCountLabel.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 4),
            titleCharCountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Date & Time section
            dateTimeSectionLabel.topAnchor.constraint(equalTo: titleCharCountLabel.bottomAnchor, constant: 20),
            dateTimeSectionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            dateTimeSectionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            startDateLabel.topAnchor.constraint(equalTo: dateTimeSectionLabel.bottomAnchor, constant: 12),
            startDateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            startDateLabel.widthAnchor.constraint(equalToConstant: 60),
            
            startDateButton.topAnchor.constraint(equalTo: startDateLabel.bottomAnchor, constant: 8),
            startDateButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            startDateButton.trailingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: -8),
            startDateButton.heightAnchor.constraint(equalToConstant: 44),
            
            endDateLabel.topAnchor.constraint(equalTo: dateTimeSectionLabel.bottomAnchor, constant: 12),
            endDateLabel.leadingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: 8),
            endDateLabel.widthAnchor.constraint(equalToConstant: 60),
            
            endDateButton.topAnchor.constraint(equalTo: endDateLabel.bottomAnchor, constant: 8),
            endDateButton.leadingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: 8),
            endDateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            endDateButton.heightAnchor.constraint(equalToConstant: 44),
            
            durationDisplayLabel.topAnchor.constraint(equalTo: endDateButton.bottomAnchor, constant: 12),
            durationDisplayLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            durationDisplayLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            durationDisplayLabel.heightAnchor.constraint(equalToConstant: 32),
            
            // Location section
            locationSectionLabel.topAnchor.constraint(equalTo: durationDisplayLabel.bottomAnchor, constant: 20),
            locationSectionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            locationSectionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            locationTextField.topAnchor.constraint(equalTo: locationSectionLabel.bottomAnchor, constant: 8),
            locationTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            locationTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            locationTextField.heightAnchor.constraint(equalToConstant: 44),
            
            locationTableView.topAnchor.constraint(equalTo: locationTextField.bottomAnchor, constant: 4),
            locationTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            locationTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            locationTableView.heightAnchor.constraint(equalToConstant: 200),
            
            // Details section
            detailsSectionLabel.topAnchor.constraint(equalTo: locationTextField.bottomAnchor, constant: 20),
            detailsSectionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            detailsSectionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            detailsTextView.topAnchor.constraint(equalTo: detailsSectionLabel.bottomAnchor, constant: 8),
            detailsTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            detailsTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            detailsTextView.heightAnchor.constraint(equalToConstant: 120),
            
            detailsPlaceholderLabel.topAnchor.constraint(equalTo: detailsTextView.topAnchor, constant: 8),
            detailsPlaceholderLabel.leadingAnchor.constraint(equalTo: detailsTextView.leadingAnchor, constant: 12),
            
            detailsCharCountLabel.topAnchor.constraint(equalTo: detailsTextView.bottomAnchor, constant: 4),
            detailsCharCountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Images section
            imagesSectionLabel.topAnchor.constraint(equalTo: detailsCharCountLabel.bottomAnchor, constant: 20),
            imagesSectionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            imagesSectionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            imagesLimitLabel.topAnchor.constraint(equalTo: imagesSectionLabel.bottomAnchor, constant: 4),
            imagesLimitLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            imagesLimitLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            imagesCollectionView.topAnchor.constraint(equalTo: imagesLimitLabel.bottomAnchor, constant: 8),
            imagesCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            imagesCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            imagesCollectionView.heightAnchor.constraint(equalToConstant: 100),
            
            // Buttons
            createButton.topAnchor.constraint(equalTo: imagesCollectionView.bottomAnchor, constant: 40),
            createButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            createButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Bottom constraint for scroll view
            containerView.bottomAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 40)
        ])
    }
    
    private func setupSessionToken() {
        sessionToken = GMSAutocompleteSessionToken()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func setupDatePickers() {
        updateDateButtonTitles()
        updateDurationDisplay()
    }
    
    private func populateFieldsForEditing() {
        guard let event = eventToEdit else { return }
        
        // Populate title
        titleTextField.text = event.title
        titleCharCountLabel.text = "\(event.title.count)/25"
        
        // Populate dates
        selectedStartDate = event.dateTime.startDate
        selectedEndDate = event.dateTime.endDate
        updateDateButtonTitles()
        updateDurationDisplay()
        
        // Populate location
        selectedLocation = event.location
        locationTextField.text = event.location.name
        
        // Populate details
        detailsTextView.text = event.details
        detailsPlaceholderLabel.isHidden = !event.details.isEmpty
        detailsCharCountLabel.text = "\(event.details.count)/1000"
        
        // Populate images
        selectedImages = event.images
        imagesCollectionView.reloadData()
        
        // Load avatar image if available
        loadEventAvatarImage()
    }
    
    private func loadEventAvatarImage() {
        guard let event = eventToEdit,
              let userId = Auth.auth().currentUser?.uid else { return }

        EventManager.shared.fetchEventEditData(userId: userId, eventId: event.id) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let editData):
                // Load avatar customization data if available
                if let avatarDataDict = editData.avatarData {
                    Logger.log("Loading saved avatar data for editing", level: .debug, category: "CreateEvent")
                    self.avatarData = CollectionAvatar.AvatarData.fromFirestoreDict(avatarDataDict, version: .v1)

                    // Save avatar data locally for ContentViewController
                    if let avatarData = self.avatarData {
                        self.saveAvatarDataLocally(avatarData)
                    }
                }

                // Load avatar image if available
                if let avatarImageURL = editData.avatarImageURL,
                   !avatarImageURL.isEmpty,
                   let url = URL(string: avatarImageURL) {

                    URLSession.shared.dataTask(with: url) { imageData, response, error in
                        if let imageData = imageData, let image = UIImage(data: imageData) {
                            DispatchQueue.main.async {
                                self.avatarImageView.image = image
                                self.avatarImageView.contentMode = .scaleAspectFit
                                self.saveTemporaryAvatarImage(image)
                            }
                        }
                    }.resume()
                }
            case .failure(let error):
                Logger.log("Error loading event avatar data: \(error.localizedDescription)", level: .error, category: "CreateEvent")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        // Clean up temporary avatar state before dismissing
        clearTemporaryAvatarState()
        dismiss(animated: true)
    }
    
    @objc private func createButtonTapped() {
        guard validateForm() else { return }
        
        if isEditMode {
            updateEvent()
        } else {
            createEvent()
        }
    }
    
    private func createEvent() {
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not authenticated")
            return
        }
        
        // Check if user already has an upcoming event
        checkUpcomingEventsCount { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let count):
                if count >= 1 {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "Event Limit Reached",
                            message: "You can only create one event at a time."
                        )
                    }
                    return
                }
                
                // Proceed with event creation
                DispatchQueue.main.async {
                    self.proceedWithEventCreation(userId: userId)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Failed to check existing events. Please try again.")
                    Logger.log("Error checking upcoming events: \(error.localizedDescription)", level: .error, category: "CreateEvent")
                }
            }
        }
    }
    
    private func proceedWithEventCreation(userId: String) {
        // Show loading indicator
        showLoadingAlert(title: "Creating Event")
        
        let eventDateTime = EventDateTime(startDate: selectedStartDate, endDate: selectedEndDate)
        let event = Event(
            id: UUID().uuidString,
            title: titleTextField.text ?? "",
            dateTime: eventDateTime,
            location: selectedLocation ?? EventLocation(name: "", address: "", coordinates: nil),
            details: detailsTextView.text ?? "",
            images: selectedImages,
            createdAt: Date(),
            userId: userId
        )
        
        // Debug: Log avatar data if present
        if let avatarData = avatarData {
            Logger.log("Saving event with avatar data: \(avatarData.selections.count) categories", level: .debug, category: "CreateEvent")
        } else {
            Logger.log("Saving event without avatar data", level: .debug, category: "CreateEvent")
        }
        
        // Save event to Firebase
        EventManager.shared.createEvent(event, avatarData: avatarData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let eventId):
                    Logger.log("Event created successfully with ID: \(eventId)", level: .info, category: "CreateEvent")
                    self?.clearTemporaryAvatarState()
                    if let self = self {
                        self.delegate?.createEventViewController(self, didCreateEvent: event)
                        self.dismissSelf()
                    }
                case .failure(let error):
                    Logger.log("Failed to create event: \(error.localizedDescription)", level: .error, category: "CreateEvent")
                    self?.dismiss(animated: true) {
                        self?.showAlert(title: "Error", message: "Failed to create event. Please try again.")
                    }
                }
            }
        }
    }
    
    private func updateEvent() {
        guard let eventToEdit = eventToEdit else { return }
        
        // Show loading indicator
        showLoadingAlert(title: "Updating Event")
        
        let eventDateTime = EventDateTime(startDate: selectedStartDate, endDate: selectedEndDate)
        let updatedEvent = Event(
            id: eventToEdit.id,
            title: titleTextField.text ?? "",
            dateTime: eventDateTime,
            location: selectedLocation ?? EventLocation(name: "", address: "", coordinates: nil),
            details: detailsTextView.text ?? "",
            images: selectedImages,
            createdAt: eventToEdit.createdAt,
            userId: eventToEdit.userId
        )
        
        // Update event in Firebase
        EventManager.shared.updateEvent(updatedEvent, avatarData: avatarData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    Logger.log("Event updated successfully", level: .info, category: "CreateEvent")
                    self?.clearTemporaryAvatarState()
                    if let self = self {
                        self.delegate?.createEventViewController(self, didCreateEvent: updatedEvent)
                        self.dismissSelf()
                    }
                case .failure(let error):
                    Logger.log("Failed to update event: \(error.localizedDescription)", level: .error, category: "CreateEvent")
                    self?.dismiss(animated: true) {
                        self?.showAlert(title: "Error", message: "Failed to update event. Please try again.")
                    }
                }
            }
        }
    }
    
    @objc private func startDateButtonTapped() {
        presentDatePickerModal(for: .start)
    }
    
    @objc private func endDateButtonTapped() {
        presentDatePickerModal(for: .end)
    }
    
    @objc private func customizeAvatarTapped() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Create a temporary collection object for avatar customization (not saved to Firestore)
        // We'll use a consistent ID so ContentViewController can recognize it as temporary
        let tempCollection = PlaceCollection(
            id: tempAvatarCollectionId,
            name: "Event Avatar",
            places: [],
            userId: userId,
            status: .active,
            isOwner: true
        )
        
        // Save existing avatar data locally (if any) before navigating
        // This ensures ContentViewController can load it if needed
        if let existingAvatarData = avatarData {
            saveAvatarDataLocally(existingAvatarData)
            Logger.log("Saved existing avatar data locally before customization", level: .info, category: "CreateEvent")
                    }
                    
        // Navigate to ContentViewController (no Firestore operations)
            let vc = ContentViewController(collection: tempCollection)
            if let nav = navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                present(vc, animated: true)
        }
    }
    
    
    private func presentDatePickerModal(for type: DatePickerType) {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minuteInterval = 15 // 15-minute intervals: 0, 15, 30, 45
        datePicker.minimumDate = type == .start ? Date() : selectedStartDate
        
        if type == .start {
            datePicker.date = selectedStartDate
        } else {
            datePicker.date = selectedEndDate
        }
        
        let alert = UIAlertController(title: type == .start ? "Select Start Date & Time" : "Select End Date & Time", message: "\n\n\n\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        
        // Add date picker as subview to the alert's view
        alert.view.addSubview(datePicker)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            datePicker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            datePicker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            datePicker.widthAnchor.constraint(equalTo: alert.view.widthAnchor, multiplier: 0.8),
            datePicker.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        let selectAction = UIAlertAction(title: "Select", style: .default) { [weak self] _ in
            if type == .start {
                self?.selectedStartDate = datePicker.date
                // Ensure end date is after start date
                if self?.selectedEndDate ?? Date() <= datePicker.date {
                    self?.selectedEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: datePicker.date) ?? datePicker.date
                }
            } else {
                self?.selectedEndDate = datePicker.date
            }
            self?.updateDateButtonTitles()
            self?.updateDurationDisplay()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(selectAction)
        alert.addAction(cancelAction)
        
        // For iPad support
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = type == .start ? startDateButton : endDateButton
            popoverController.sourceRect = type == .start ? startDateButton.bounds : endDateButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func updateDateButtonTitles() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        startDateButton.setTitle(formatter.string(from: selectedStartDate), for: .normal)
        endDateButton.setTitle(formatter.string(from: selectedEndDate), for: .normal)
    }
    
    private func updateDurationDisplay() {
        let eventDateTime = EventDateTime(startDate: selectedStartDate, endDate: selectedEndDate)
        durationDisplayLabel.text = "Duration: \(eventDateTime.formattedDuration)"
    }
    
    func searchLocations(query: String) {
        guard !query.isEmpty else {
            locationPredictions = []
            locationTableView.isHidden = true
            return
        }
        
        // Only search if user has typed at least 2 characters to reduce API costs
        guard query.count >= 2 else {
            locationPredictions = []
            locationTableView.isHidden = true
            return
        }
        
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()
        
        // Include both establishments and addresses for comprehensive results
        // This allows searching for both businesses and residential addresses
        filter.types = ["establishment", "geocode"]
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: sessionToken
        ) { [weak self] predictions, error in
            DispatchQueue.main.async {
                if let error = error {
                    Logger.log("Error searching locations: \(error.localizedDescription)", level: .error, category: "CreateEvent")
                    return
                }
                
                self?.locationPredictions = predictions ?? []
                let isEmpty = self?.locationPredictions.isEmpty ?? true
                self?.locationTableView.isHidden = isEmpty
                
                // Only reload if table view is visible to prevent crashes
                if !isEmpty {
                    self?.locationTableView.reloadData()
                }
            }
        }
    }
}

enum DatePickerType {
    case start
    case end
}

// MARK: - Keyboard Handling
extension CreateEventViewController {
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    // MARK: - Helper Methods
    private func validateForm() -> Bool {
        guard let title = titleTextField.text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Missing Title", message: "Please enter an event title.")
            return false
        }
        
        guard title.count <= 25 else {
            showAlert(title: "Title Too Long", message: "Event title must be 25 characters or less.")
            return false
        }
        
        guard selectedLocation != nil else {
            showAlert(title: "Missing Location", message: "Please select an event location.")
            return false
        }
        
        guard let details = detailsTextView.text, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Missing Details", message: "Please enter event details.")
            return false
        }
        
        guard details.count <= 1000 else {
            showAlert(title: "Details Too Long", message: "Event details must be 1000 characters or less.")
            return false
        }
        
        return true
    }
    
    private func checkUpcomingEventsCount(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "CreateEventViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        EventManager.shared.fetchEvents(userId: userId) { result in
            switch result {
            case .success(let events):
                let now = Date()
                // Upcoming events include both current (started but not ended) and future (not started yet) events
                let upcomingEvents = events.filter { $0.dateTime.endDate >= now }
                completion(.success(upcomingEvents.count))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let messageModal = MessageModalViewController(title: title, message: message)
        present(messageModal, animated: true)
    }
    
    private func showLoadingAlert(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        alert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor, constant: 20)
        ])
        
        present(alert, animated: true)
    }
    
    // MARK: - Avatar Data Handling
    func updateAvatarData(_ avatarData: CollectionAvatar.AvatarData) {
        self.avatarData = avatarData
        Logger.log("Avatar data updated for event creation: \(avatarData.selections.count) selections", level: .info, category: "CreateEvent")
    }
    
    func updateAvatarImageView() {
        // Update the avatar image view to show the actual customized avatar
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Load and display the temporary avatar image
            self.loadTemporaryAvatarImage()
            
            Logger.log("Avatar image view updated with actual avatar", level: .debug, category: "CreateEvent")
        }
    }
    
}

