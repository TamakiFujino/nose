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
        // self.backgroundColor = UIColor.secondColor
    }

    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            segmentedControl.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20)
        ])

        // Set segmented control appearance
        segmentedControl.selectedSegmentTintColor = .thirdColor
        // Set unselected control color
        segmentedControl.backgroundColor = .firstColor // Set background color for unselected tabs
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.sixthColor], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.sixthColor], for: .normal)
    }

    // Method to configure items of the segmented control
    func configureItems(_ items: [String]) {
        segmentedControl.removeAllSegments()
        for (index, item) in items.enumerated() {
            segmentedControl.insertSegment(withTitle: item, at: index, animated: false)
        }
    }
}
