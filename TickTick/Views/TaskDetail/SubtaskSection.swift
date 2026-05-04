import SwiftUI
import SwiftData

struct SubtaskSection: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @State private var isAddingSubtask = false
    @State private var newSubtaskTitle = ""
    @FocusState private var addFieldFocused: Bool

    private var sortedSubtasks: [Subtask] {
        task.subtasks.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("子任務")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { isAddingSubtask = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            ForEach(sortedSubtasks) { subtask in
                SubtaskRow(subtask: subtask) {
                    deleteSubtask(subtask)
                }
            }

            if isAddingSubtask {
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))

                    TextField("新增子任務...", text: $newSubtaskTitle)
                        .textFieldStyle(.plain)
                        .focused($addFieldFocused)
                        .onSubmit { commitSubtask() }
                        .onExitCommand {
                            isAddingSubtask = false
                            newSubtaskTitle = ""
                        }
                }
            }
        }
        .onChange(of: isAddingSubtask) { _, newValue in
            if newValue { addFieldFocused = true }
        }
    }

    private func commitSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let subtask = Subtask(title: title, parent: task)
        subtask.order = task.subtasks.count
        context.insert(subtask)
        newSubtaskTitle = ""
        addFieldFocused = true
    }

    private func deleteSubtask(_ subtask: Subtask) {
        task.subtasks.removeAll { $0.persistentModelID == subtask.persistentModelID }
        context.delete(subtask)
    }
}

struct SubtaskRow: View {
    @Bindable var subtask: Subtask
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { subtask.isCompleted.toggle() }) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(subtask.isCompleted ? Color.green : Color.secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            TextField("", text: $subtask.title)
                .textFieldStyle(.plain)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? Color.secondary : Color.primary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 1)
    }
}
