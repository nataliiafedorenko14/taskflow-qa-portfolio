import Foundation

// MARK: - Enums

enum Role: String, Codable, CaseIterable, Identifiable {
    case admin, manager, member, viewer
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo, in_progress, done, cancelled
    var id: String { rawValue }
    var label: String {
        switch self {
        case .todo: return "To Do"
        case .in_progress: return "In Progress"
        case .done: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, urgent
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum NetworkMode: String, Codable, CaseIterable, Identifiable {
    case normal, slow, error500 = "error500", unauthorized, empty
    case invalidJson = "invalid-json", conflict
    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - User

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let fullName: String
    let role: Role

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case fullName = "full_name"
    }
}

struct Token: Codable {
    let accessToken: String
    let tokenType: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}

// MARK: - Project

struct Project: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let ownerId: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case ownerId = "owner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProjectMember: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let projectId: Int
    let projectRole: String
    let fullName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case projectId = "project_id"
        case projectRole = "project_role"
        case fullName = "full_name"
        case email
    }
}

// MARK: - TaskItem
// (Named TaskItem to avoid clashing with Swift's concurrency `Task`.)

struct TaskItem: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var description: String
    var status: TaskStatus
    var priority: Priority
    let projectId: Int
    var assigneeId: Int?
    var reporterId: Int?
    var dueDate: String?
    var tags: [String]
    var assignee: User?
    var reporter: User?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, priority, tags, assignee, reporter
        case projectId = "project_id"
        case assigneeId = "assignee_id"
        case reporterId = "reporter_id"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TaskPage: Codable {
    let items: [TaskItem]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
}

// MARK: - Comment

struct Comment: Codable, Identifiable, Hashable {
    let id: Int
    let taskId: Int
    let authorId: Int?
    let authorName: String?
    let body: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, body
        case taskId = "task_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Tag

struct Tag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String
}

// MARK: - Notification

struct AppNotification: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let type: String
    let message: String
    let read: Bool
    let taskId: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, message, read
        case userId = "user_id"
        case taskId = "task_id"
        case createdAt = "created_at"
    }
}

// MARK: - Request payloads

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case email, password
        case fullName = "full_name"
    }
}

struct TaskCreateRequest: Codable {
    let title: String
    let description: String
    let status: TaskStatus
    let priority: Priority
    let assigneeId: Int?
    let dueDate: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case title, description, status, priority, tags
        case assigneeId = "assignee_id"
        case dueDate = "due_date"
    }
}

struct TaskUpdateRequest: Codable {
    var title: String?
    var description: String?
    var status: TaskStatus?
    var priority: Priority?
    var assigneeId: Int?
    var dueDate: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case title, description, status, priority, tags
        case assigneeId = "assignee_id"
        case dueDate = "due_date"
    }
}

struct CommentRequest: Codable {
    let body: String
}

struct NetworkModeRequest: Codable {
    let mode: String
}
