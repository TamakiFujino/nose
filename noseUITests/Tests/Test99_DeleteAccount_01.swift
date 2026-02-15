import XCTest

/// Login as User A, check settings items (privacy, terms, version, licenses), then delete account.
final class Test99_DeleteAccount_01: BaseUITest {

    func test_settings_and_delete_account() {
        // --- Login ---
        GoogleSignInHelper.signIn(app: app, email: TestConfig.UserA.email, name: TestConfig.UserA.name)

        NavigationHelper.dismissLocationPermission(app: app)
        sleep(1)

        // --- Check settings items ---
        app.buttons["Personal Library"].tap()
        sleep(2)

        // Privacy Policy
        app.staticTexts["Privacy Policy"].tap()
        sleep(5)
        app.buttons["Settings"].tap()
        sleep(2)

        // Terms of Service
        app.staticTexts["Terms of Service"].tap()
        sleep(5)
        app.buttons["Settings"].tap()
        sleep(2)

        // App Version
        let appVersion = app.staticTexts["App Version"]
        XCTAssertTrue(appVersion.exists, "App Version cell should be visible")

        let appVersionText = app.staticTexts["app_version_text"]
        XCTAssertTrue(appVersionText.exists, "App version text should be visible")

        // Licenses
        app.staticTexts["Licenses"].tap()
        sleep(2)

        app.staticTexts["AppAuth"].tap()
        sleep(2)

        // Verify license detail
        let licenseTitle = app.staticTexts.firstMatch
        XCTAssertTrue(licenseTitle.exists)
        sleep(2)

        // Go back to Licenses list
        app.buttons["Licenses"].tap()
        sleep(2)

        // Go back to Settings
        app.buttons["Settings"].tap()
        sleep(2)

        // --- Delete Account ---
        app.staticTexts["Account"].tap()
        sleep(2)

        app.staticTexts["Delete Account"].tap()

        app.buttons["Confirm"].tap()
        sleep(2)

        app.buttons["OK"].tap()
        sleep(2)

        // Verify we're back at the login screen
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 10),
                      "Should be back at login screen after account deletion")
    }
}
