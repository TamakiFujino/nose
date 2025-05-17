import UIKit

extension Avatar3DViewController {

    // Note: loadSelectionState calls these, so it should be in an extension that can see these,
    // or these should be public if loadSelectionState is in a different extension.
    // For now, assuming they are called from within the same class or its extensions.
    func updateUIForSelectedItem() {
        // Implementation for updating UI when an item is selected
    }

    func updateUIForNoSelection() {
        // Implementation for updating UI when no item is selected
    }
} 