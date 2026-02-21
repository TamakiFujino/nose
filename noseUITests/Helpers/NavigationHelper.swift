import XCTest

enum NavigationHelper {

    /// Perform logout: Settings → Account → Logout → Confirm → OK
    static func logout(app: XCUIApplication) {
        let personalLibrary = app.buttons["Personal Library"]
        XCTAssertTrue(personalLibrary.waitForExistence(timeout: 10))
        personalLibrary.tap()
        sleep(2)

        app.staticTexts["Account"].tap()
        sleep(1)

        app.staticTexts["Logout"].tap()
        sleep(1)

        app.buttons["Confirm"].tap()
        sleep(1)

        app.buttons["OK"].tap()
        sleep(1)
    }

    /// Navigate to collections: right_dot → sparkle
    static func openCollections(app: XCUIApplication) {
        let rightDot = app.buttons["right_dot"]
        XCTAssertTrue(rightDot.waitForExistence(timeout: 5))
        rightDot.tap()
        sleep(2)

        let sparkle = app.buttons["sparkle"]
        XCTAssertTrue(sparkle.waitForExistence(timeout: 5))
        sparkle.tap()
        sleep(2)
    }

    /// Navigate to completed collections: left_dot → archive
    static func openCompletedCollections(app: XCUIApplication) {
        let leftDot = app.buttons["left_dot"]
        XCTAssertTrue(leftDot.waitForExistence(timeout: 5))
        leftDot.tap()
        sleep(2)

        let archive = app.buttons["archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.tap()
        sleep(2)
    }

    /// Dismiss location permission alert if shown
    static func dismissLocationPermission(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow While Using App"]
        if allowButton.waitForExistence(timeout: 5) {
            allowButton.tap()
        }
    }

    /// Navigate to Settings via Personal Library button
    static func goToSettings(app: XCUIApplication) {
        let personalLibrary = app.buttons["Personal Library"]
        XCTAssertTrue(personalLibrary.waitForExistence(timeout: 10))
        personalLibrary.tap()
        sleep(1)
    }

    /// Dismiss modal by swiping down and tapping outside
    static func dismissModal(app: XCUIApplication) {
        app.swipeDown()
        sleep(2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        sleep(2)
    }
}
