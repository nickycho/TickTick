import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var completedAt: Date?
    var dueDate: Date?
    var hasDueTime: Bool
    var priorityRaw: Int
    var order: Int
    var createdAt: Date

    var list: TaskList?

    @Relationship(deleteRule: .cascade, inverse: \Subtask.parent)
    var subtasks: [Subtask] = []

    @Relationship(deleteRule: .cascade, inverse: \RecurrenceRule.task)
    var recurrence: RecurrenceRule?

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let date = dueDate, !isCompleted else { return false }
        let calendar = Calendar.current
        if hasDueTime {
            return date < Date()
        } else {
            return calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
        }
    }

    init(title: String, list: TaskList? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = ""
        self.isCompleted = false
        self.dueDate = nil
        self.hasDueTime = false
        self.priorityRaw = Priority.none.rawValue
        self.order = 0
        self.createdAt = Date()
        self.list = list
    }

    static func nextDate(from date: Date, rule: RecurrenceRule) -> Date? {
        let calendar = Calendar.current
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .workdays:
            var next = calendar.date(byAdding: .day, value: 1, to: date)!
            while calendar.isDateInWeekend(next) {
                next = calendar.date(byAdding: .day, value: 1, to: next)!
            }
            return next
        case .weekly:
            if rule.weekdays.isEmpty {
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
            }
            var next = calendar.date(byAdding: .day, value: 1, to: date)!
            for _ in 0..<7 {
                let weekday = calendar.component(.weekday, from: next) - 1
                if rule.weekdays.contains(weekday) { return next }
                next = calendar.date(byAdding: .day, value: 1, to: next)!
            }
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        }
    }

    func nextDueDate() -> Date? {
        guard let rule = recurrence, let date = dueDate else { return nil }
        return TaskItem.nextDate(from: date, rule: rule)
    }
}
