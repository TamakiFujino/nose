import UIKit

final class AvatarColorManager {
    static let shared = AvatarColorManager()
    private init() {}
    
    private var colorCache: [String: UIColor] = [:]
    private var hexColors: [String] = []
    
    // MARK: - Public Interface
    
    func getColor(for hex: String) -> UIColor? {
        if let cachedColor = colorCache[hex] {
            return cachedColor
        }
        
        if let color = UIColor(hex: hex) {
            colorCache[hex] = color
            return color
        }
        
        return nil
    }
    
    func getHexColors() -> [String] {
        return hexColors
    }
    
    func setHexColors(_ colors: [String]) {
        hexColors = colors
        // Clear cache when new colors are set
        colorCache.removeAll()
    }
    
    func toHexString(_ color: UIColor) -> String? {
        return color.toHexString()
    }
    
    func fromHexString(_ hex: String) -> UIColor? {
        return UIColor(hex: hex)
    }
} 