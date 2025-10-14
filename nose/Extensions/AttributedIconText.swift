import UIKit

enum AttributedIconText {
    static func iconWithText(
        systemName: String,
        tintColor: UIColor,
        text: String,
        textColor: UIColor? = nil,
        font: UIFont = .systemFont(ofSize: 14)
    ) -> NSAttributedString {
        let attachment = NSTextAttachment()
        if let image = UIImage(systemName: systemName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal) {
            attachment.image = image
        }

        let iconString = NSAttributedString(attachment: attachment)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor ?? tintColor,
            .font: font
        ]
        let textString = NSAttributedString(string: " \(text)", attributes: attributes)

        let result = NSMutableAttributedString()
        result.append(iconString)
        result.append(textString)
        return result
    }
}


