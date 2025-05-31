import UIKit

extension UIColor {
    static func fromHex(_ hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }

        guard hexSanitized.count == 6 else { return nil } // Return nil if invalid

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return nil }

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }

    // Define colors using Hex
    static let firstColor = UIColor.fromHex("#FFFFFF") ?? .white
    static let secondColor = UIColor.fromHex("#ECEFF4") ?? .lightGray
    static let thirdColor = UIColor.fromHex("#D8DEE9") ?? .lightGray
    static let fourthColor = UIColor.fromHex("#4C566A") ?? .darkGray
    static let fifthColor = UIColor.fromHex("#434C5E") ?? .darkGray
    static let sixthColor = UIColor.fromHex("#3B4252") ?? .black
}
