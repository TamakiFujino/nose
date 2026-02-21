import XCTest

/// Login as User B, verify shared collection is gone, try adding deleted User A, then delete account.
final class Test99_DeleteAccount_02: BaseUITest {

    func test_delete_account_user_b() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Verify shared collection with User A is gone ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["From Friends"].tap()
        sleep(2)

        XCTAssertFalse(app.staticTexts["National Parks"].waitForExistence(timeout: 3),
                       "Deleted user's collection should not appear")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)

        // --- Try to add deleted User A as friend ---
        app.buttons["Personal Library"].tap()
        sleep(2)

        app.staticTexts["Add Friend"].tap()
        sleep(2)

        let searchField = app.searchFields["Search by User ID"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        guard let userAId = TestConfig.userAId else {
            XCTFail("User A ID not found.")
            return
        }
        searchField.typeText(userAId)
        searchField.typeText("\n")
        sleep(2)

        // The add_friend_button may or may not appear depending on deletion timing
        let addFriendBtn = app.buttons["add_friend_button"]
        if addFriendBtn.waitForExistence(timeout: 3) {
            addFriendBtn.tap()
            sleep(2)
        }

        // Verify "User Not Found" message
        XCTAssertTrue(app.staticTexts["User Not Found"].waitForExistence(timeout: 5))

        app.buttons["OK"].tap()
        sleep(2)

        // Go back to Settings
        app.buttons["Settings"].tap()
        sleep(2)

        // --- Delete Account ---
        app.staticTexts["Account"].tap()
        sleep(2)

        app.staticTexts["Delete Account"].tap()

        app.buttons["Confirm"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // Verify we're back at the login screen
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 10),
                      "Should be back at login screen after account deletion")
    }
}
