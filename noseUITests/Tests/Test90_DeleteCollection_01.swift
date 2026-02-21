import XCTest

/// Login as User B, delete a spot from the shared collection via swipe, verify deletion.
final class Test90_DeleteCollection_01: BaseUITest {

    func test_delete_spot() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Open shared collection ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["From Friends"].tap()
        sleep(2)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Verify spot exists
        let pinnacles = app.staticTexts["Pinnacles National Park"]
        XCTAssertTrue(pinnacles.waitForExistence(timeout: 5))

        // --- Delete spot via swipe ---
        pinnacles.swipeLeft()
        sleep(2)

        // Tap the Delete button that appears after swipe
        let swipeDeleteBtn = app.buttons["Delete"]
        XCTAssertTrue(swipeDeleteBtn.waitForExistence(timeout: 5))
        swipeDeleteBtn.tap()
        sleep(2)

        // Confirm deletion in modal
        app.buttons["Delete"].tap()
        sleep(2)

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Reload and verify spot is deleted ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["From Friends"].tap()
        sleep(2)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Pinnacles should no longer exist
        XCTAssertFalse(app.staticTexts["Pinnacles National Park"].waitForExistence(timeout: 3),
                       "Deleted spot should not appear in collection")

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
