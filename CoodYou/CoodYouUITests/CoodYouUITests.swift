//
//  CoodYouUITests.swift
//  CoodYouUITests
//
//  Created by Hassam Gani on 27/09/25.
//

import XCTest

final class CoodYouUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testAuthEmailValidation() throws {
        let app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["auth.emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 2))
        emailField.tap()
        emailField.typeText("invalid")

        let passwordField = app.secureTextFields["auth.passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 1))
        passwordField.tap()
        passwordField.typeText("secret123")

        let primaryButton = app.buttons["auth.primaryButton"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 1))
        primaryButton.tap()

        let inlineError = app.otherElements["auth.inlineError"]
        XCTAssertTrue(inlineError.waitForExistence(timeout: 1))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
