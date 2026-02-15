import XCTest

/// Login as User A, put back the completed "National Parks" collection.
final class Test03_CompleteCollection_03: BaseUITest {

    func test_collection_put_back() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Open completed collections ---
        NavigationHelper.openCompletedCollections(app: app)

        XCTAssertTrue(app.staticTexts["Completed Collections"].waitForExistence(timeout: 5))

        app.staticTexts["National Parks"].tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Kings Canyon National Park"].waitForExistence(timeout: 5))

        // --- Put back the collection ---
        app.buttons["More"].tap()
        sleep(2)

        app.staticTexts["Put back collection"].tap()
        sleep(5)

        // Dismiss modal
        NavigationHelper.dismissModal(app: app)

        // --- Logout ---
        NavigationHelper.logout(app: app)
    }
}
