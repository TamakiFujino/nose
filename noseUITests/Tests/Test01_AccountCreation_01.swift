import XCTest

/// Create User A account, validate name input, copy user ID, then logout.
final class Test01_AccountCreation_01: BaseUITest {

    func test_create_user_a() {
        // --- Google Sign In ---
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 15))
        googleButton.tap()
        sleep(2)

        // Accept iOS system alert
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alertContinue = springboard.buttons["Continue"]
        if alertContinue.waitForExistence(timeout: 5) {
            alertContinue.tap()
        }
        sleep(3)

        // Select Google account
        let accountLink = app.webViews.links["\(TestConfig.UserA.name) \(TestConfig.UserA.email)"]
        XCTAssertTrue(accountLink.waitForExistence(timeout: 10))
        accountLink.tap()
        sleep(2)

        // Tap Continue on consent screen
        if app.buttons["Continue"].waitForExistence(timeout: 5) {
            app.buttons["Continue"].tap()
        } else if app.buttons["次へ"].waitForExistence(timeout: 5) {
            app.buttons["次へ"].tap()
        }
        sleep(7)

        // --- Name Registration ---
        let titleText = app.staticTexts["What should we call you?"]
        XCTAssertTrue(titleText.waitForExistence(timeout: 15))

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()

        // Test: 1 character (too short)
        textField.typeText("1")
        app.buttons["Continue"].tap()
        let errorAlert1 = app.alerts["Error"]
        XCTAssertTrue(errorAlert1.waitForExistence(timeout: 5))
        errorAlert1.buttons["OK"].tap()
        sleep(1)

        // Test: 31 characters (too long)
        textField.tap()
        clearAndType(textField, text: "1234567890123456789012345678901")
        app.buttons["Continue"].tap()
        let errorAlert2 = app.alerts["Error"]
        XCTAssertTrue(errorAlert2.waitForExistence(timeout: 5))
        errorAlert2.buttons["OK"].tap()
        sleep(1)

        // Enter valid name "User A"
        textField.tap()
        clearAndType(textField, text: TestConfig.UserA.displayName)
        app.buttons["Continue"].tap()
        sleep(5)

        // --- Accept location permission ---
        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Copy User ID ---
        app.buttons["Personal Library"].tap()
        sleep(1)

        // Navigate to Add Friend screen
        app.staticTexts["Add Friend"].tap()
        sleep(1)
        app.staticTexts["Add Friend"].tap()
        sleep(1)

        // Read user ID directly from label
        let userIdLabel = app.staticTexts["user_id_value"]
        XCTAssertTrue(userIdLabel.waitForExistence(timeout: 5))
        let userId = userIdLabel.label
        XCTAssertFalse(userId.isEmpty, "User ID should not be empty")

        // Tap copy button
        app.buttons["copy"].tap()
        sleep(1)

        // Save user ID for later tests
        TestConfig.userAId = userId

        // Go back to Settings
        app.buttons["Settings"].tap()
        sleep(1)

        // Go back to Home
        app.buttons["Back"].tap()
        sleep(1)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
