import XCTest

/// Login as User A, complete the "National Parks" collection.
final class Test03_CompleteCollection_01: BaseUITest {

    func test_collection_complete() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Open collections ---
        NavigationHelper.openCollections(app: app)

        XCTAssertTrue(app.staticTexts["My Collections"].waitForExistence(timeout: 5))

        app.staticTexts["National Parks"].tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Kings Canyon National Park"].waitForExistence(timeout: 5))

        // --- Complete the collection ---
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Complete the Collection"].tap()
        sleep(2)

        app.buttons["Complete"].tap()
        sleep(5)

        // Dismiss modal
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
