import UIKit

// Centralized typography tokens for consistent fonts across the app
enum AppFonts {
    // Display / Headlines
    static func displayLarge(_ size: CGFloat = 32) -> UIFont {
        return UIFont(name: "Gotham-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }

    static func displayMedium(_ size: CGFloat = 24) -> UIFont {
        return UIFont(name: "Gotham-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }

    static func title(_ size: CGFloat = 20) -> UIFont {
        return UIFont(name: "Gotham-Medium", size: size) ?? UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    // Body
    static func body(_ size: CGFloat = 16) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func bodyBold(_ size: CGFloat = 16) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .bold)
    }

    // Caption / Small
    static func caption(_ size: CGFloat = 12) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }
}


