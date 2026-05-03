import Foundation
import Firebase

/// Centralized manager for Firebase Analytics event logging.
/// Provides a unified interface for tracking user behavior and app usage.
enum AnalyticsManager {

    // MARK: - Screen Tracking

    /// Log a screen view event.
    /// - Parameters:
    ///   - screenName: Name of the screen (e.g., "Home", "Settings")
    ///   - screenClass: Optional class name (defaults to screen name)
    static func logScreen(_ screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: screenName,
                AnalyticsParameterScreenClass: screenClass ?? screenName
            ]
        )
        Logger.log("Screen viewed: \(screenName)", level: .debug, category: "Analytics")
    }

    // MARK: - User Events

    /// Log user sign up completion.
    /// - Parameter method: Sign-in method (e.g., "google", "apple")
    static func logSignUp(method: String) {
        Analytics.logEvent(
            AnalyticsEventSignUp,
            parameters: [AnalyticsParameterMethod: method]
        )
        Logger.log("User signed up: \(method)", level: .info, category: "Analytics")
    }

    /// Log user login.
    /// - Parameter method: Sign-in method (e.g., "google", "apple")
    static func logLogin(method: String) {
        Analytics.logEvent(
            AnalyticsEventLogin,
            parameters: [AnalyticsParameterMethod: method]
        )
        Logger.log("User logged in: \(method)", level: .info, category: "Analytics")
    }

    // MARK: - Collection Events

    /// Log collection creation.
    /// - Parameters:
    ///   - success: Whether creation succeeded
    ///   - placeCount: Number of places in the collection (optional)
    static func logCollectionCreated(success: Bool, placeCount: Int? = nil) {
        var parameters: [String: Any] = ["success": success]
        if let count = placeCount {
            parameters["place_count"] = count
        }
        Analytics.logEvent("collection_created", parameters: parameters)
        Logger.log("Collection created: success=\(success)", level: .info, category: "Analytics")
    }

    /// Log place added to collection.
    static func logPlaceAdded() {
        Analytics.logEvent("place_added_to_collection", parameters: nil)
        Logger.log("Place added to collection", level: .debug, category: "Analytics")
    }

    /// Log collection deletion.
    static func logCollectionDeleted() {
        Analytics.logEvent("collection_deleted", parameters: nil)
        Logger.log("Collection deleted", level: .info, category: "Analytics")
    }

    /// Log collection sharing.
    /// - Parameter method: Share method (e.g., "link", "qr_code")
    static func logCollectionShared(method: String) {
        Analytics.logEvent(
            AnalyticsEventShare,
            parameters: ["content_type": "collection", "method": method]
        )
        Logger.log("Collection shared: \(method)", level: .info, category: "Analytics")
    }

    // MARK: - Event Events

    /// Log event creation.
    /// - Parameter success: Whether creation succeeded
    static func logEventCreated(success: Bool) {
        Analytics.logEvent(
            "event_created",
            parameters: ["success": success]
        )
        Logger.log("Event created: success=\(success)", level: .info, category: "Analytics")
    }

    /// Log event deletion.
    static func logEventDeleted() {
        Analytics.logEvent("event_deleted", parameters: nil)
        Logger.log("Event deleted", level: .info, category: "Analytics")
    }

    // MARK: - Social Events

    /// Log friend added.
    /// - Parameter method: Method used (e.g., "qr_code", "user_id")
    static func logFriendAdded(method: String) {
        Analytics.logEvent(
            "friend_added",
            parameters: ["method": method]
        )
        Logger.log("Friend added: \(method)", level: .info, category: "Analytics")
    }

    /// Log user blocked.
    static func logUserBlocked() {
        Analytics.logEvent("user_blocked", parameters: nil)
        Logger.log("User blocked", level: .info, category: "Analytics")
    }

    // MARK: - Avatar Events

    /// Log avatar customization started.
    static func logAvatarCustomizationStarted() {
        Analytics.logEvent("avatar_customization_started", parameters: nil)
        Logger.log("Avatar customization started", level: .debug, category: "Analytics")
    }

    /// Log avatar saved.
    static func logAvatarSaved() {
        Analytics.logEvent("avatar_saved", parameters: nil)
        Logger.log("Avatar saved", level: .info, category: "Analytics")
    }

    // MARK: - Search Events

    /// Log search performed.
    /// - Parameter hasResults: Whether search returned results
    static func logSearch(hasResults: Bool) {
        Analytics.logEvent(
            AnalyticsEventSearch,
            parameters: ["has_results": hasResults]
        )
        Logger.log("Search performed: hasResults=\(hasResults)", level: .debug, category: "Analytics")
    }

    // MARK: - User Properties

    /// Set user property.
    /// - Parameters:
    ///   - value: Property value (max 36 chars)
    ///   - name: Property name
    static func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
        Logger.log("User property set: \(name)=\(value ?? "nil")", level: .debug, category: "Analytics")
    }

    /// Set user ID.
    /// - Parameter userID: Firebase Auth user ID
    static func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
        Logger.log("User ID set: \(userID ?? "nil")", level: .info, category: "Analytics")
    }

    // MARK: - Custom Events

    /// Log a custom event with optional parameters.
    /// - Parameters:
    ///   - name: Event name (alphanumeric + underscore, max 40 chars)
    ///   - parameters: Event parameters (optional, max 25 per event)
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
        let paramString = parameters?.description ?? "none"
        Logger.log("Custom event: \(name) (\(paramString))", level: .debug, category: "Analytics")
    }
}
