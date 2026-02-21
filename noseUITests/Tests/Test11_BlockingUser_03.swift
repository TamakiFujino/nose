import XCTest

/// Login as User B, unblock User A.
final class Test11_BlockingUser_03: BaseUITest {

    func test_unblock_user() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Unblock User A ---
        app.buttons["Personal Library"].tap()
        sleep(2)

        app.staticTexts["Friend List"].tap()
        sleep(2)

        app.staticTexts["Blocked"].tap()
        sleep(2)

        app.staticTexts["User A"].tap()
        sleep(2)

        app.staticTexts["Unblock User"].tap()
        sleep(2)

        app.buttons["Unblock"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // Verify User A is no longer in blocked list
        XCTAssertFalse(app.staticTexts["User A"].waitForExistence(timeout: 3),
                       "User A should no longer be in blocked list")

        // Go back to Settings
        app.buttons["Settings"].tap()
        sleep(2)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
