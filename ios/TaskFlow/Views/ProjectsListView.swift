import SwiftUI

struct ProjectsListView: View {
    @EnvironmentObject var state: AppState
    @State private var projects: [Project] = []
    @State private var error: String?
    @State private var isLoading = false
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Projects")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCreate = true
                        } label: { Image(systemName: "plus") }
                            .accessibilityIdentifier("projects.createButton")
                    }
                }
                .sheet(isPresented: $showCreate) { CreateProjectView { load() } }
                .task { load() }
                .refreshable { load() }
        }
    }

    @ViewBuilder private var content: some View {
        if isLoading && projects.isEmpty {
            LoadingView()
        } else if let error {
            ErrorRetryView(message: error) { load() }
        } else if projects.isEmpty {
            EmptyStateView(title: "No projects yet")
                .accessibilityIdentifier("projects.empty")
        } else {
            List {
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectTasksView(project: project)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name).font(.headline)
                            Text(project.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("projects.row.\(project.name)")
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("projects.list")
        }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await state.api.projects()
                await MainActor.run { self.projects = result; isLoading = false }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed to load"
                    isLoading = false
                }
            }
        }
    }
}

struct CreateProjectView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let onCreated: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name).accessibilityIdentifier("project.nameTextField")
                TextField("Description", text: $description).accessibilityIdentifier("project.descriptionTextField")
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("project.errorLabel") }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .accessibilityIdentifier("project.createButton")
                }
            }
        }
    }

    private func create() {
        isLoading = true
        Task {
            do {
                _ = try await state.api.createProject(name: name, description: description)
                await MainActor.run {
                    isLoading = false
                    onCreated(); dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Failed"; isLoading = false
                }
            }
        }
    }
}
