import UIKit

extension UIColor {
    static func fromHex(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }

        guard hexSanitized.count == 6 else { return UIColor.gray } // Default if invalid

        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    // Define colors using Hex
    static let firstColor = UIColor.fromHex("#FFFFFF")
    static let secondColor = UIColor.fromHex("#ECEFF4")
    static let thirdColor = UIColor.fromHex("#D8DEE9")
    static let fourthColor = UIColor.fromHex("#4C566A")
    static let fifthColor = UIColor.fromHex("#434C5E")
    static let sixthColor = UIColor.fromHex("#3B4252")
}
