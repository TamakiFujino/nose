import UIKit

class CustomTabBar: UIView {

    let segmentedControl = UISegmentedControl()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCustomAppearance()
        setupSegmentedControl()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCustomAppearance()
        setupSegmentedControl()
    }

    // Setup for the custom tab bar
    private func setupCustomAppearance() {
        // Set tab bar background color
        // self.backgroundColor = UIColor.backgroundSecondary
    }

    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            segmentedControl.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.Spacing.xl),
            segmentedControl.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.Spacing.xl)
        ])

        // Set segmented control appearance
        segmentedControl.selectedSegmentTintColor = .borderSubtle
        // Set unselected control color
        segmentedControl.backgroundColor = .backgroundPrimary
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.textPrimary], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.fourthColor], for: .normal)

        // Rounded appearance
        segmentedControl.layer.cornerRadius = DesignTokens.Radii.md
        segmentedControl.layer.masksToBounds = true
    }

    // Method to configure items of the segmented control
    func configureItems(_ items: [String]) {
        segmentedControl.removeAllSegments()
        for (index, item) in items.enumerated() {
            segmentedControl.insertSegment(withTitle: item, at: index, animated: false)
        }
    }
}
