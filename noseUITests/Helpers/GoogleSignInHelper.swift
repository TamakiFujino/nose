import XCTest

enum GoogleSignInHelper {

    /// Performs Google Sign-In for a test user.
    static func signIn(app: XCUIApplication, email: String, name: String) {
        // Tap "Continue with Google" button
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 15),
                      "Continue with Google button not found")
        googleButton.tap()
        sleep(2)

        // Handle iOS system alert ("nose wants to use google.com to sign in")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let continueAlertButton = springboard.buttons["Continue"]
        if continueAlertButton.waitForExistence(timeout: 5) {
            continueAlertButton.tap()
        }
        sleep(3)

        // Select user account in Google WebView
        let accountLink = app.webViews.links["\(name) \(email)"]
        XCTAssertTrue(accountLink.waitForExistence(timeout: 10),
                      "Google account '\(name) \(email)' not found in picker")
        accountLink.tap()
        sleep(2)

        // Tap Continue / 次へ on consent screen
        if app.buttons["Continue"].waitForExistence(timeout: 5) {
            app.buttons["Continue"].tap()
        } else if app.staticTexts["Continue"].waitForExistence(timeout: 3) {
            app.staticTexts["Continue"].tap()
        } else if app.buttons["次へ"].waitForExistence(timeout: 3) {
            app.buttons["次へ"].tap()
        } else if app.staticTexts["次へ"].waitForExistence(timeout: 3) {
            app.staticTexts["次へ"].tap()
        }
        sleep(10)
    }
}
