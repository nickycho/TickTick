import SwiftUI
import SwiftData

struct CalendarDayDetailView: View {
    let date: Date?
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.order) private var allTasks: [TaskItem]
    @State private var selectedTask: TaskItem?
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""

    private var dayTasks: [TaskItem] {
        guard let date else { return [] }
        let cal = Calendar.current
        return allTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: date)
            }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        Group {
            if let date {
                if let task = selectedTask {
                    detailPanel(for: task, date: date)
                } else {
                    dayListPanel(for: date)
                }
            } else {
                ContentUnavailableView("選擇日期", systemImage: "calendar")
            }
        }
        .onChange(of: date) { selectedTask = nil }
    }

    // MARK: - Sub-panels

    @ViewBuilder
    private func detailPanel(for task: TaskItem, date: Date) -> some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: { selectedTask = nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(dayTitle(date))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            TaskDetailView(task: task)
        }
    }

    @ViewBuilder
    private func dayListPanel(for date: Date) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayTitle(date))
                        .font(.title3.bold())
                    Text(fullDateString(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isAddingTask = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if dayTasks.isEmpty && !isAddingTask {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                    Text("這天沒有任務")
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(dayTasks) { task in
                        let isSelected = selectedTask?.persistentModelID == task.persistentModelID
                        TaskRow(task: task, onComplete: { toggleComplete(task) })
                            .contentShape(Rectangle())
                            .onTapGesture { selectedTask = task }
                            .listRowBackground(
                                isSelected ? Color.accentColor.opacity(0.12) : Color.clear
                            )
                            .contextMenu {
                                Button("刪除", role: .destructive) { context.delete(task) }
                            }
                    }
                }
                .listStyle(.plain)
            }

            AddTaskBar(isActive: $isAddingTask, text: $newTaskTitle, onSubmit: { addTask(for: date) })
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func addTask(for date: Date) {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            newTaskTitle = ""
            isAddingTask = false
            return
        }
        let task = TaskItem(title: title)
        task.dueDate = Calendar.current.startOfDay(for: date)
        task.order = dayTasks.count
        context.insert(task)
        newTaskTitle = ""
        isAddingTask = false
        DispatchQueue.main.async { selectedTask = task }
    }

    private func toggleComplete(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
            guard task.recurrence != nil, let nextDate = task.nextDueDate() else { return }
            let newTask = TaskItem(title: task.title, list: task.list)
            newTask.notes = task.notes
            newTask.priorityRaw = task.priorityRaw
            newTask.dueDate = nextDate
            newTask.hasDueTime = task.hasDueTime
            newTask.order = task.order
            if let rule = task.recurrence {
                let newRule = RecurrenceRule(frequency: rule.frequency, weekdays: rule.weekdays)
                context.insert(newRule)
                newTask.recurrence = newRule
            }
            context.insert(newTask)
            task.spawnedNextTaskID = newTask.id
        } else {
            task.completedAt = nil
            if let spawnedID = task.spawnedNextTaskID,
               let spawnedTask = allTasks.first(where: { $0.id == spawnedID }) {
                context.delete(spawnedTask)
            }
            task.spawnedNextTaskID = nil
        }
    }

    // MARK: - Formatting

    private func dayTitle(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInTomorrow(date) { return "明天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func fullDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: date)
    }
}
