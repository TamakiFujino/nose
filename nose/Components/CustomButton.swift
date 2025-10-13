import UIKit

class CustomButton: UIButton {
    enum Style {
        case primary
        case secondary
        case destructive
        case ghost
    }

    enum Size {
        case small
        case medium
        case large
    }

    var style: Style = .primary { didSet { applyStyle() } }
    var size: Size = .medium { didSet { applyStyle() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        clipsToBounds = true
        adjustsImageWhenHighlighted = true
        applyStyle()
    }

    private func applyStyle() {
        // Typography by size
        switch size {
        case .small:
            titleLabel?.font = AppFonts.bodyBold(14)
            layer.cornerRadius = DesignTokens.Radii.sm
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
            contentEdgeInsets = UIEdgeInsets(top: DesignTokens.Spacing.sm, left: DesignTokens.Spacing.md, bottom: DesignTokens.Spacing.sm, right: DesignTokens.Spacing.md)
        case .medium:
            titleLabel?.font = AppFonts.bodyBold(16)
            layer.cornerRadius = DesignTokens.Radii.md
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            contentEdgeInsets = UIEdgeInsets(top: DesignTokens.Spacing.md, left: DesignTokens.Spacing.lg, bottom: DesignTokens.Spacing.md, right: DesignTokens.Spacing.lg)
        case .large:
            titleLabel?.font = AppFonts.bodyBold(18)
            layer.cornerRadius = DesignTokens.Radii.lg
            heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
            contentEdgeInsets = UIEdgeInsets(top: DesignTokens.Spacing.lg, left: DesignTokens.Spacing.xl, bottom: DesignTokens.Spacing.lg, right: DesignTokens.Spacing.xl)
        }

        // Colors by style
        switch style {
        case .primary:
            backgroundColor = .fourthColor
            setTitleColor(.firstColor, for: .normal)
            layer.borderWidth = 0
            layer.borderColor = UIColor.clear.cgColor
        case .secondary:
            backgroundColor = .firstColor
            setTitleColor(.sixthColor, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = UIColor.borderSubtle.cgColor
        case .destructive:
            backgroundColor = .firstColor
            setTitleColor(.statusError, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = UIColor.statusError.cgColor
        case .ghost:
            backgroundColor = .clear
            setTitleColor(.sixthColor, for: .normal)
            layer.borderWidth = 0
            layer.borderColor = UIColor.clear.cgColor
        }
    }
}
