//
//  ShareViewController.swift
//  ShareWithNose
//
//  Created by Tamaki Fujino on 2025/11/16.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Data Models
    struct SimpleCollection {
        let id: String
        let name: String
    }
    
    private var collections: [SimpleCollection] = []
    private var extractedURL: String?
    private var isSaving = false
    private var selectedCollectionIndex: Int?
    private var isValidLocationLink = false
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Save to Collection"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .systemGray2
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tv.backgroundColor = .clear
        tv.separatorStyle = .singleLine
        tv.tableFooterView = UIView()
        return tv
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Save", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        button.alpha = 0.5
        button.isEnabled = false
        return button
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        setupUI()
        loadCachedCollections()
        processInputItems()
    }
    
    private func setupUI() {
        view.addSubview(containerView)
        containerView.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)
        containerView.addSubview(tableView)
        containerView.addSubview(saveButton)
        containerView.addSubview(loadingIndicator)
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            containerView.heightAnchor.constraint(equalToConstant: 480),
            
            // Header
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // TableView
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -10),
            
            // Save Button
            saveButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Loading / Status
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Loading
    private func loadCachedCollections() {
        if let defaults = UserDefaults(suiteName: "group.com.tamakifujino.nose"),
           let cached = defaults.array(forKey: "CachedCollections") as? [[String: String]] {
            
            self.collections = cached.compactMap { dict in
                guard let id = dict["id"], let name = dict["name"] else { return nil }
                return SimpleCollection(id: id, name: name)
            }
            tableView.reloadData()
        }
        
        if collections.isEmpty {
            showError(message: "No collections found.\nOpen Nose to create one.")
        }
    }
    
    private func processInputItems() {
        loadingIndicator.startAnimating()
        
        guard let extensionContext = self.extensionContext else { return }
        
        var foundURL = false
        
        for item in extensionContext.inputItems as! [NSExtensionItem] {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    foundURL = true
                    provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] (url, error) in
                        DispatchQueue.main.async {
                            self?.loadingIndicator.stopAnimating()
                            if let url = url as? URL {
                                self?.validateAndSetURL(url)
                            } else {
                                self?.showError(message: "Invalid content.")
                            }
                        }
                    }
                    return
                }
            }
        }
        
        if !foundURL {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadingIndicator.stopAnimating()
                self.showError(message: "No link found.")
            }
        }
    }
    
    private func validateAndSetURL(_ url: URL) {
        // Basic validation to ensure it's a map link
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        let isMapLink = host.contains("google.com") ||
                        host.contains("goo.gl") ||
                        host.contains("g.co") ||
                        host.contains("maps.apple.com") ||
                        host.contains("waze.com") ||
                        path.contains("/maps")
        
        if isMapLink {
            self.extractedURL = url.absoluteString
            self.isValidLocationLink = true
            self.updateSaveButtonState()
        } else {
            showError(message: "This link does not appear to be a location.")
        }
    }
    
    private func showError(message: String) {
        tableView.isHidden = true
        saveButton.isHidden = true
        statusLabel.text = message
        statusLabel.isHidden = false
    }
    
    private func updateSaveButtonState() {
        let hasURL = extractedURL != nil
        let hasSelection = selectedCollectionIndex != nil
        let canSave = hasURL && hasSelection && isValidLocationLink
        
        UIView.animate(withDuration: 0.2) {
            self.saveButton.alpha = canSave ? 1.0 : 0.5
            self.saveButton.isEnabled = canSave
        }
    }
    
    // MARK: - Actions
    @objc private func closeTapped() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @objc private func saveTapped() {
        guard let index = selectedCollectionIndex else { return }
        let collection = collections[index]
        saveToCollection(collectionId: collection.id, collectionName: collection.name)
    }
    
    private func saveToCollection(collectionId: String, collectionName: String) {
        guard let urlString = extractedURL else { return }
        guard !isSaving else { return }
        isSaving = true
        
        // Show loading on button
        saveButton.setTitle("Saving...", for: .normal)
        
        let pendingItem: [String: Any] = [
            "url": urlString,
            "collectionId": collectionId,
            "collectionName": collectionName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let defaults = UserDefaults(suiteName: "group.com.tamakifujino.nose") {
            var inbox = defaults.array(forKey: "ShareInbox") as? [[String: Any]] ?? []
            inbox.append(pendingItem)
            defaults.set(inbox, forKey: "ShareInbox")
            defaults.synchronize()
            
            showSuccessAndClose()
        }
    }
    
    private func showSuccessAndClose() {
        tableView.isHidden = true
        saveButton.isHidden = true
        titleLabel.text = "Saved!"
        statusLabel.text = "Place queued for saving."
        statusLabel.isHidden = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return collections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = collections[indexPath.row].name
        
        // Show selection checkmark
        if indexPath.row == selectedCollectionIndex {
            cell.accessoryType = .checkmark
            cell.textLabel?.textColor = .systemBlue
        } else {
            cell.accessoryType = .none
            cell.textLabel?.textColor = .label
        }
        
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Update selection
        let previousIndex = selectedCollectionIndex
        selectedCollectionIndex = indexPath.row
        
        var reloadPaths: [IndexPath] = [indexPath]
        if let prev = previousIndex {
            reloadPaths.append(IndexPath(row: prev, section: 0))
        }
        
        tableView.reloadRows(at: reloadPaths, with: .automatic)
        updateSaveButtonState()
    }
}
