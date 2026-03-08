import Foundation

/// Handles Unity responses and forwards them to UnityManager
@objc public class UnityResponseHandler: NSObject {
    @objc public static let shared = UnityResponseHandler()
    private override init() { super.init() }
    
    /// Handle Unity response - call this method from your iOS Unity integration
    @objc public func handleUnityResponse(_ response: String) {
        Logger.log("UnityResponseHandler: Received response from Unity: \(response)", level: .debug, category: "UnityResponse")
        
        // Forward the response to UnityManager asynchronously
        Task { @MainActor in
            UnityManager.shared.handleUnityResponse(response)
        }
    }
    
    /// Static entrypoint for C-callable shim
    @objc public static func handleUnityResponseStatic(_ response: String) {
        UnityResponseHandler.shared.handleUnityResponse(response)
    }
}
