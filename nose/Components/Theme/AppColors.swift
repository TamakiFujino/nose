import UIKit

extension UIColor {
    convenience init?(hex: String) {
            var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if hexSanitized.hasPrefix("#") {
                hexSanitized.remove(at: hexSanitized.startIndex)
            }
            var rgbValue: UInt64 = 0
            guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return nil }

            switch hexSanitized.count {
            case 6: // RRGGBB
                self.init(
                    red:   CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                    blue:  CGFloat(rgbValue & 0x0000FF) / 255.0,
                    alpha: 1.0
                )
            case 8: // RRGGBBAA
                self.init(
                    red:   CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0,
                    blue:  CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0,
                    alpha: CGFloat(rgbValue & 0x000000FF) / 255.0
                )
            default:
                return nil
            }
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
    static let firstColor = UIColor(hex: "#FFFFFF") ?? .white
    static let secondColor = UIColor(hex: "#ECEFF4") ?? .lightGray
    static let thirdColor = UIColor(hex: "#D8DEE9") ?? .lightGray
    static let fourthColor = UIColor(hex: "#4C566A") ?? .darkGray
    static let fifthColor = UIColor(hex: "#434C5E") ?? .darkGray
    static let sixthColor = UIColor(hex: "#3B4252") ?? .black
    static let redColor = UIColor(hex: "#EE2725") ?? .red
    static let greenColor = UIColor(hex: "#D9F4D5") ?? .green
    static let blueColor = UIColor(hex: "#A6B6D3") ?? .blue
    static let purpleColor = UIColor(hex: "#8E8BBA") ?? .purple

    // Semantic aliases
    static let backgroundPrimary = UIColor.firstColor
    static let backgroundSecondary = UIColor.secondColor
    static let borderSubtle = UIColor.thirdColor
    static let textSecondary = UIColor.fourthColor
    static let textPrimary = UIColor.sixthColor
    static let accent = UIColor.blueColor
    static let statusError = UIColor.redColor
    static let statusSuccess = UIColor.greenColor
    // No orange in palette; warnings map to red for now
    static let statusWarning = UIColor.redColor

}
