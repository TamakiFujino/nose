import XCTest

/// Login as User B (non-owner), block User A, verify blocked state and collection isolation.
final class Test11_BlockingUser_01: BaseUITest {

    func test_blocking_user_as_non_owner() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Block User A ---
        app.buttons["Personal Library"].tap()
        sleep(2)

        app.staticTexts["Friend List"].tap()
        sleep(2)

        app.staticTexts["User A"].tap()
        sleep(2)

        app.staticTexts["Block User"].tap()
        sleep(2)

        app.buttons["Block"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // --- Verify User A is in blocked list ---
        app.staticTexts["Blocked"].tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["User A"].exists, "User A should be in blocked list")

        // --- Verify collection is not shared with blocked user ---
        app.buttons["Settings"].tap()
        sleep(2)

        app.buttons["Back"].tap()
        sleep(2)

        // Reset timeline position
        let middleDot = app.buttons["middle_dot"]
        if middleDot.waitForExistence(timeout: 3) {
            middleDot.tap()
            sleep(2)
        }

        // Search for a spot and check shared collections
        app.buttons["Search"].tap()
        sleep(2)

        let searchBar = app.searchFields["Search for a place"]
        XCTAssertTrue(searchBar.waitForExistence(timeout: 5))
        searchBar.tap()
        searchBar.typeText("yose")
        sleep(2)
        searchBar.typeText("mite ")
        sleep(2)
        searchBar.typeText("National")
        sleep(2)

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Yosemite National Park"].waitForExistence(timeout: 5))

        app.buttons["bookmark"].tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Save to Collection"].waitForExistence(timeout: 5))

        app.staticTexts["From Friends"].tap()
        sleep(2)

        // National Parks should NOT be available
        XCTAssertFalse(app.staticTexts["National Parks"].waitForExistence(timeout: 3),
                       "Blocked user's collection should not be visible")

        app.buttons["Close"].tap()
        sleep(2)

        // Dismiss place detail
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // --- Verify shared collection is NOT listed ---
        NavigationHelper.openCollections(app: app)

        app.staticTexts["From Friends"].tap()
        sleep(2)

        XCTAssertFalse(app.staticTexts["National Parks"].waitForExistence(timeout: 3),
                       "Blocked user's collection should not appear in From Friends")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
