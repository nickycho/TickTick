import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Title
                TextField("任務標題", text: $task.title, axis: .vertical)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, 8)

                // Notes
                TextField("備註...", text: $task.notes, axis: .vertical)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, 20)

                Divider().padding(.bottom, 16)

                // Due Date Row
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    if task.dueDate != nil {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { task.dueDate ?? Date() },
                                set: { task.dueDate = $0 }
                            ),
                            displayedComponents: task.hasDueTime ? [.date, .hourAndMinute] : .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()

                        Toggle(isOn: $task.hasDueTime) {
                            Image(systemName: "clock")
                                .font(.caption)
                        }
                        .toggleStyle(.button)
                        .controlSize(.mini)
                        .help("包含時間")

                        Button(action: {
                            task.dueDate = nil
                            task.hasDueTime = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("新增截止日期") {
                            task.dueDate = Calendar.current.startOfDay(for: Date())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.bottom, 12)

                // Priority Row
                HStack(spacing: 12) {
                    Image(systemName: "flag")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    Text("優先級")
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(Priority.allCases.filter { $0 != .none }, id: \.self) { p in
                            Button(action: {
                                task.priority = task.priority == p ? .none : p
                            }) {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(task.priority == p ? p.color : Color.secondary.opacity(0.25))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.bottom, 12)

                // Recurrence Row
                RecurrencePicker(task: task)
                    .padding(.bottom, 16)

                Divider().padding(.bottom, 16)

                // Subtasks
                SubtaskSection(task: task)

                Spacer()
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
