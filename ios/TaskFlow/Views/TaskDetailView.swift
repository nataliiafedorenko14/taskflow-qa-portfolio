import SwiftUI

struct TaskDetailView: View {
    let taskId: Int
    var onChange: () -> Void = {}

    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var task: TaskItem?
    @State private var comments: [Comment] = []
    @State private var error: String?
    @State private var commentBody = ""
    @State private var isLoading = false
    @State private var showEdit = false

    var body: some View {
        content
            .navigationTitle("Task #\(taskId)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showEdit = true }
                        .accessibilityIdentifier("task.editButton")
                }
            }
            .sheet(isPresented: $showEdit) {
                if let task {
                    TaskEditView(project: Project(id: task.projectId, name: "", description: "",
                                                  ownerId: 0, createdAt: "", updatedAt: ""),
                                  task: task) { load() }
                }
            }
            .task { load() }
            .refreshable { load() }
    }

    @ViewBuilder private var content: some View {
        if isLoading && task == nil {
            LoadingView()
        } else if let error {
            ErrorRetryView(message: error) { load() }
        } else if let task {
            List {
                Section("Task") {
                    Text(task.title).font(.headline)
                    if !task.description.isEmpty { Text(task.description) }
                    HStack { Text("Status"); Spacer(); StatusBadge(status: task.status) }
                    HStack { Text("Priority"); Spacer(); PriorityLabel(priority: task.priority) }
                    if let a = task.assignee { HStack { Text("Assignee"); Spacer(); Text(a.fullName) } }
                    if let r = task.reporter { HStack { Text("Reporter"); Spacer(); Text(r.fullName) } }
                    if let d = task.dueDate { HStack { Text("Due"); Spacer(); Text(d) } }
                    if !task.tags.isEmpty { TagPills(tags: task.tags).padding(.vertical, 4) }
                }
                Section("Comments") {
                    ForEach(comments) { c in
                        VStack(alignment: .leading) {
                            Text(c.body)
                            Text(c.authorName ?? "—").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        TextField("Add a comment", text: $commentBody)
                            .accessibilityIdentifier("task.commentTextField")
                        Button {
                            addComment()
                        } label: { Image(systemName: "paperplane.fill") }
                            .accessibilityIdentifier("task.addCommentButton")
                            .disabled(commentBody.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("comments.list")
        } else {
            EmptyStateView(title: "Task not found")
        }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                async let t = state.api.task(taskId)
                async let c = state.api.comments(taskId: taskId)
                let (fetched, fetchedComments) = try await (t, c)
                await MainActor.run {
                    self.task = fetched; self.comments = fetchedComments; isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load"
                    isLoading = false
                }
            }
        }
    }

    private func addComment() {
        let body = commentBody
        Task {
            do {
                let comment = try await state.api.createComment(taskId: taskId, body: body)
                await MainActor.run {
                    self.comments.append(comment)
                    self.commentBody = ""
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to post comment"
                }
            }
        }
    }
}