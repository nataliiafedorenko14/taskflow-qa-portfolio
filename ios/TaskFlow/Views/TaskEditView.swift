import SwiftUI

struct TaskEditView: View {
    let project: Project
    let task: TaskItem?
    let onSaved: () -> Void

    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var status: TaskStatus = .todo
    @State private var priority: Priority = .medium
    @State private var assigneeId: Int? = nil
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var tagsText = ""
    @State private var members: [ProjectMember] = []
    @State private var error: String?
    @State private var isSaving = false

    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("task.titleTextField")
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("task.descriptionTextField")
                }
                Section("Properties") {
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases) { s in Text(s.label).tag(s) }
                    }
                    .accessibilityIdentifier("task.statusPicker")
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in Text(p.label).tag(p) }
                    }
                    .accessibilityIdentifier("task.priorityPicker")
                    Picker("Assignee", selection: $assigneeId) {
                        Text("Unassigned").tag(Int?.none)
                        ForEach(members) { m in Text(m.fullName).tag(Optional(m.userId)) }
                    }
                    .accessibilityIdentifier("task.assigneePicker")
                    Toggle("Has due date", isOn: $hasDueDate)
                        .accessibilityIdentifier("task.dueDateToggle")
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                            .accessibilityIdentifier("task.dueDatePicker")
                    }
                }
                Section("Tags (comma separated)") {
                    TextField("ios, automation", text: $tagsText)
                        .accessibilityIdentifier("task.tagsField")
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("task.errorLabel") }
                }
                if task != nil {
                    Section {
                        Button("Delete task", role: .destructive) { delete() }
                            .accessibilityIdentifier("task.deleteButton")
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("task.saveButton")
                }
            }
        }
        .task { loadMembers() }
    }

    private func loadMembers() {
        if let task {
            title = task.title
            description = task.description
            status = task.status
            priority = task.priority
            assigneeId = task.assigneeId
            if let d = task.dueDate, let date = formatter.date(from: d) {
                hasDueDate = true; dueDate = date
            }
            tagsText = task.tags.joined(separator: ", ")
        }
        Task {
            do {
                let result = try await state.api.projectMembers(project.id)
                await MainActor.run { self.members = result }
            } catch { /* optional: ignore */ }
        }
    }

    private func parsedTags() -> [String] {
        tagsText.split(whereSeparator: { $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        error = nil
        isSaving = true
        let tags = parsedTags()
        let dueStr = hasDueDate ? formatter.string(from: dueDate) : nil
        Task {
            do {
                if let task {
                    let req = TaskUpdateRequest(
                        title: title, description: description, status: status,
                        priority: priority, assigneeId: assigneeId, dueDate: dueStr, tags: tags)
                    _ = try await state.api.updateTask(task.id, request: req)
                } else {
                    let req = TaskCreateRequest(
                        title: title, description: description, status: status,
                        priority: priority, assigneeId: assigneeId, dueDate: dueStr, tags: tags)
                    _ = try await state.api.createTask(projectId: project.id, request: req)
                }
                await MainActor.run { isSaving = false; onSaved(); dismiss() }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to save"
                    isSaving = false
                }
            }
        }
    }

    private func delete() {
        guard let task else { return }
        Task {
            do {
                try await state.api.deleteTask(task.id)
                await MainActor.run { onSaved(); dismiss() }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to delete"
                }
            }
        }
    }
}