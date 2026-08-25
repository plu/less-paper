import ApiInterface
import Foundation
import XCTest

@MainActor
public struct ServerFormScreen {

    public let app: XCUIApplication

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.timeout = timeout
    }

    @discardableResult
    public func addServer(
        alias: String,
        url: URL,
        username: String,
        password: String
    ) throws -> Bool {
        let addButton = app.navigationBars.buttons["Add server"]
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        // The domain field takes host and port only; the scheme is a separate picker that
        // defaults to https, which the container does not serve.
        app.buttons["Scheme, https://"].tap()
        app.buttons["\(url.scheme ?? "http")://"].tap()

        type(try url.hostAndPort.get(), into: app.textFields["Domain"])
        type(username, into: app.textFields["Username"])
        type(password, into: app.secureTextFields["Password"])
        type(alias, into: app.textFields["Alias"])

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    private func type(
        _ text: String,
        into element: XCUIElement
    ) {
        guard element.waitForExistence(timeout: timeout) else {
            return
        }
        element.tap()
        app.typeText(text)
    }
}
