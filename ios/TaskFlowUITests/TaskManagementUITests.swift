//
//  TaskManagementUITests.swift
//  TaskFlow
//
//  Created by Natasha on 09.11.2026.
//

import XCTest

/// UI tests for the task management flow: create/edit/delete and validation.
///
/// Require the server to be running (./run.sh). Each test launches the app
/// with `UITEST_FRESH`, which resets the server DB to the seed baseline —
/// so tests are independent.
final class TaskManagementUITests: XCTestCase {

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

    /// Log in as the seeded `member` (email is pre-filled).
    private func login() {
        let pwd = app.secureTextFields["login.passwordTextField"]
        XCTAssertTrue(pwd.waitForExistence(timeout: 10))
        pwd.tap()
        pwd.typeText("member123")
        app.buttons["login.submitButton"].tap()
    }

    /// On recent iOS versions SwiftUI list rows are exposed as Cells whose
    /// inner Button is not hittable, so cells are tapped by center coordinate.
    /// The first tap may land while the screen is still settling, so retry
    /// until the expected marker of the destination screen appears.
    private func tapCellUntil(_ cell: XCUIElement, shows marker: XCUIElement,
                              file: StaticString = #filePath, line: UInt = #line) {
        for _ in 1...3 {
            if marker.waitForExistence(timeout: 3) { return }
            cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(marker.waitForExistence(timeout: 5),
                      "Expected screen did not appear", file: file, line: line)
    }

    private func openMainProject() {
        let row = app.buttons["projects.row.Mobile QA Automation"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Main project did not appear")
        let cell = app.cells.containing(.button, identifier: "projects.row.Mobile QA Automation").firstMatch
        tapCellUntil(cell, shows: app.buttons["tasks.createButton"])
    }

    /// A task row is a button with an aggregated accessibility label that
    /// starts with the task title ("<title>, <status>, ...").
    private func taskRow(titled title: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", title)
        return app.buttons.matching(predicate).firstMatch
    }

    /// Creates a task with the given title via the UI and waits until it
    /// appears in the list.
    private func createTask(title: String) {
        XCTAssertTrue(app.buttons["tasks.createButton"].waitForExistence(timeout: 10))
        app.buttons["tasks.createButton"].tap()
        let titleField = app.textFields["task.titleTextField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.typeText(title)
        app.buttons["task.saveButton"].tap()
        XCTAssertTrue(taskRow(titled: title).waitForExistence(timeout: 15),
                      "Created task did not appear in the list")
    }

    // MARK: - Create + Delete (full CRUD cycle)

    func testCreateAndDeleteTask() {
        login()
        openMainProject()
        createTask(title: "Task To Delete")

        // Open the task details. The row button has no identifier, so we
        // tap the button found by its label (coordinate tap does not need
        // hittability, and the button fills the whole cell).
        tapCellUntil(taskRow(titled: "Task To Delete"), shows: app.buttons["task.editButton"])

        // Edit sheet -> Delete.
        app.buttons["task.editButton"].tap()
        XCTAssertTrue(app.buttons["task.deleteButton"].waitForExistence(timeout: 10))
        app.buttons["task.deleteButton"].tap()

        // The detail view stays open after delete and fails to reload the
        // removed task — go back to the list.
        XCTAssertTrue(app.buttons["BackButton"].waitForExistence(timeout: 10))
        app.buttons["BackButton"].tap()

        // Refresh the list and verify the task is gone.
        XCTAssertTrue(app.buttons["tasks.createButton"].waitForExistence(timeout: 10))
        if app.cells.firstMatch.waitForExistence(timeout: 5) {
            app.cells.firstMatch.swipeDown()
        }
        XCTAssertFalse(taskRow(titled: "Task To Delete").waitForExistence(timeout: 5),
                       "Deleted task is still visible in the list")
    }

    // MARK: - Edit status

    func testEditTaskChangesStatus() {
        login()
        openMainProject()

        // Open any seeded task.
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        tapCellUntil(app.cells.firstMatch, shows: app.buttons["task.editButton"])
        app.buttons["task.editButton"].tap()

        // Change the status via the picker.
        let statusPicker = app.buttons["task.statusPicker"]
        XCTAssertTrue(statusPicker.waitForExistence(timeout: 10))
        statusPicker.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        app.buttons["task.saveButton"].tap()

        // The detail view reloads and shows the updated status badge.
        XCTAssertTrue(app.staticTexts["Done"].waitForExistence(timeout: 10),
                      "Status was not updated to Done")
    }

    // MARK: - Validation (negative)

    func testSaveButtonDisabledForEmptyTitle() {
        login()
        openMainProject()

        XCTAssertTrue(app.buttons["tasks.createButton"].waitForExistence(timeout: 10))
        app.buttons["tasks.createButton"].tap()
        let titleField = app.textFields["task.titleTextField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))

        let saveButton = app.buttons["task.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))

        // Empty title -> Save must be disabled.
        XCTAssertFalse(saveButton.isEnabled,
                       "Save must be disabled while the title is empty")

        // Filled title -> Save becomes available.
        titleField.tap()
        titleField.typeText("Validation task")
        XCTAssertTrue(saveButton.isEnabled,
                      "Save must be enabled when the title is filled")

        // Cleared again -> disabled again.
        titleField.deleteText()
        XCTAssertFalse(saveButton.isEnabled,
                       "Save must be disabled after the title is cleared")
    }
}
