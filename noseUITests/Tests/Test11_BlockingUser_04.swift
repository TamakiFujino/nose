import XCTest

/// Login as User A (owner), re-add User B as friend, share collection, then block User B.
final class Test11_BlockingUser_04: BaseUITest {

    func test_blocking_user_as_owner() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Add User B as a friend ---
        app.buttons["Personal Library"].tap()
        sleep(1)

        app.staticTexts["Add Friend"].tap()
        sleep(1)

        let searchField = app.searchFields["Search by User ID"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        guard let userBId = TestConfig.userBId else {
            XCTFail("User B ID not found. Run Test01_AccountCreation_02 first.")
            return
        }
        searchField.typeText(userBId)
        searchField.typeText("\n")
        sleep(1)

        app.buttons["add_friend_button"].tap()
        sleep(1)

        app.buttons["OK"].tap()
        sleep(1)

        app.buttons["Settings"].tap()
        sleep(1)

        // --- Share collection with User B ---
        app.buttons["Back"].tap()
        sleep(1)

        NavigationHelper.openCollections(app: app)

        app.staticTexts["National Parks"].tap()
        sleep(1)

        app.buttons["More"].tap()
        sleep(1)

        app.staticTexts["Share with Friends"].tap()
        sleep(1)

        app.staticTexts["User B"].tap()
        sleep(1)

        app.buttons["Update Sharing"].tap()
        sleep(1)

        // Verify shared friends count is 2
        let sharedCount = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount.value as? String, "2", "Shared friends count should be 2")

        // Dismiss collection modal
        NavigationHelper.dismissModal(app: app)

        // --- Block User B ---
        app.buttons["Personal Library"].tap()
        sleep(2)

        app.staticTexts["Friend List"].tap()
        sleep(2)

        app.staticTexts["User B"].tap()
        sleep(2)

        app.staticTexts["Block User"].tap()
        sleep(2)

        app.buttons["Block"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // --- Verify User B is in blocked list ---
        app.staticTexts["Blocked"].tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["User B"].exists, "User B should be in blocked list")

        // --- Try to add blocked user as friend ---
        app.buttons["Settings"].tap()
        sleep(2)

        app.staticTexts["Add Friend"].tap()
        sleep(2)

        let searchField2 = app.searchFields["Search by User ID"]
        XCTAssertTrue(searchField2.waitForExistence(timeout: 5))
        searchField2.tap()
        searchField2.typeText(userBId)
        searchField2.typeText("\n")
        sleep(2)

        // Dismiss error modal
        app.buttons["OK"].tap()
        sleep(2)

        // --- Verify collection is no longer shared ---
        app.buttons["Settings"].tap()
        sleep(2)

        app.buttons["Back"].tap()
        sleep(2)

        NavigationHelper.openCollections(app: app)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Shared friends count should be 1
        let sharedCount2 = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount2.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount2.value as? String, "1", "Shared friends count should be 1")

        // Places count should be 2
        let placesCount = app.staticTexts["places_count_label"]
        XCTAssertTrue(placesCount.waitForExistence(timeout: 5))
        XCTAssertEqual(placesCount.value as? String, "2", "Number of spots should be 2")

        // Verify User B is NOT in share list
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Share with Friends"].tap()
        sleep(2)

        XCTAssertFalse(app.staticTexts["User B"].waitForExistence(timeout: 3),
                       "Blocked User B should not appear in share list")

        app.buttons["close"].tap()
        sleep(3)

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
