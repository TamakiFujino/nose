//
//  ManageEventViewController.swift
//  nose
//
//  Created by Tamaki Fujino on 2025/10/06.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ManageEventViewController: UIViewController {
    
    // MARK: - Properties
    
    private var allEvents: [Event] = []
    private var filteredEvents: [Event] = []
    private var isLoading = false
    private var addButton: UIBarButtonItem?
    
    private enum EventFilter: Int {
        case past = 0
        case current = 1
        case future = 2
    }
    
    private var currentFilter: EventFilter = .current
    
    // MARK: - UI Components
    
    private lazy var filterSegmentedControl: UISegmentedControl = {
        let segmented = UISegmentedControl(items: ["Past", "Current", "Future"])
        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.selectedSegmentIndex = EventFilter.current.rawValue
        segmented.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        return segmented
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(EventTableViewCell.self, forCellReuseIdentifier: "EventCell")
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        return tableView
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        
        let imageView = UIImageView(image: UIImage(systemName: "calendar.badge.exclamationmark"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No events yet"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Tap + to create your first event"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.textAlignment = .center
        
        view.addSubview(imageView)
        view.addSubview(label)
        view.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        return view
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadEvents()
        setupNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh events when view appears
        loadEvents()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "My Events"
        
        // Add navigation bar buttons
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backButton.tintColor = .label
        navigationItem.leftBarButtonItem = backButton
        
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(createEventTapped)
        )
        addButton.tintColor = .fourthColor
        self.addButton = addButton
        navigationItem.rightBarButtonItem = addButton
        
        // Add subviews
        view.addSubview(filterSegmentedControl)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            filterSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            filterSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            filterSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            filterSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            tableView.topAnchor.constraint(equalTo: filterSegmentedControl.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: filterSegmentedControl.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupNotifications() {
        // Listen for event creation/update notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEventUpdated),
            name: NSNotification.Name("EventUpdated"),
            object: nil
        )
    }
    
    // MARK: - Data Loading
    
    private func loadEvents() {
        guard !isLoading else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not authenticated")
            return
        }
        
        isLoading = true
        activityIndicator.startAnimating()
        emptyStateView.isHidden = true
        
        EventManager.shared.fetchEvents(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.activityIndicator.stopAnimating()
                
                switch result {
                case .success(let events):
                    self?.allEvents = events.sorted { $0.dateTime.startDate > $1.dateTime.startDate }
                    self?.applyFilter()
                    self?.updateUI()
                    self?.updateAddButtonState()
                case .failure(let error):
                    print("❌ Failed to load events: \(error.localizedDescription)")
                    self?.showAlert(title: "Error", message: "Failed to load events. Please try again.")
                    self?.updateUI()
                    self?.updateAddButtonState()
                }
            }
        }
    }
    
    private func updateUI() {
        if filteredEvents.isEmpty {
            emptyStateView.isHidden = false
            tableView.isHidden = true
        } else {
            emptyStateView.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
    
    private func updateAddButtonState() {
        let now = Date()
        // Upcoming events include both current (started but not ended) and future (not started yet) events
        let upcomingEvents = allEvents.filter { $0.dateTime.endDate >= now }
        let hasUpcomingEvent = upcomingEvents.count >= 1
        
        // Keep button enabled but gray it out to indicate limit is reached
        // The error message will be shown when tapped
        if hasUpcomingEvent {
            addButton?.tintColor = .systemGray
        } else {
            addButton?.tintColor = .fourthColor
        }
    }
    
    private func applyFilter() {
        let now = Date()
        
        switch currentFilter {
        case .past:
            // Events that have ended
            filteredEvents = allEvents.filter { $0.dateTime.endDate < now }
        case .current:
            // Events that are currently happening (started but not ended)
            filteredEvents = allEvents.filter { $0.dateTime.startDate <= now && $0.dateTime.endDate >= now }
        case .future:
            // Events that haven't started yet
            filteredEvents = allEvents.filter { $0.dateTime.startDate > now }
        }
    }
    
    @objc private func filterChanged() {
        currentFilter = EventFilter(rawValue: filterSegmentedControl.selectedSegmentIndex) ?? .current
        applyFilter()
        updateUI()
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func createEventTapped() {
        // Check if user already has an upcoming event
        let now = Date()
        let upcomingEvents = allEvents.filter { $0.dateTime.endDate >= now }
        if upcomingEvents.count >= 1 {
            showAlert(
                title: "Event Limit Reached",
                message: "You can only create one event at a time."
            )
            return
        }
        
        let createEventVC = CreateEventViewController()
        createEventVC.delegate = self
        let navController = UINavigationController(rootViewController: createEventVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    @objc private func handleEventUpdated() {
        loadEvents()
    }
    
    private func showAlert(title: String, message: String) {
        let messageModal = MessageModalViewController(title: title, message: message)
        present(messageModal, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension ManageEventViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredEvents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as! EventTableViewCell
        cell.configure(with: filteredEvents[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let event = filteredEvents[indexPath.row]
        
        // Navigate to edit screen
        let createEventVC = CreateEventViewController(eventToEdit: event)
        createEventVC.delegate = self
        let navController = UINavigationController(rootViewController: createEventVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let event = filteredEvents[indexPath.row]
        
        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            self?.confirmDeleteEvent(at: indexPath)
            completion(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func confirmDeleteEvent(at indexPath: IndexPath) {
        let event = filteredEvents[indexPath.row]
        
        let alert = UIAlertController(
            title: "Delete Event",
            message: "Are you sure you want to delete '\(event.title)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteEvent(at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteEvent(at indexPath: IndexPath) {
        let event = filteredEvents[indexPath.row]
        
        activityIndicator.startAnimating()
        
        EventManager.shared.deleteEvent(eventId: event.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                switch result {
                case .success:
                    // Remove from both allEvents and filteredEvents
                    if let allIndex = self?.allEvents.firstIndex(where: { $0.id == event.id }) {
                        self?.allEvents.remove(at: allIndex)
                    }
                    self?.filteredEvents.remove(at: indexPath.row)
                    self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self?.updateUI()
                    self?.updateAddButtonState()
                    ToastManager.showToast(message: "Event deleted", type: .success)
                case .failure(let error):
                    print("❌ Failed to delete event: \(error.localizedDescription)")
                    self?.showAlert(title: "Error", message: "Failed to delete event. Please try again.")
                }
            }
        }
    }
    
}

// MARK: - CreateEventViewControllerDelegate

extension ManageEventViewController: CreateEventViewControllerDelegate {
    func createEventViewController(_ controller: CreateEventViewController, didCreateEvent event: Event) {
        print("Event created: \(event.title)")
        controller.navigationController?.dismiss(animated: true)
        loadEvents()
    }
}

// MARK: - EventTableViewCell

class EventTableViewCell: UITableViewCell {
    
    // Event image (header)
    private lazy var eventImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    // Avatar image (left side)
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .clear
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var locationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
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
        contentView.addSubview(eventImageView)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(locationLabel)
        
        NSLayoutConstraint.activate([
            // Event image at top (square, full width)
            eventImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            eventImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            eventImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            eventImageView.heightAnchor.constraint(equalTo: eventImageView.widthAnchor),
            
            // Avatar image on left below event image
            avatarImageView.topAnchor.constraint(equalTo: eventImageView.bottomAnchor, constant: 12),
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),
            
            // Title label on right
            titleLabel.topAnchor.constraint(equalTo: eventImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Date label
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Location label
            locationLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            locationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            locationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with event: Event) {
        titleLabel.text = event.title
        
        // Format date range as "yyyy/mm/dd tt:tt - yyyy/mm/dd tt:tt"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let startDateString = dateFormatter.string(from: event.dateTime.startDate)
        let endDateString = dateFormatter.string(from: event.dateTime.endDate)
        dateLabel.text = "📅 \(startDateString) - \(endDateString)"
        
        // Location
        locationLabel.text = "📍 \(event.location.name)"
        
        // Clear images first to prevent showing old images
        eventImageView.image = nil
        avatarImageView.image = nil
        
        // Load event uploaded image (header)
        loadEventImage(for: event)
        
        // Load avatar image (left side)
        loadAvatarImage(for: event)
    }
    
    private func loadEventImage(for event: Event) {
        // Use already loaded image if available
        if !event.images.isEmpty {
            print("🖼️ Using event uploaded image for: \(event.title)")
            eventImageView.image = event.images[0]
            return
        }
        
        // Show placeholder
        eventImageView.image = UIImage(systemName: "photo")
        eventImageView.tintColor = .systemGray3
        eventImageView.contentMode = .scaleAspectFit
    }
    
    private func loadAvatarImage(for event: Event) {
        // Set placeholder while loading
        avatarImageView.image = UIImage(systemName: "person.circle")
        avatarImageView.tintColor = .systemGray3
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(event.userId)
            .collection("events")
            .document(event.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading avatar image: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let avatarImageURL = data["avatarImageURL"] as? String,
                      !avatarImageURL.isEmpty,
                      let url = URL(string: avatarImageURL) else {
                    print("⚠️ No avatar image URL found for event: \(event.title)")
                    return
                }
                
                // Download avatar image
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.avatarImageView.image = image
                            self?.avatarImageView.contentMode = .scaleAspectFit
                            self?.avatarImageView.tintColor = nil
                        }
                    }
                }.resume()
            }
    }
}
