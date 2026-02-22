import XCTest

/// Login as User A, search a spot, create "National Parks" collection, add spot, share with User B.
final class Test02_CollectionCreation_01: BaseUITest {

    func test_create_collection() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Search a spot ---
        app.buttons["Search"].tap()
        sleep(2)

        let searchBar = app.searchFields["Search for a place"]
        XCTAssertTrue(searchBar.waitForExistence(timeout: 5))
        searchBar.tap()
        searchBar.typeText("Kings ")
        sleep(1)
        searchBar.typeText("Canyon ")
        sleep(2)
        searchBar.typeText("National ")
        sleep(2)

        // Tap first search result
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()
        sleep(2)

        // Verify place title
        XCTAssertTrue(app.staticTexts["Kings Canyon National Park"].waitForExistence(timeout: 5))

        // Tap bookmark to save
        app.buttons["bookmark"].tap()
        sleep(2)

        // Verify "Save to Collection" modal
        XCTAssertTrue(app.staticTexts["Save to Collection"].waitForExistence(timeout: 5))

        // --- Create a new collection ---
        app.buttons["add"].tap()
        sleep(2)

        let collectionNameField = app.textFields.firstMatch
        XCTAssertTrue(collectionNameField.waitForExistence(timeout: 5))
        collectionNameField.tap()
        collectionNameField.typeText("National Parks")

        app.buttons["Create"].tap()
        sleep(2)

        // --- Add spot to the collection ---
        app.staticTexts["National Parks"].tap()
        sleep(2)

        app.buttons["Save"].tap()
        sleep(2)

        // Dismiss place detail
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // --- Check collection content ---
        NavigationHelper.openCollections(app: app)

        // Verify "My Collections" title
        XCTAssertTrue(app.staticTexts["My Collections"].waitForExistence(timeout: 5))

        // Open the collection
        app.staticTexts["National Parks"].tap()
        sleep(2)

        // Verify spot is listed
        XCTAssertTrue(app.staticTexts["Kings Canyon National Park"].waitForExistence(timeout: 5))

        // Verify places count is 1
        let placesCount = app.staticTexts["places_count_label"]
        XCTAssertTrue(placesCount.waitForExistence(timeout: 5))
        XCTAssertEqual(placesCount.value as? String, "1", "Number of spots should be 1")

        // --- Share collection with User B ---
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Share with Friends"].tap()
        sleep(2)

        app.staticTexts[TestConfig.UserB.updatedName].tap()
        sleep(2)

        app.buttons["Update Sharing"].tap()
        sleep(2)

        // Verify shared friends count is 2
        let sharedCount = app.staticTexts["shared_friends_count_label"]
        XCTAssertTrue(sharedCount.waitForExistence(timeout: 5))
        XCTAssertEqual(sharedCount.value as? String, "2", "Shared friends count should be 2")

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
