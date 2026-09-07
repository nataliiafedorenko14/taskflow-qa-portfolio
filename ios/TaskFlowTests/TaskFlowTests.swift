import XCTest
@testable import TaskFlow

/// Small, server-independent unit tests that illustrate the testing pattern
/// and guard the model layer.
final class TaskFlowTests: XCTestCase {

    private let decoder = JSONDecoder()

    func testDecodeUser() throws {
        let json = """
        {"id": 1, "email": "a@b.c", "full_name": "Jane", "role": "admin"}
        """.data(using: .utf8)!
        let user = try decoder.decode(User.self, from: json)
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.email, "a@b.c")
        XCTAssertEqual(user.role, .admin)
    }

    func testDecodeTaskItem() throws {
        let json = """
        {"id": 7, "title": "Write tests", "description": "cover api",
         "status": "in_progress", "priority": "high",
         "project_id": 2, "assignee_id": 15, "reporter_id": 8,
         "due_date": "2026-12-31", "tags": ["ios", "automation"],
         "assignee": null, "reporter": null,
         "created_at": "2026-08-27T10:00:00", "updated_at": "2026-08-27T10:30:00"}
        """.data(using: .utf8)!
        let task = try decoder.decode(TaskItem.self, from: json)
        XCTAssertEqual(task.title, "Write tests")
        XCTAssertEqual(task.status, .in_progress)
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.tags, ["ios", "automation"])
        XCTAssertEqual(task.dueDate, "2026-12-31")
    }

    func testNetworkModeRawValues() {
        XCTAssertEqual(NetworkMode.invalidJson.rawValue, "invalid-json")
        XCTAssertEqual(NetworkMode.error500.rawValue, "error500")
    }

    func testTaskStatusLabels() {
        XCTAssertFalse(TaskStatus.in_progress.label.isEmpty)
        XCTAssertNotEqual(TaskStatus.todo.label, TaskStatus.done.label)
    }

    func testTokenStoreRoundTrip() {
        let store = TokenStore()
        store.clear()
        XCTAssertNil(store.token)
        store.save("abc")
        XCTAssertEqual(store.token, "abc")
        store.clear()
        XCTAssertNil(store.token)
    }
}