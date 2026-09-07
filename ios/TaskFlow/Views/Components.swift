import SwiftUI

/// Full-screen loading indicator.
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("loading.view")
    }
}

/// Error state with an optional Retry button. Used across list screens.
struct ErrorRetryView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("error.retryButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty-state placeholder.
struct EmptyStateView: View {
    let title: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatusBadge: View {
    let status: TaskStatus
    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        switch status {
        case .todo: return .gray
        case .in_progress: return .blue
        case .done: return .green
        case .cancelled: return .red
        }
    }
}

struct PriorityLabel: View {
    let priority: Priority
    var body: some View {
        Text(priority.label)
            .font(.caption)
            .foregroundStyle(color)
    }
    private var color: Color {
        switch priority {
        case .low: return .secondary
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

struct TagPills: View {
    let tags: [String]
    var body: some View {
        FlowingHStack(items: tags) { tag in
            Text("#\(tag)")
                .font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
    }
}

/// A simple wrapping horizontal layout for tag chips.
struct FlowingHStack<Content: View>: View {
    let items: [String]
    @ViewBuilder let content: (String) -> Content
    var body: some View {
        FlexibleView(data: items, spacing: 6, alignment: .leading) { item in
            content(item)
        }
    }
}

// Adapted flexible-wrap layout (public-domain style).
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    @ViewBuilder let content: (Data.Element) -> Content

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(chunked(), id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { item in content(item) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked() -> [[Data.Element]] {
        // Simple fixed-count wrapping (2 per row) keeps layout deterministic
        // and avoids measuring geometry — enough for a handful of tags.
        var rows: [[Data.Element]] = []
        var current: [Data.Element] = []
        for item in data {
            current.append(item)
            if current.count >= 2 {
                rows.append(current); current = []
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}