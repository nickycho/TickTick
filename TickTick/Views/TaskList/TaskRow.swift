import SwiftUI

struct TaskRow: View {
    @Bindable var task: TaskItem
    let onComplete: () -> Void
    @AppStorage("taskFontSize") private var fontSize: Double = 14
    @Environment(\.locale) private var locale

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
                    .font(.system(size: CGFloat(fontSize)))
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
        let relativeDate: String?

        if calendar.isDateInToday(date) {
            relativeDate = String(localized: "Today", locale: locale)
        } else if calendar.isDateInTomorrow(date) {
            relativeDate = String(localized: "Tomorrow", locale: locale)
        } else if calendar.isDateInYesterday(date) {
            relativeDate = String(localized: "Yesterday", locale: locale)
        } else {
            relativeDate = nil
        }

        if let relativeDate {
            return task.hasDueTime ? "\(relativeDate) \(timeString(date))" : relativeDate
        }
        return task.hasDueTime ? dateTimeString(date) : dateString(date)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
