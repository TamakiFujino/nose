//
//  DesignElementViewController.swift
//  nose
//
//  Created by Tamaki Fujino on 2025/10/15.
//

import UIKit

final class DesignElementViewController: UIViewController {
    
    // MARK: - UI
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.backgroundColor = .backgroundPrimary
        return sv
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - State
    private var pillButtons: [CustomButton] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Design Elements"
        view.backgroundColor = .backgroundPrimary
        setupLayout()
        buildCatalog()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Make demo buttons fully round (pill)
        for button in pillButtons {
            button.layer.cornerRadius = button.bounds.height / 2
            button.clipsToBounds = true
        }
    }
    
    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }
    
    // MARK: - Catalog
    private func buildCatalog() {
        addButtonsSection()
        addGlassAndIconButtonsSection()
        addTabsSection()
        addMapButtonsSection()
        addToastsAndLoadingSection()
        addColorsSection()
        addTypographySection()
    }
    
    private func addSection(title: String) -> UIStackView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = DesignTokens.Spacing.md
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .textPrimary
        section.addArrangedSubview(label)
        
        let container = UIView()
        container.backgroundColor = .backgroundSecondary
        container.layer.cornerRadius = DesignTokens.Radii.md
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = DesignTokens.Spacing.md
        inner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            inner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            inner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
        
        section.addArrangedSubview(container)
        contentStack.addArrangedSubview(section)
        return inner
    }
    
    private func addButtonsSection() {
        let inner = addSection(title: "Buttons (Full Width)")
        addFullWidthButton(to: inner, title: "Primary", style: .primary, size: .large)
        addFullWidthButton(to: inner, title: "Secondary", style: .secondary, size: .large)
        addFullWidthButton(to: inner, title: "Destructive", style: .destructive, size: .large)
        addFullWidthButton(to: inner, title: "Ghost", style: .ghost, size: .large)
    }
    
    private func addGlassAndIconButtonsSection() {
        let inner = addSection(title: "Glass & Icon Buttons")
        
        let row = horizontalRow()
        
        let glass = CustomGlassButton()
        glass.setTitle("Glass", for: .normal)
        row.addArrangedSubview(glass)
        
        let icon1 = IconButton(image: UIImage(systemName: "person.fill"), action: #selector(dummyAction), target: self)
        let icon2 = IconButton(image: UIImage(systemName: "magnifyingglass"), action: #selector(dummyAction), target: self)
        row.addArrangedSubview(icon1)
        row.addArrangedSubview(icon2)
        
        let back = BackButton()
        row.addArrangedSubview(back)
        
        inner.addArrangedSubview(row)
    }
    
    private func addTabsSection() {
        let inner = addSection(title: "Tabs")
        let tabs = CustomTabBar()
        tabs.configureItems(["Personal", "Shared"])
        inner.addArrangedSubview(tabs)
    }
    
    private func addMapButtonsSection() {
        let inner = addSection(title: "Map Buttons")
        let row = horizontalRow()
        let locate = MapLocationButton()
        row.addArrangedSubview(locate)
        inner.addArrangedSubview(row)
    }
    
    private func addToastsAndLoadingSection() {
        let inner = addSection(title: "Toasts & Loading")
        let row1 = horizontalRow()
        
        let successBtn = makeButton(title: "Toast Success", style: .secondary, size: .small)
        successBtn.addTarget(self, action: #selector(showSuccessToast), for: .touchUpInside)
        let errorBtn = makeButton(title: "Toast Error", style: .secondary, size: .small)
        errorBtn.addTarget(self, action: #selector(showErrorToast), for: .touchUpInside)
        let infoBtn = makeButton(title: "Toast Info", style: .secondary, size: .small)
        infoBtn.addTarget(self, action: #selector(showInfoToast), for: .touchUpInside)
        row1.addArrangedSubview(successBtn)
        row1.addArrangedSubview(errorBtn)
        row1.addArrangedSubview(infoBtn)
        inner.addArrangedSubview(row1)
        
        let row2 = horizontalRow()
        let showLoadingBtn = makeButton(title: "Show Loading", style: .primary, size: .small)
        showLoadingBtn.addTarget(self, action: #selector(showLoading), for: .touchUpInside)
        let hideLoadingBtn = makeButton(title: "Hide Loading", style: .ghost, size: .small)
        hideLoadingBtn.addTarget(self, action: #selector(hideLoading), for: .touchUpInside)
        row2.addArrangedSubview(showLoadingBtn)
        row2.addArrangedSubview(hideLoadingBtn)
        inner.addArrangedSubview(row2)
    }
    
    private func addColorsSection() {
        let inner = addSection(title: "Colors")
        
        func colorRow(_ items: [(String, UIColor)]) -> UIStackView {
            let row = horizontalRow()
            for (name, color) in items {
                let swatch = colorSwatch(title: name, color: color)
                row.addArrangedSubview(swatch)
            }
            return row
        }
        
        inner.addArrangedSubview(colorRow([
            ("first", .firstColor), ("second", .secondColor), ("third", .thirdColor)
        ]))
        inner.addArrangedSubview(colorRow([
            ("fourth", .fourthColor)
        ]))
        inner.addArrangedSubview(colorRow([
            ("textPrimary", .textPrimary), ("textSecondary", .textSecondary), ("accent", .accent)
        ]))
        inner.addArrangedSubview(colorRow([
            ("success", .statusSuccess), ("error", .statusError), ("warning", .statusWarning)
        ]))
        inner.addArrangedSubview(colorRow([
            ("bgPrimary", .backgroundPrimary), ("bgSecondary", .backgroundSecondary), ("border", .borderSubtle)
        ]))
    }
    
    private func addTypographySection() {
        let inner = addSection(title: "Typography")
        let display = UILabel()
        display.text = "Display Large"
        display.textColor = .textPrimary
        display.font = AppFonts.displayLarge(28)
        
        let body = UILabel()
        body.text = "Body Bold 16"
        body.textColor = .textSecondary
        body.font = AppFonts.bodyBold(16)
        
        let stack = UIStackView(arrangedSubviews: [display, body])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        inner.addArrangedSubview(stack)
    }
    
    // MARK: - Builders
    private func horizontalRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fillProportionally
        row.spacing = DesignTokens.Spacing.md
        return row
    }
    
    private func makeButton(title: String, style: CustomButton.Style, size: CustomButton.Size) -> UIButton {
        let btn = CustomButton()
        btn.setTitle(title, for: .normal)
        btn.style = style
        btn.size = size
        return btn
    }
    
    private func colorSwatch(title: String, color: UIColor) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = DesignTokens.Spacing.sm
        
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = DesignTokens.Radii.sm
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 64).isActive = true
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .textSecondary
        
        container.addArrangedSubview(view)
        container.addArrangedSubview(label)
        return container
    }
    
    private func addFullWidthButton(to stack: UIStackView, title: String, style: CustomButton.Style, size: CustomButton.Size) {
        let button = makeButton(title: title, style: style, size: size)
        button.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(button)
        // Pin leading/trailing to stack's readable width by using explicit constraints
        button.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        button.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        pillButtons.append(button as? CustomButton ?? CustomButton())
    }
    
    // MARK: - Actions
    @objc private func showSuccessToast() {
        ToastManager.showToast(message: "Success toast", type: .success)
    }
    
    @objc private func showErrorToast() {
        ToastManager.showToast(message: "Error toast", type: .error)
    }
    
    @objc private func showInfoToast() {
        ToastManager.showToast(message: "Info toast", type: .info)
    }
    
    @objc private func showLoading() {
        LoadingView.shared.showOverlayLoading(on: view, message: "Loading...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.hideLoading()
        }
    }
    
    @objc private func hideLoading() {
        LoadingView.shared.hideOverlayLoading()
    }
    
    @objc private func dummyAction() {
        // No-op for demo taps
    }
}

