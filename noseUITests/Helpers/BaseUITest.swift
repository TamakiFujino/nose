import XCTest

class BaseUITest: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Element \(element.debugDescription) did not appear within \(timeout)s")
        return element
    }

    func tapButton(_ identifier: String, timeout: TimeInterval = 10) {
        let button = app.buttons[identifier]
        waitForElement(button, timeout: timeout)
        button.tap()
    }

    func tapStaticText(_ text: String, timeout: TimeInterval = 10) {
        let staticText = app.staticTexts[text]
        waitForElement(staticText, timeout: timeout)
        staticText.tap()
    }

    func clearTextField(_ element: XCUIElement) {
        element.tap()
        guard let currentValue = element.value as? String, !currentValue.isEmpty else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        element.typeText(deleteString)
    }

    func clearAndType(_ element: XCUIElement, text: String) {
        clearTextField(element)
        element.typeText(text)
    }

    func dismissSystemAlert(timeout: TimeInterval = 5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow While Using App"]
        if allowButton.waitForExistence(timeout: timeout) {
            allowButton.tap()
        }
    }

    func dismissAnyAlert(timeout: TimeInterval = 3) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: timeout) {
            let allow = alert.buttons["Allow While Using App"]
            let ok = alert.buttons["OK"]
            let allow2 = alert.buttons["Allow"]
            if allow.exists { allow.tap() }
            else if ok.exists { ok.tap() }
            else if allow2.exists { allow2.tap() }
        }
    }

    func elementExists(_ identifier: String, type: XCUIElement.ElementType = .any, timeout: TimeInterval = 3) -> Bool {
        let element: XCUIElement
        switch type {
        case .button:
            element = app.buttons[identifier]
        case .staticText:
            element = app.staticTexts[identifier]
        default:
            element = app.descendants(matching: .any)[identifier]
        }
        return element.waitForExistence(timeout: timeout)
    }
}
