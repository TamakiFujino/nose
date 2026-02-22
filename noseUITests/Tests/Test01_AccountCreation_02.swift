import XCTest

/// Create User B account, add User A as friend, update name, then logout.
final class Test01_AccountCreation_02: BaseUITest {

    func test_create_user_b() {
        // --- Google Sign In ---
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 15))
        googleButton.tap()
        sleep(2)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alertContinue = springboard.buttons["Continue"]
        if alertContinue.waitForExistence(timeout: 5) {
            alertContinue.tap()
        }
        sleep(3)

        let accountLink = app.webViews.links["\(TestConfig.UserB.name) \(TestConfig.UserB.email)"]
        XCTAssertTrue(accountLink.waitForExistence(timeout: 10))
        accountLink.tap()
        sleep(2)

        if app.buttons["次へ"].waitForExistence(timeout: 5) {
            app.buttons["次へ"].tap()
        } else if app.buttons["Continue"].waitForExistence(timeout: 5) {
            app.buttons["Continue"].tap()
        }
        sleep(7)

        // --- Name Registration ---
        let titleText = app.staticTexts["What should we call you?"]
        XCTAssertTrue(titleText.waitForExistence(timeout: 15))

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        clearAndType(textField, text: TestConfig.UserB.displayName)
        app.buttons["Continue"].tap()
        sleep(5)

        // --- Accept location permission ---
        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Add User A as friend ---
        app.buttons["Personal Library"].tap()
        sleep(1)

        app.staticTexts["Add Friend"].tap()
        sleep(1)

        let searchField = app.searchFields["Search by User ID"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        guard let userAId = TestConfig.userAId else {
            XCTFail("User A ID not found. Run Test01_AccountCreation_01 first.")
            return
        }
        searchField.typeText(userAId)
        searchField.typeText("\n")
        sleep(1)

        app.buttons["add_friend_button"].tap()
        sleep(1)

        // Dismiss success modal
        app.buttons["OK"].tap()
        sleep(1)

        // --- Copy User B's ID ---
        let userIdLabel = app.staticTexts["user_id_value"]
        XCTAssertTrue(userIdLabel.waitForExistence(timeout: 5))
        let userId = userIdLabel.label
        XCTAssertFalse(userId.isEmpty, "User ID should not be empty")
        TestConfig.userBId = userId

        // Go back to Settings
        app.buttons["Settings"].tap()
        sleep(1)

        // --- Update User B's name ---
        app.staticTexts["Name"].tap()
        sleep(2)

        // Test: 1 character (too short)
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        clearAndType(nameField, text: "1")
        app.buttons["Save"].tap()
        let alert1 = app.alerts.firstMatch
        XCTAssertTrue(alert1.waitForExistence(timeout: 5))
        sleep(1)
        alert1.buttons["OK"].tap()
        sleep(1)

        // Test: 31 characters (too long)
        nameField.tap()
        clearAndType(nameField, text: "1234567890123456789012345678901")
        app.buttons["Save"].tap()
        let alert2 = app.alerts.firstMatch
        XCTAssertTrue(alert2.waitForExistence(timeout: 5))
        sleep(1)
        alert2.buttons["OK"].tap()
        sleep(1)

        // Enter valid updated name
        nameField.tap()
        clearAndType(nameField, text: TestConfig.UserB.updatedName)
        app.buttons["Save"].tap()
        sleep(2)
        app.buttons["OK"].tap()
        sleep(1)

        // Verify back on Settings screen
        let nameCell = app.staticTexts["Name"]
        XCTAssertTrue(nameCell.waitForExistence(timeout: 5))
        sleep(2)

        // Go back to Home
        app.buttons["Back"].tap()
        sleep(1)

        // --- Logout ---
        NavigationHelper.logout(app: app)

        // Dismiss any remaining modal
        app.swipeDown()
        sleep(2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)
    }
}
