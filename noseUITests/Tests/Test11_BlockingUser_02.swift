import XCTest

/// Login as User A (owner), verify User B is no longer shared (was blocked by B).
final class Test11_BlockingUser_02: BaseUITest {

    func test_verify_blocked_owner_side() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Verify shared friends count decreased ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Shared friends count should be 1 (only owner)
        let sharedCount = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount.value as? String, "1", "Shared friends count should be 1")

        // --- Verify User B is not in share list ---
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Share with Friends"].tap()
        sleep(2)

        XCTAssertFalse(app.staticTexts["User B"].waitForExistence(timeout: 3),
                       "Blocked User B should not appear in share list")

        app.buttons["close"].tap()
        sleep(2)

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
