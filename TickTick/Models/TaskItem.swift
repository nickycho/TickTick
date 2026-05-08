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
    /// 同一條重複序列的所有 occurrence 共享相同 ID。legacy 資料為 nil，由 backfill 補。
    var seriesID: UUID?

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
        self.seriesID = UUID()
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

    /// 為下一次 occurrence 建立副本：複製屬性、繼承 seriesID、新建 RecurrenceRule、複製未完成的 subtasks。
    /// `order` 為 nil 時保留原任務 order（適用於單筆 spawn，原任務移到完成區後不衝突）；
    /// 批次 spawn 時應傳入遞增值，避免多筆同 order 排序未定義。
    /// 已插入 context，呼叫端不需再 insert。
    @discardableResult
    func cloneForRecurrence(dueDate newDueDate: Date, order newOrder: Int? = nil, in context: ModelContext) -> TaskItem {
        let newTask = TaskItem(title: title, list: list)
        newTask.notes = notes
        newTask.priorityRaw = priorityRaw
        newTask.dueDate = newDueDate
        newTask.hasDueTime = hasDueTime
        newTask.order = newOrder ?? order
        newTask.seriesID = seriesID ?? UUID()
        context.insert(newTask)

        if let rule = recurrence {
            let newRule = RecurrenceRule(frequency: rule.frequency, weekdays: rule.weekdays)
            context.insert(newRule)
            newTask.recurrence = newRule
        }

        for subtask in subtasks.sorted(by: { $0.order < $1.order }) {
            let newSubtask = Subtask(title: subtask.title, parent: newTask)
            newSubtask.order = subtask.order
            context.insert(newSubtask)
        }

        return newTask
    }
}
