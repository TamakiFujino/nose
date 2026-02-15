import XCTest

/// Login as User B, verify being blocked by User A: can't add as friend, collection not visible.
final class Test11_BlockingUser_05: BaseUITest {

    func test_verify_being_blocked() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Try to add User A as friend (should fail - blocked) ---
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

        // Verify "User Not Found" message (because blocked)
        XCTAssertTrue(app.staticTexts["User Not Found"].waitForExistence(timeout: 5))

        app.buttons["OK"].tap()
        sleep(2)

        // --- Verify collection is NOT visible ---
        app.buttons["Settings"].tap()
        sleep(2)

        app.buttons["Back"].tap()
        sleep(2)

        NavigationHelper.openCollections(app: app)

        app.staticTexts["From Friends"].tap()
        sleep(2)

        XCTAssertFalse(app.staticTexts["National Parks"].waitForExistence(timeout: 3),
                       "Blocked owner's collection should not be visible")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
