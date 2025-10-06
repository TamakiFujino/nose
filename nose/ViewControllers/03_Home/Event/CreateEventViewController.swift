import UIKit
import GooglePlaces

protocol CreateEventViewControllerDelegate: AnyObject {
    func createEventViewController(_ controller: CreateEventViewController, didCreateEvent event: Event)
}

struct Event {
    let id: String
    let title: String
    let dateTime: EventDateTime
    let location: EventLocation
    let details: String
    let images: [UIImage]
    let createdAt: Date
}

struct EventDateTime {
    let startDate: Date
    let endDate: Date
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

struct EventLocation {
    let name: String
    let address: String
    let coordinates: CLLocationCoordinate2D?
}

final class CreateEventViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: CreateEventViewControllerDelegate?
    private var selectedLocation: EventLocation?
    private var selectedImages: [UIImage] = []
    private var sessionToken: GMSAutocompleteSessionToken?
    private var selectedStartDate: Date = Date()
    private var selectedEndDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    private var locationPredictions: [GMSAutocompletePrediction] = []
    
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
    
    
    // Title Section
    private lazy var titleSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Title"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private lazy var titleTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter title (max 25 characters)"
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)
        textField.delegate = self
        return textField
    }()
    
    private lazy var titleCharCountLabel: UILabel = {
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
    
    private lazy var locationTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Search for location"
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)
        textField.delegate = self
        return textField
    }()
    
    private lazy var locationTableView: UITableView = {
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
    
    private lazy var detailsTextView: UITextView = {
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
    
    private lazy var detailsPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Describe the event... (max 1000 characters)"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .placeholderText
        return label
    }()
    
    private lazy var detailsCharCountLabel: UILabel = {
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
        label.text = "Upload up to 3 images"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var imagesCollectionView: UICollectionView = {
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
        button.setTitle("Create Event", for: .normal)
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
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Create Event"
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        [titleSectionLabel, titleTextField, titleCharCountLabel,
         dateTimeSectionLabel, startDateLabel, startDateButton, endDateLabel, endDateButton, durationDisplayLabel,
         locationSectionLabel, locationTextField, locationTableView,
         detailsSectionLabel, detailsTextView, detailsPlaceholderLabel, detailsCharCountLabel,
         imagesSectionLabel, imagesLimitLabel, imagesCollectionView,
         cancelButton, createButton].forEach {
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
            
            // Title section
            titleSectionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
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
            cancelButton.topAnchor.constraint(equalTo: imagesCollectionView.bottomAnchor, constant: 40),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalTo: createButton.widthAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            
            createButton.topAnchor.constraint(equalTo: imagesCollectionView.bottomAnchor, constant: 40),
            createButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 12),
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
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func createButtonTapped() {
        guard validateForm() else { return }
        
        let eventDateTime = EventDateTime(startDate: selectedStartDate, endDate: selectedEndDate)
        let event = Event(
            id: UUID().uuidString,
            title: titleTextField.text ?? "",
            dateTime: eventDateTime,
            location: selectedLocation ?? EventLocation(name: "", address: "", coordinates: nil),
            details: detailsTextView.text ?? "",
            images: selectedImages,
            createdAt: Date()
        )
        
        delegate?.createEventViewController(self, didCreateEvent: event)
        dismiss(animated: true)
    }
    
    @objc private func startDateButtonTapped() {
        presentDatePickerModal(for: .start)
    }
    
    @objc private func endDateButtonTapped() {
        presentDatePickerModal(for: .end)
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
    
    private func searchLocations(query: String) {
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
                    print("Error searching locations: \(error.localizedDescription)")
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
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
}

// MARK: - UITextFieldDelegate
extension CreateEventViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == titleTextField {
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            
            if newText.count <= 25 {
                titleCharCountLabel.text = "\(newText.count)/25"
                titleCharCountLabel.textColor = newText.count > 20 ? .systemRed : .secondaryLabel
                return true
            }
            return false
        }
        
        if textField == locationTextField {
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            
            // Debounce the search to reduce API calls
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performLocationSearch), object: nil)
            perform(#selector(performLocationSearch), with: newText, afterDelay: 0.5)
            
            return true
        }
        
        return true
    }
    
    @objc private func performLocationSearch(_ query: String) {
        searchLocations(query: query)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == locationTextField && !locationPredictions.isEmpty {
            locationTableView.isHidden = false
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == locationTextField {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.locationTableView.isHidden = true
            }
        }
    }
    
}

// MARK: - UITextViewDelegate
extension CreateEventViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        detailsPlaceholderLabel.isHidden = !textView.text.isEmpty
        
        let count = textView.text.count
        detailsCharCountLabel.text = "\(count)/1000"
        detailsCharCountLabel.textColor = count > 900 ? .systemRed : .secondaryLabel
        
        if count > 1000 {
            textView.text = String(textView.text.prefix(1000))
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CreateEventViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationPredictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
        
        // Safety check to prevent index out of bounds crash
        guard indexPath.row < locationPredictions.count else {
            var content = cell.defaultContentConfiguration()
            content.text = "Loading..."
            cell.contentConfiguration = content
            return cell
        }
        
        let prediction = locationPredictions[indexPath.row]
        
        // Use the attributed text directly to preserve Google's formatting (bold matching parts)
        let primaryAttributedString = prediction.attributedPrimaryText
        let secondaryAttributedString = prediction.attributedSecondaryText
        
        var content = cell.defaultContentConfiguration()
        
        // Create a mutable attributed string for the primary text
        let mutablePrimary = NSMutableAttributedString(attributedString: primaryAttributedString)
        mutablePrimary.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .medium), range: NSRange(location: 0, length: mutablePrimary.length))
        content.attributedText = mutablePrimary
        
        // Add secondary text if available
        if let secondary = secondaryAttributedString {
            let mutableSecondary = NSMutableAttributedString(attributedString: secondary)
            mutableSecondary.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: mutableSecondary.length))
            mutableSecondary.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(location: 0, length: mutableSecondary.length))
            content.secondaryAttributedText = mutableSecondary
        }
        
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Safety check to prevent index out of bounds crash
        guard indexPath.row < locationPredictions.count else {
            return
        }
        
        let prediction = locationPredictions[indexPath.row]
        
        // Fetch place details
        PlacesAPIManager.shared.fetchPlaceDetailsForUserInteraction(
            placeID: prediction.placeID,
            fields: PlacesAPIManager.FieldConfig.search
        ) { [weak self] place in
            DispatchQueue.main.async {
                if let place = place {
                    self?.selectedLocation = EventLocation(
                        name: place.name ?? "",
                        address: place.formattedAddress ?? "",
                        coordinates: place.coordinate
                    )
                    self?.locationTextField.text = place.name
                    self?.locationTableView.isHidden = true
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension CreateEventViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Show add button only if we have fewer than 3 images
        return selectedImages.count < 3 ? selectedImages.count + 1 : selectedImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCollectionViewCell
        
        if indexPath.item < selectedImages.count {
            cell.configure(with: selectedImages[indexPath.item])
            cell.isAddButton = false
        } else {
            // This is the add button (only shown when selectedImages.count < 3)
            cell.configureAddButton()
            cell.isAddButton = true
        }
        
        cell.delegate = self
        cell.indexPath = indexPath
        
        return cell
    }
}

// MARK: - ImageCollectionViewCellDelegate
extension CreateEventViewController: ImageCollectionViewCellDelegate {
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapAddButtonAt indexPath: IndexPath) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        present(imagePicker, animated: true)
    }
    
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapRemoveButtonAt indexPath: IndexPath) {
        selectedImages.remove(at: indexPath.item)
        imagesCollectionView.reloadData()
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension CreateEventViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let editedImage = info[.editedImage] as? UIImage {
            selectedImages.append(editedImage)
        } else if let originalImage = info[.originalImage] as? UIImage {
            selectedImages.append(originalImage)
        }
        
        imagesCollectionView.reloadData()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - ImageCollectionViewCell
protocol ImageCollectionViewCellDelegate: AnyObject {
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapAddButtonAt indexPath: IndexPath)
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapRemoveButtonAt indexPath: IndexPath)
}

class ImageCollectionViewCell: UICollectionViewCell {
    weak var delegate: ImageCollectionViewCellDelegate?
    var indexPath: IndexPath?
    var isAddButton: Bool = false
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        return button
    }()
    
    private let removeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .firstColor
        button.backgroundColor = .fourthColor
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(addButton)
        contentView.addSubview(removeButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            addButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            removeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        removeButton.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
    }
    
    func configure(with image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        addButton.isHidden = true
        removeButton.isHidden = false
    }
    
    func configureAddButton() {
        imageView.isHidden = true
        addButton.isHidden = false
        removeButton.isHidden = true
    }
    
    @objc private func addButtonTapped() {
        guard let indexPath = indexPath else { return }
        delegate?.imageCollectionViewCell(self, didTapAddButtonAt: indexPath)
    }
    
    @objc private func removeButtonTapped() {
        guard let indexPath = indexPath else { return }
        delegate?.imageCollectionViewCell(self, didTapRemoveButtonAt: indexPath)
    }
}
