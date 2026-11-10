//
//  ProjectsAccessUITests.swift
//  TaskFlow
//
//  Created by Natasha on 10.11.2026.
//

import XCTest

/// UI tests for project visibility rules driven by the seed data:
/// `member` belongs only to "Mobile QA Automation", so "Backend Refactor"
/// must stay hidden; `empty` has no memberships at all and must see the
/// empty state instead of a list.
///
/// Require the server to be running (./run.sh). Each test launches the app
/// with `UITEST_FRESH`, which resets the server DB to the seed baseline —
/// so tests are independent.
final class ProjectsAccessUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_FRESH"] = "1"
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        app.launch()
        // Cold simulator starts can be slow, allow plenty of time.
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 45),
                      "Login screen did not appear")
    }

    // MARK: - Helpers

    /// Log in as an arbitrary seeded user. The email field is pre-filled
    /// with `member@test.local`, so it is cleared first.
    private func login(email: String, password: String) {
        let emailField = app.textFields["login.emailTextField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.deleteText()
        emailField.typeText(email)

        let pwd = app.secureTextFields["login.passwordTextField"]
        XCTAssertTrue(pwd.waitForExistence(timeout: 10))
        pwd.tap()
        pwd.typeText(password)

        app.buttons["login.submitButton"].tap()
        app.dismissSavePasswordPromptIfPresent()
    }

    // MARK: - Access control

    func testMemberSeesOnlyOwnProject() {
        login(email: "member@test.local", password: "member123")

        // The member's own project is listed...
        XCTAssertTrue(app.buttons["projects.row.Mobile QA Automation"].waitForExistence(timeout: 20),
                      "Own project did not appear after login")

        // ...while a project the member does not belong to stays hidden.
        XCTAssertFalse(app.buttons["projects.row.Backend Refactor"].exists,
                       "Member must not see a project they are not assigned to")
        XCTAssertFalse(app.buttons["projects.row.Onboarding"].exists,
                       "Member must not see a project they are not assigned to")
    }

    // MARK: - Empty state

    func testUserWithoutProjectsSeesEmptyState() {
        login(email: "empty@test.local", password: "empty123")

        // No memberships -> the empty state is shown instead of the list.
        // (The "projects.empty" identifier sits on the container VStack, so
        // assert on the visible text instead.)
        XCTAssertTrue(app.staticTexts["No projects yet"].waitForExistence(timeout: 20),
                      "Empty state did not appear for a user without projects")
        XCTAssertFalse(app.buttons["projects.row.Mobile QA Automation"].exists,
                       "No project rows must be visible for a user without projects")
    }
}
