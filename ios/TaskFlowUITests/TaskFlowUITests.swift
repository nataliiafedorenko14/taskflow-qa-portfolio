import XCTest

/// XCUITest UI tests for the TaskFlow app.
///
/// These require the server to be running (./run.sh) so the the app can reach
/// http://localhost:8000. Each test launches the app with `UITEST_FRESH`, which
/// makes the app reset the server DB to the seed baseline, reset the network
/// mode, and start logged out — so tests are independent.
final class TaskFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_FRESH"] = "1"
        app.launch()
        // Wait for the launch screen / login. Cold simulator starts can be slow,
        // so allow plenty of time on the first launch.
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 45),
                      "Login screen did not appear")
    }

    /// Log in as the seeded `member` (email is pre-filled; only the password
    /// needs to be entered). `password` lets a test use a wrong value.
    private func login(password: String = "member123") {
        let pwd = app.secureTextFields["login.passwordTextField"]
        XCTAssertTrue(pwd.waitForExistence(timeout: 10))
        pwd.tap()
        pwd.typeText(password)
        app.buttons["login.submitButton"].tap()
    }

    // MARK: - Auth

    func testLoginSuccessShowsProjects() {
        login()
        XCTAssertTrue(app.staticTexts["Mobile QA Automation"].waitForExistence(timeout: 20),
                      "Projects did not appear after login")
    }

    func testLoginFailureShowsError() {
        login(password: "wrong")
        XCTAssertTrue(app.staticTexts["login.errorLabel"].waitForExistence(timeout: 10),
                      "Error label did not appear on bad credentials")
    }

    // MARK: - Tasks

    func testCreateTaskAppearsInList() {
        login()
        XCTAssertTrue(app.staticTexts["Mobile QA Automation"].waitForExistence(timeout: 20))
        app.staticTexts["Mobile QA Automation"].tap()

        app.buttons["tasks.createButton"].tap()
        let title = app.textFields["task.titleTextField"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("UI Test Task")

        app.buttons["task.saveButton"].tap()

        XCTAssertTrue(app.staticTexts["UI Test Task"].waitForExistence(timeout: 15),
                      "Created task did not appear in the list")
    }

    func testAddComment() {
        login()
        XCTAssertTrue(app.staticTexts["Mobile QA Automation"].waitForExistence(timeout: 20))
        app.staticTexts["Mobile QA Automation"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        app.cells.firstMatch.tap()

        let field = app.textFields["task.commentTextField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("UI Test Comment")
        app.buttons["task.addCommentButton"].tap()

        XCTAssertTrue(app.staticTexts["UI Test Comment"].waitForExistence(timeout: 10),
                      "Comment did not appear")
    }

    func testSearchTasks() {
        login()
        XCTAssertTrue(app.staticTexts["Mobile QA Automation"].waitForExistence(timeout: 20))
        app.staticTexts["Mobile QA Automation"].tap()

        let search = app.textFields["tasks.searchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("login\n")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10),
                      "Search returned no rows")
    }

    func testFilterByStatus() {
        login()
        XCTAssertTrue(app.staticTexts["Mobile QA Automation"].waitForExistence(timeout: 20))
        app.staticTexts["Mobile QA Automation"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))

        app.buttons["tasks.filterButton"].tap()
        XCTAssertTrue(app.buttons["filter.status.todo"].waitForExistence(timeout: 10))
        app.buttons["filter.status.todo"].tap()
        XCTAssertTrue(app.buttons["filter.doneButton"].waitForExistence(timeout: 10))
        app.buttons["filter.doneButton"].tap()
        // After applying a todo filter the list still shows rows (seed has todo tasks).
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10),
                      "Filtered list did not reload")
    }

    // MARK: - Session

    func testLogoutReturnsToLogin() {
        login()
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Profile"].tap()
        app.buttons["profile.logoutButton"].tap()
        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: 10),
                      "Did not return to login after logout")
    }

    // MARK: - Network error + retry

    func testNetworkErrorShowsRetryAndRecovers() {
        login()
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 20))

        // Switch the server into the 500 mode.
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["profile.networkMode.error500"].waitForExistence(timeout: 10))
        app.buttons["profile.networkMode.error500"].tap()

        // Returning to Projects forces a reload. Depending on the platform it
        // either fails immediately (no cells to swipe) or still shows cached
        // rows (swipe to refresh). Handle both so the test is stable.
        app.tabBars.buttons["Projects"].tap()
        if !app.buttons["error.retryButton"].exists,
           app.cells.firstMatch.waitForExistence(timeout: 3) {
            app.cells.firstMatch.swipeDown()
        }
        XCTAssertTrue(app.buttons["error.retryButton"].waitForExistence(timeout: 10),
                      "Retry button did not appear on network error")

        // Restore normal mode and give the server a moment to apply it.
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["profile.networkMode.normal"].waitForExistence(timeout: 10))
        app.buttons["profile.networkMode.normal"].tap()
        _ = app.staticTexts["Network mode: normal"].waitForExistence(timeout: 10)
        sleep(2)

        // Back to Projects. If the error screen is still showing, tap Retry;
        // otherwise the list already reloaded on appear. Either way the seeded
        // project should become visible.
        app.tabBars.buttons["Projects"].tap()
        if app.buttons["error.retryButton"].waitForExistence(timeout: 3) {
            app.buttons["error.retryButton"].tap()
        }
        XCTAssertTrue(app.staticTexts["Mobile QA Automation"].waitForExistence(timeout: 10),
                      "List did not recover after retry")
    }
}
