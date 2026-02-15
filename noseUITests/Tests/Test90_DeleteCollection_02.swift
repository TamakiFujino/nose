import XCTest

/// Login as User A, unshare collection, delete remaining spot, delete the collection entirely.
final class Test90_DeleteCollection_02: BaseUITest {

    func test_delete_collection() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Unshare the collection ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Verify Pinnacles was already deleted by User B
        XCTAssertFalse(app.staticTexts["Pinnacles National Park"].waitForExistence(timeout: 3),
                       "Pinnacles should have been deleted by User B")

        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Share with Friends"].tap()
        sleep(2)

        // Deselect User B
        app.staticTexts[TestConfig.UserB.updatedName].tap()
        sleep(2)

        // Verify "Will be removed" text
        XCTAssertTrue(app.staticTexts["Will be removed"].waitForExistence(timeout: 3))

        app.buttons["Update Sharing"].tap()
        sleep(2)

        // Verify shared count is 1
        let sharedCount = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount.value as? String, "1", "Shared friends count should be 1")

        // --- Delete spot via swipe ---
        let kingsCanyon = app.staticTexts["Kings Canyon National Park"]
        XCTAssertTrue(kingsCanyon.exists)

        kingsCanyon.swipeLeft()
        sleep(2)

        let swipeDeleteBtn = app.buttons["Delete"]
        XCTAssertTrue(swipeDeleteBtn.waitForExistence(timeout: 5))
        swipeDeleteBtn.tap()
        sleep(2)

        // Confirm deletion
        app.buttons["Delete"].tap()
        sleep(2)

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Reload and verify spot is deleted ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        XCTAssertFalse(app.staticTexts["Kings Canyon National Park"].waitForExistence(timeout: 3),
                       "Deleted spot should not appear")

        // --- Delete the collection ---
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Delete Collection"].tap()
        sleep(2)

        app.buttons["Delete"].tap()
        sleep(5)

        // Verify we're back at "My Collections"
        XCTAssertTrue(app.staticTexts["My Collections"].waitForExistence(timeout: 5))

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)

        // --- Reload and verify collection is deleted ---
        NavigationHelper.openCollections(app: app)

        XCTAssertFalse(app.staticTexts["National Parks"].waitForExistence(timeout: 3),
                       "Deleted collection should not appear")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
