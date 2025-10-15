import UIKit

enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radii {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Shadow {
        static let color: CGColor = UIColor.sixthColor.withAlphaComponent(0.2).cgColor
        static let offset: CGSize = CGSize(width: 0, height: 2)
        static let radius: CGFloat = 4
        static let opacity: Float = 1.0
    }

    enum Animation {
        static let fast: TimeInterval = 0.15
        static let normal: TimeInterval = 0.3
    }
}


