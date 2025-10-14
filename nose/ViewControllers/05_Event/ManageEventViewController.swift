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
        tableView.backgroundColor = .backgroundPrimary
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
        view.backgroundColor = .backgroundPrimary
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
        addButton.tintColor = .fifthColor
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
            AlertManager.present(on: self, title: "Error", message: "User not authenticated", style: .error)
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
                case .failure(let error):
                    Logger.log("Failed to load events: \(error.localizedDescription)", level: .error, category: "Events")
                    if let presenter = self {
                        AlertManager.present(on: presenter, title: "Error", message: "Failed to load events. Please try again.", style: .error)
                    }
                    self?.updateUI()
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
        guard let userId = Auth.auth().currentUser?.uid else { return }
        // Enforce a limit of 2 active/future events per user
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let count = try await EventManager.shared.countActiveAndFutureEvents(userId: userId)
                if count >= 2 {
                    AlertManager.present(on: self, title: "Limit Reached", message: "You can create up to 2 upcoming/current events.", style: .info)
                    return
                }
                let createEventVC = CreateEventViewController()
                createEventVC.delegate = self
                let navController = UINavigationController(rootViewController: createEventVC)
                navController.modalPresentationStyle = .fullScreen
                self.present(navController, animated: true)
            } catch {
                AlertManager.present(on: self, title: "Error", message: "Couldn't verify event quota. Please try again.", style: .error)
            }
        }
    }
    
    @objc private func handleEventUpdated() {
        loadEvents()
    }
    
    // Removed local showAlert in favor of AlertManager.present
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
        deleteAction.backgroundColor = .statusError
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func confirmDeleteEvent(at indexPath: IndexPath) {
        let event = filteredEvents[indexPath.row]
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        let delete = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteEvent(at: indexPath)
        }
        AlertManager.present(
            on: self,
            title: "Delete Event",
            message: "Are you sure you want to delete '\(event.title)'? This action cannot be undone.",
            style: .error,
            preferredStyle: .alert,
            actions: [cancel, delete]
        )
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
                    ToastManager.showToast(message: "Event deleted", type: .success)
                case .failure(let error):
                    Logger.log("Failed to delete event: \(error.localizedDescription)", level: .error, category: "Events")
                    if let presenter = self {
                        AlertManager.present(on: presenter, title: "Error", message: "Failed to delete event. Please try again.", style: .error)
                    }
                }
            }
        }
    }
    
}

// MARK: - CreateEventViewControllerDelegate

extension ManageEventViewController: CreateEventViewControllerDelegate {
    func createEventViewController(_ controller: CreateEventViewController, didCreateEvent event: Event) {
        Logger.log("Event created: \(event.title)", level: .info, category: "Events")
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
        imageView.backgroundColor = .backgroundSecondary
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
            Logger.log("Using event uploaded image for: \(event.title)", level: .debug, category: "Events")
            eventImageView.image = event.images[0]
            return
        }
        
        // Show placeholder
        eventImageView.image = UIImage(systemName: "photo")
        eventImageView.tintColor = .borderSubtle
        eventImageView.contentMode = .scaleAspectFit
    }
    
    private func loadAvatarImage(for event: Event) {
        // Set placeholder while loading
        avatarImageView.image = UIImage(systemName: "person.circle")
        avatarImageView.tintColor = .borderSubtle
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(event.userId)
            .collection("events")
            .document(event.id)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    Logger.log("Error loading avatar image: \(error.localizedDescription)", level: .error, category: "Events")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let avatarImageURL = data["avatarImageURL"] as? String,
                      !avatarImageURL.isEmpty,
                      let url = URL(string: avatarImageURL) else {
                    Logger.log("No avatar image URL found for event: \(event.title)", level: .debug, category: "Events")
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
