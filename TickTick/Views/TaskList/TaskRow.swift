import SwiftUI

struct TaskRow: View {
    @Bindable var task: TaskItem
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)

                if let date = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formattedDate(date))
                            .font(.caption)
                    }
                    .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if !task.subtasks.isEmpty {
                    let completedCount = task.subtasks.filter(\.isCompleted).count
                    Text("\(completedCount)/\(task.subtasks.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if task.recurrence != nil {
                    Image(systemName: "repeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if task.priority != .none {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(task.priority.color)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return task.hasDueTime ? "今天 \(timeString(date))" : "今天"
        } else if calendar.isDateInTomorrow(date) {
            return task.hasDueTime ? "明天 \(timeString(date))" : "明天"
        } else if calendar.isDateInYesterday(date) {
            return task.hasDueTime ? "昨天 \(timeString(date))" : "昨天"
        } else {
            return task.hasDueTime ? dateTimeString(date) : dateString(date)
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func dateTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
