import UIKit

enum ToastType {
    case success
    case error
    case info

    var feedbackStyle: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success: return .success
        case .error: return .error
        case .info: return .warning // or use .success/.none depending on your UX design
        }
    }
}

struct ToastMessages {
    // maps - success
    static let collectionCreated = "Collection created successfully!" // done
    static let spotSavedtoCollection = "Spot saved to collection!" // done
    static let collectionDeleted = "Collection deleted" // done
    static let markSpotVisited = "Spot marked as visited!" // done
    static let completedCollection = "Collection completed!" // done
    static let collectionShared = "Collection shared successfully!"
    
    // maps - info
    static let collectionNotSelected = "No collections selected. Select at least one." // done
    static let removeSpotFromCollection = "Spot removed from collection" // done
    
    // maps - error
    static let collectionAlreadyExists = "Collection creation failed" // not implemented
    static let FailedToGetSpotInfo = "Failed to get spot information. Please try again." // done
    
    // settings
    static let nameUpdated = "Name updated successfully!"
    static let userBlocked = "User blocked successfully!"
    static let userUnblocked = "User unblocked successfully!"
    static let friendAdded = "Friend added successfully!"
    static let userUnfrined = "User Unfriended successfully!"
    
    // avatar
    static let avatarUpdated = "Avatar updated successfully!"
}
