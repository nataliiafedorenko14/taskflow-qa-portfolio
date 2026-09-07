import Foundation

/// Thin async/await REST client over URLSession.
///
/// The base URL defaults to `http://localhost:8000` (the iOS Simulator maps
/// `localhost` to the host Mac, so it reaches the server started via ./run.sh).
/// It can be changed at runtime from the Profile > Developer screen so that
/// UI tests can point at a custom port.
final class APIClient: ObservableObject {

    @Published private(set) var baseURL: URL

    private let session: URLSession
    private let tokenStore: TokenStore

    init(baseURL: URL = APIClient.defaultBaseURL(),
         session: URLSession = .shared,
         tokenStore: TokenStore = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    static func defaultBaseURL() -> URL {
        if let saved = UserDefaults.standard.string(forKey: "baseURL"), let url = URL(string: saved) {
            return url
        }
        return URL(string: "http://localhost:8000")!
    }

    func setBaseURL(_ url: URL) {
        self.baseURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: "baseURL")
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> Token {
        try await post("/api/auth/login", body: LoginRequest(email: email, password: password))
    }

    func register(email: String, password: String, fullName: String) async throws -> User {
        try await post("/api/auth/register",
                       body: RegisterRequest(email: email, password: password, fullName: fullName))
    }

    func me() async throws -> User {
        try await get("/api/auth/me")
    }

    // MARK: - Projects

    func projects() async throws -> [Project] {
        try await get("/api/projects")
    }

    func createProject(name: String, description: String) async throws -> Project {
        struct Body: Codable { let name: String; let description: String }
        return try await post("/api/projects", body: Body(name: name, description: description))
    }

    func projectMembers(_ id: Int) async throws -> [ProjectMember] {
        try await get("/api/projects/\(id)/members")
    }

    func projectTasks(_ id: Int) async throws -> [TaskItem] {
        try await get("/api/projects/\(id)/tasks")
    }

    // MARK: - Tasks

    func tasks(page: Int = 1, pageSize: Int = 50, status: TaskStatus? = nil,
                priority: Priority? = nil, assigneeId: Int? = nil,
                projectId: Int? = nil, tag: String? = nil, query: String? = nil)
        async throws -> TaskPage {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        if let status { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let priority { items.append(URLQueryItem(name: "priority", value: priority.rawValue)) }
        if let assigneeId { items.append(URLQueryItem(name: "assignee_id", value: String(assigneeId))) }
        if let projectId { items.append(URLQueryItem(name: "project_id", value: String(projectId))) }
        if let tag { items.append(URLQueryItem(name: "tag", value: tag)) }
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return try await get("/api/tasks", queryItems: items)
    }

    func task(_ id: Int) async throws -> TaskItem {
        try await get("/api/tasks/\(id)")
    }

    func createTask(projectId: Int, request: TaskCreateRequest) async throws -> TaskItem {
        try await post("/api/projects/\(projectId)/tasks", body: request)
    }

    func updateTask(_ id: Int, request: TaskUpdateRequest) async throws -> TaskItem {
        try await patch("/api/tasks/\(id)", body: request)
    }

    func deleteTask(_ id: Int) async throws {
        try await requestVoid(method: "DELETE", path: "/api/tasks/\(id)")
    }

    // MARK: - Comments

    func comments(taskId: Int) async throws -> [Comment] {
        try await get("/api/tasks/\(taskId)/comments")
    }

    func createComment(taskId: Int, body: String) async throws -> Comment {
        try await post("/api/tasks/\(taskId)/comments", body: CommentRequest(body: body))
    }

    // MARK: - Tags

    func tags() async throws -> [Tag] {
        try await get("/api/tags")
    }

    // MARK: - Test controls

    func resetDatabase() async throws {
        try await requestVoid(method: "POST", path: "/api/test/reset")
    }

    func setNetworkMode(_ mode: NetworkMode) async throws {
        struct Resp: Codable { let mode: String }
        let resp: Resp = try await post("/api/test-controls/network-mode",
                                        body: NetworkModeRequest(mode: mode.rawValue))
        _ = resp
    }

    func resetNetworkMode() async throws {
        struct Resp: Codable { let mode: String }
        let resp: Resp = try await requestEmpty(method: "POST",
                                                path: "/api/test-controls/network-mode/reset",
                                                as: Resp.self)
        _ = resp
    }

    // MARK: - Core request helpers

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(method: "GET", path: path, queryItems: queryItems, body: Optional<EmptyBody>.none)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    private func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "PATCH", path: path, body: body)
    }

    private struct EmptyBody: Encodable {}

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty { components.queryItems = (components.queryItems ?? []) + queryItems }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func request<B: Encodable, T: Decodable>(method: String, path: String,
                                                     queryItems: [URLQueryItem] = [],
                                                     body: B?) async throws -> T {
        let url = try makeURL(path: path, queryItems: queryItems)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await send(req)
        try ensureSuccess(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(String(describing: error))
        }
    }

    private func requestVoid(method: String, path: String) async throws {
        let url = try makeURL(path: path, queryItems: [])
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token = tokenStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await send(req)
        try ensureSuccess(response: response, data: data)
    }

    private func requestEmpty<T: Decodable>(method: String, path: String, as: T.Type) async throws -> T {
        let url = try makeURL(path: path, queryItems: [])
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokenStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(EmptyBody())
        let (data, response) = try await send(req)
        try ensureSuccess(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func ensureSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(0, "No HTTP response")
        }
        if (200..<300).contains(http.statusCode) { return }
        let message = (try? decoder.decode(APIErrorBody.self, from: data))?.detail
            ?? String(data: data, encoding: .utf8) ?? ""
        throw APIError.badStatus(http.statusCode, message)
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        return d
    }
}
