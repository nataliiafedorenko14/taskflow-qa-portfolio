import SwiftUI

struct ProjectTasksView: View {
    let project: Project
    @EnvironmentObject var state: AppState

    @State private var tasks: [TaskItem] = []
    @State private var error: String?
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var showCreate = false

    @State var statusFilter: TaskStatus?
    @State var priorityFilter: Priority?
    @State var tagFilter: String = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreate = true
                } label: { Image(systemName: "plus") }
                .accessibilityIdentifier("tasks.createButton")
            }
        }
        .sheet(isPresented: $showFilters, onDismiss: { load() }) {
            TaskFilterView(status: $statusFilter, priority: $priorityFilter, tag: $tagFilter)
        }
        .sheet(isPresented: $showCreate) {
            TaskEditView(project: project, task: nil) { load() }
        }
        .task { load() }
        .refreshable { load() }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search tasks", text: $searchText)
                .submitLabel(.search)
                .onSubmit { load() }
                .accessibilityIdentifier("tasks.searchField")
            Button {
                searchText = ""; statusFilter = nil; priorityFilter = nil; tagFilter = ""; load()
            } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            Button("Filter") { showFilters = true }
                .accessibilityIdentifier("tasks.filterButton")
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder private var content: some View {
        if isLoading && tasks.isEmpty {
            LoadingView()
        } else if let error {
            ErrorRetryView(message: error) { load() }
        } else if tasks.isEmpty {
            EmptyStateView(title: "No tasks match").accessibilityIdentifier("tasks.empty")
        } else {
            List {
                ForEach(tasks) { task in
                    NavigationLink {
                        TaskDetailView(taskId: task.id, onChange: load)
                    } label: { TaskRow(task: task) }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("tasks.list")
        }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let page = try await state.api.tasks(page: 1, pageSize: 100,
                                                      status: statusFilter, priority: priorityFilter,
                                                      projectId: project.id,
                                                      tag: tagFilter.isEmpty ? nil : tagFilter,
                                                      query: searchText.isEmpty ? nil : searchText)
                await MainActor.run { self.tasks = page.items; isLoading = false }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load"
                    isLoading = false
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.title).font(.body).lineLimit(2)
                Spacer()
                StatusBadge(status: task.status)
            }
            HStack(spacing: 8) {
                if let assignee = task.assignee {
                    Label(assignee.fullName, systemImage: "person").font(.caption).foregroundStyle(.secondary)
                }
                PriorityLabel(priority: task.priority)
            }
            if !task.tags.isEmpty { TagPills(tags: task.tags) }
        }
    }
}

struct TaskFilterView: View {
    @Binding var status: TaskStatus?
    @Binding var priority: Priority?
    @Binding var tag: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Button { status = nil } label: { row("Any", selected: status == nil) }
                        .accessibilityIdentifier("filter.status.any")
                    ForEach(TaskStatus.allCases) { s in
                        Button { status = s } label: { row(s.label, selected: status == s) }
                            .accessibilityIdentifier("filter.status.\(s.rawValue)")
                    }
                }
                Section("Priority") {
                    Button { priority = nil } label: { row("Any", selected: priority == nil) }
                        .accessibilityIdentifier("filter.priority.any")
                    ForEach(Priority.allCases) { p in
                        Button { priority = p } label: { row(p.label, selected: priority == p) }
                            .accessibilityIdentifier("filter.priority.\(p.rawValue)")
                    }
                }
                Section("Tag") {
                    TextField("Tag name (e.g. ios)", text: $tag).accessibilityIdentifier("filters.tagField")
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("filter.doneButton")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { status = nil; priority = nil; tag = "" }
                        .accessibilityIdentifier("filters.clearButton")
                }
            }
        }
    }

    private func row(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.primary)
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
        }
    }
}