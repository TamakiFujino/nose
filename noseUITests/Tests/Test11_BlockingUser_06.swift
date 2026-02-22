import XCTest

/// Login as User A, unblock User B, re-add as friend, re-share collection.
final class Test11_BlockingUser_06: BaseUITest {

    func test_unblock_and_reshare() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Unblock User B ---
        app.buttons["Personal Library"].tap()
        sleep(2)

        app.staticTexts["Friend List"].tap()
        sleep(2)

        app.staticTexts["Blocked"].tap()
        sleep(2)

        app.staticTexts["User B"].tap()
        sleep(2)

        app.staticTexts["Unblock User"].tap()
        sleep(2)

        app.buttons["Unblock"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // Verify User B is no longer in blocked list
        XCTAssertFalse(app.staticTexts["User B"].waitForExistence(timeout: 3),
                       "User B should no longer be in blocked list")

        // --- Re-add User B as friend ---
        app.buttons["Settings"].tap()
        sleep(2)

        app.staticTexts["Add Friend"].tap()
        sleep(2)

        let searchField = app.searchFields["Search by User ID"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        guard let userBId = TestConfig.userBId else {
            XCTFail("User B ID not found.")
            return
        }
        searchField.typeText(userBId)
        searchField.typeText("\n")
        sleep(2)

        app.buttons["add_friend_button"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // --- Re-share collection ---
        app.buttons["Settings"].tap()
        sleep(2)

        app.buttons["Back"].tap()
        sleep(2)

        NavigationHelper.openCollections(app: app)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Verify current state
        let sharedCount = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount.value as? String, "1", "Shared friends count should be 1")

        let placesCount = app.staticTexts["places_count_label"]
        XCTAssertTrue(placesCount.waitForExistence(timeout: 5))
        XCTAssertEqual(placesCount.value as? String, "2", "Number of spots should be 2")

        // Share with User B
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Share with Friends"].tap()
        sleep(2)

        app.staticTexts["User B"].tap()
        sleep(2)

        app.buttons["Update Sharing"].tap()
        sleep(2)

        // Verify shared count is now 2
        let sharedCount2 = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount2.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount2.value as? String, "2", "Shared friends count should be 2")

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
