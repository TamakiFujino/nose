import XCTest

/// Login as User B, add a spot to the shared collection, verify collection content.
final class Test02_CollectionCreation_02: BaseUITest {

    func test_collection_shared() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserB.email, name: TestConfig.UserB.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Search a spot ---
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

        // Switch to shared collections tab
        app.staticTexts["From Friends"].tap()
        sleep(2)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        app.buttons["Save"].tap()
        sleep(2)

        // Dismiss place detail
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // --- See the shared collection detail ---
        NavigationHelper.openCollections(app: app)

        // Switch to shared tab
        app.staticTexts["From Friends"].tap()
        sleep(2)

        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Verify places count is 2
        let placesCount = app.staticTexts["places_count_label"]
        XCTAssertTrue(placesCount.waitForExistence(timeout: 5))
        XCTAssertEqual(placesCount.value as? String, "2", "Number of spots should be 2")

        // Verify both spots are listed
        XCTAssertTrue(app.staticTexts["Kings Canyon National Park"].exists)
        XCTAssertTrue(app.staticTexts["Pinnacles National Park"].exists)

        // Verify "More" button is NOT visible (non-owner)
        XCTAssertFalse(app.buttons["More"].exists, "More button should not exist for non-owner")

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
