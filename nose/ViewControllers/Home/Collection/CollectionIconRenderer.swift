import UIKit

enum CollectionIconRenderer {
    static func makeIconImage(
        iconName: String?,
        remoteImage: UIImage?,
        size: CGFloat
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

        let normalizedIconName = normalized(iconName)
        let hasIcon = normalizedIconName != nil || remoteImage != nil

        return renderer.image { _ in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let path = UIBezierPath(ovalIn: rect)

            if hasIcon {
                UIColor.white.setFill()
            } else {
                UIColor.systemGray5.setFill()
            }
            path.fill()

            UIColor.white.setStroke()
            path.lineWidth = 1.5
            path.stroke()

            guard let normalizedIconName else {
                if let remoteImage {
                    drawRemoteImage(remoteImage, in: rect, circlePath: path, size: size)
                }
                return
            }

            if let symbolImage = UIImage(systemName: normalizedIconName) {
                drawSymbol(symbolImage, in: rect, size: size)
            } else {
                drawEmoji(normalizedIconName, in: rect, size: size)
            }
        }
    }

    private static func normalized(_ iconName: String?) -> String? {
        guard let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func drawRemoteImage(_ image: UIImage, in rect: CGRect, circlePath: UIBezierPath, size: CGFloat) {
        guard image.size.width > 0, image.size.height > 0 else { return }

        let imageSize: CGFloat = size * 0.75
        let imageRect = CGRect(
            x: (size - imageSize) / 2,
            y: (size - imageSize) / 2,
            width: imageSize,
            height: imageSize
        )

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        circlePath.addClip()

        let aspect = image.size.width / image.size.height
        var drawRect = imageRect

        if aspect > 1 {
            let height = imageRect.width / aspect
            drawRect = CGRect(
                x: imageRect.origin.x,
                y: imageRect.origin.y + (imageRect.height - height) / 2,
                width: imageRect.width,
                height: height
            )
        } else {
            let width = imageRect.height * aspect
            drawRect = CGRect(
                x: imageRect.origin.x + (imageRect.width - width) / 2,
                y: imageRect.origin.y,
                width: width,
                height: imageRect.height
            )
        }

        image.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
        context.restoreGState()
    }

    private static func drawSymbol(_ image: UIImage, in rect: CGRect, size: CGFloat) {
        let iconSize = size * 0.55
        let iconRect = CGRect(
            x: rect.origin.x + (size - iconSize) / 2,
            y: rect.origin.y + (size - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        let aspect = image.size.width / image.size.height
        var drawRect = iconRect

        if aspect > 1 {
            let height = iconRect.width / aspect
            drawRect = CGRect(
                x: iconRect.origin.x,
                y: iconRect.origin.y + (iconRect.height - height) / 2,
                width: iconRect.width,
                height: height
            )
        } else {
            let width = iconRect.height * aspect
            drawRect = CGRect(
                x: iconRect.origin.x + (iconRect.width - width) / 2,
                y: iconRect.origin.y,
                width: width,
                height: iconRect.height
            )
        }

        let tintedIcon = image.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        tintedIcon.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
    }

    private static func drawEmoji(_ emoji: String, in rect: CGRect, size: CGFloat) {
        let fontSize = size * 0.52
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]

        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (size - textSize.height) / 2 - (size * 0.03),
            width: size,
            height: textSize.height
        )
        attributedString.draw(in: textRect.integral)
    }
}
