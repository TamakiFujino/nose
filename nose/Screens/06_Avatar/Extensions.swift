import UIKit
import RealityKit // Added because MaterialColorParameter is from RealityKit

// Helper for safe array indexing
internal extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Helper to compare tint color in SimpleMaterial
internal extension MaterialColorParameter {
    var tintedColor: UIColor? {
        switch self {
        case .color(let color): return color
        default: return nil
        }
    }
} 