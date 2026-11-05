//
//  RegistrationUITests.swift
//  TaskFlow
//
//  Created by Natasha on 15.09.2026.
//

import XCTest

final class RegistrationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_FRESH"] = "1"
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        app.launch()
        // Wait for the launch screen / login. Cold simulator starts can be slow,
        // so allow plenty of time on the first launch.
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 45),
                      "Login screen did not appear")
    }
    
    func testSuccessfulRegistration() {
        app.launch()
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 45),
                      "Login screen did not appear")
        
        app.buttons["login.registerButton"].tap()
        
//        let heading = app.staticTexts["register.heading"]
//        XCTAssertTrue(heading.waitForExistence(timeout: 5))
//        XCTAssertEqual(heading.label,"Создать аккаунт")
//        
        app.textFields["register.emailTextField"].tap()
        app.textFields["register.emailTextField"].typeText("newuser@test.local")
        
        app.textFields["register.nameTextField"].tap()
        app.textFields["register.nameTextField"].typeText("Test User")
        
        app.secureTextFields["register.passwordTextField"].tap()
        app.secureTextFields["register.passwordTextField"].typeText("P")
        
        app.buttons["xmark"].tap()
        
        app.secureTextFields["register.passwordTextField"].typeText("upa123")
        
        app.buttons["register.submitButton"].tap()
        
        XCTAssertTrue(app.buttons["projects.createButton"].exists)
    }
    
    func testEmailOnly() {
        app.launch()
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 45),
                      "Login screen did not appear")
        
        app.buttons["login.registerButton"].tap()
        
//        let heading = app.staticTexts["register.heading"]
//        XCTAssertTrue(heading.waitForExistence(timeout: 5))
//        XCTAssertEqual(heading.label,"Создать аккаунт")
//
        app.textFields["register.emailTextField"].tap()
        app.textFields["register.emailTextField"].typeText("newuser@test.local")
        
        app.buttons["register.submitButton"].tap()
        XCTAssertTrue(app.buttons["register.submitButton"].isEnabled)
        
    }
    
}
