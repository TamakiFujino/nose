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
    static let collectionCreated = "Collection created successfully!"
    static let spotSavedtoCollection = "Spot saved to collection!"
    static let collectionDeleted = "Collection deleted"
    static let markSpotVisited = "Spot marked as visited!"
    static let completedCollection = "Collection completed!"
    static let collectionShared = "Collection shared successfully!"
    
    // maps - info
    static let collectionNotSelected = "No collections selected. Select at least one."
    static let removeSpotFromCollection = "Spot removed from collection"
    
    // maps - error
    // static let collectionAlreadyExists = "Collection creation failed"
    static let FailedToGetSpotInfo = "Failed to get spot information. Please try again."
    
    // settings - success
    static let nameUpdated = "Name updated successfully!"
    
    // settings - error
    static let nameUpdateFailed = "Name update failed. Please try again."
    
    // friends - success
    static let friendAdded = "Friend added successfully!"
    static let userBlocked = "User blocked"
    static let userUnblocked = "User unblocked"
    static let userUnfrined = "User Unfriended"
    
    // friends - error
    static let userBlockFailed = "User block failed. Please try again."
    static let userUnblockFailed = "User unblock failed. Please try again."
    static let userUnfriendFailed = "User Unfriend failed. Please try again."
    
    // avatar - success
    static let avatarUpdated = "Avatar updated successfully!"
    
    // avatar - error
    static let avatarUpdateFailed = "Avatar update failed. Please try again."
    static let categoriesLoadFailed = "Failed to load categories. Please try again."
}
