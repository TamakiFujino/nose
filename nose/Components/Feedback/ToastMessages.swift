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
    static var collectionCreated: String { String(localized: "toast_collection_created") }
    static var spotSavedtoCollection: String { String(localized: "toast_spot_saved_to_collection") }
    static var collectionDeleted: String { String(localized: "toast_collection_deleted") }
    static var markSpotVisited: String { String(localized: "toast_mark_spot_visited") }
    static var completedCollection: String { String(localized: "toast_completed_collection") }
    static var collectionShared: String { String(localized: "toast_collection_shared") }
    static var collectionUpdated: String { String(localized: "toast_collection_updated") }

    // maps - info
    static var collectionNotSelected: String { String(localized: "toast_collection_not_selected") }
    static var removeSpotFromCollection: String { String(localized: "toast_remove_spot_from_collection") }

    // maps - error
    static var FailedToGetSpotInfo: String { String(localized: "toast_failed_to_get_spot_info") }

    // settings - success
    static var nameUpdated: String { String(localized: "toast_name_updated") }

    // settings - error
    static var nameUpdateFailed: String { String(localized: "toast_name_update_failed") }

    // friends - success
    static var friendAdded: String { String(localized: "toast_friend_added") }
    static var userBlocked: String { String(localized: "toast_user_blocked") }
    static var userUnblocked: String { String(localized: "toast_user_unblocked") }
    static var userUnfrined: String { String(localized: "toast_user_unfriended") }

    // friends - error
    static var userBlockFailed: String { String(localized: "toast_user_block_failed") }
    static var userUnblockFailed: String { String(localized: "toast_user_unblock_failed") }
    static var userUnfriendFailed: String { String(localized: "toast_user_unfriend_failed") }

    // avatar - success
    static var avatarUpdated: String { String(localized: "toast_avatar_updated") }
    static var avatarSaved: String { String(localized: "toast_avatar_saved") }

    // avatar - error
    static var avatarUpdateFailed: String { String(localized: "toast_avatar_update_failed") }
    static var categoriesLoadFailed: String { String(localized: "toast_categories_load_failed") }
    static var noCategoriesAvailable: String { String(localized: "toast_no_categories_available") }
}
