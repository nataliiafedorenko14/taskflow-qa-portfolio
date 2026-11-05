//
//  AuthUITests.swift
//  TaskFlow
//
//  Created by Natasha on 14.09.2026.
//

import XCTest

final class AuthUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            for label in ["Not Now", "Never", "Don’t Save", "Don't Save"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
        app = XCUIApplication()
        app.launchEnvironment["UITEST_FRESH"] = "1"
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        app.launch()
        // Wait for the launch screen / login. Cold simulator starts can be slow,
        // so allow plenty of time on the first launch.
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 45),
                      "Login screen did not appear")
    }
    
    func testSuccessfulLogin() {
        
        let emailField = app.textFields["login.emailTextField"]
        let passwordField = app.secureTextFields["login.passwordTextField"]
        let loginButton = app.buttons["login.submitButton"]
        
        emailField.tap()
        emailField.press(forDuration: 1.0)
        emailField.doubleTap()
        emailField.typeText("")
        emailField.typeText("member@test.local")
        
        passwordField.tap()
        passwordField.typeText("member123")
        
        loginButton.tap()
        app.dismissSavePasswordPromptIfPresent()
        
        let project = app.buttons["projects.row.Mobile QA Automation"]
        XCTAssertTrue(project.waitForExistence(timeout: 20))
    }
    
    func testNoDataToLogin() {
        let emailField = app.textFields["login.emailTextField"]
        let passwordField = app.secureTextFields["login.passwordTextField"]
        let loginButton = app.buttons["login.submitButton"]
        
        emailField.deleteText()
        
        passwordField.tap()
        passwordField.typeText("")
        
        loginButton.tap()
        
        let errorMessage = app.staticTexts["login.errorLabel"]

        XCTAssertTrue(
            errorMessage.waitForExistence(timeout: 5)
        )

        XCTAssertEqual(
            errorMessage.label,
            "Invalid email or password"
        )
        
    }
    
    func testAuthWrongData() {
        
        let emailField = app.textFields["login.emailTextField"]
        let passwordField = app.secureTextFields["login.passwordTextField"]
        let loginButton = app.buttons["login.submitButton"]
        
        emailField.tap()
        emailField.deleteText()
        emailField.typeText("admin@test.local")
        
        passwordField.tap()
        passwordField.typeText("member123")
        
        loginButton.tap()
        
        let errorMessage = app.staticTexts["login.errorLabel"]

        XCTAssertTrue(
            errorMessage.waitForExistence(timeout: 5)
        )

        XCTAssertEqual(
            errorMessage.label,
            "Invalid email or password"
        )
        
    }
    
    func testAdminLoginAndCreateProject() {
        let emailField = app.textFields["login.emailTextField"]
        let passwordField = app.secureTextFields["login.passwordTextField"]
        let loginButton = app.buttons["login.submitButton"]
        
        emailField.deleteText()
        emailField.typeText("admin@test.local")
        
        passwordField.tap()
        passwordField.typeText("admin123")
        
        loginButton.tap()
        app.dismissSavePasswordPromptIfPresent()
        
        let createProjectButton = app.buttons["projects.createButton"]
        XCTAssertTrue(createProjectButton.waitForExistence(timeout: 20),
                      "Projects screen did not appear after admin login")
        createProjectButton.tap()
        
        let nameField = app.textFields["project.nameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("ProjectAdmin")
        
        app.buttons["project.createButton"].tap()
        
        let createdProject = app.buttons["projects.row.ProjectAdmin"]
        XCTAssertTrue(createdProject.waitForExistence(timeout: 20),
                      "Created project ProjectAdmin did not appear in the list")
    }
}
