import XCTest

/// Login as User B, verify completed collection is not in active shared, verify it IS in completed tab.
final class Test03_CompleteCollection_02: BaseUITest {

    func test_completed_collection_shared() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Verify collection is NOT in active shared "Save to Collection" ---
        app.buttons["Search"].tap()
        sleep(2)

        let searchBar = app.searchFields["Search for a place"]
        XCTAssertTrue(searchBar.waitForExistence(timeout: 5))
        searchBar.tap()
        searchBar.typeText("Pin")
        sleep(2)
        searchBar.typeText("nacles ")
        sleep(2)
        searchBar.typeText("National")
        sleep(2)

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Pinnacles National Park"].waitForExistence(timeout: 5))

        app.buttons["bookmark"].tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Save to Collection"].waitForExistence(timeout: 5))

        app.staticTexts["From Friends"].tap()
        sleep(2)

        // National Parks should NOT be in shared collections (it's completed)
        XCTAssertFalse(app.staticTexts["National Parks"].waitForExistence(timeout: 3),
                       "Completed collection should not appear in active shared list")

        app.buttons["Close"].tap()
        sleep(1)

        // Dismiss place detail
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // --- Verify collection IS in completed tab ---
        NavigationHelper.openCompletedCollections(app: app)

        XCTAssertTrue(app.staticTexts["Completed Collections"].waitForExistence(timeout: 5))

        app.staticTexts["From Friends"].tap()
        sleep(2)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Verify spots are listed
        XCTAssertTrue(app.staticTexts["Kings Canyon National Park"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pinnacles National Park"].exists)

        // Verify "More" button is NOT visible (non-owner)
        XCTAssertFalse(app.buttons["More"].exists, "More button should not exist for non-owner")

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
