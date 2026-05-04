import SwiftUI
import SwiftData

struct TaskListView: View {
    let selection: SidebarSelection
    @Binding var selectedTask: TaskItem?
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.order) private var allTasks: [TaskItem]
    @Query(sort: \TaskList.order) private var allLists: [TaskList]
    @State private var showCompleted = false
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""

    private var activeTasks: [TaskItem] { filtered(completed: false) }
    private var completedTasks: [TaskItem] { filtered(completed: true) }

    private func filtered(completed: Bool) -> [TaskItem] {
        switch selection {
        case .smartList(let type):
            return smartFiltered(type: type, completed: completed)
        case .taskList(let id):
            return allTasks.filter {
                $0.list?.persistentModelID == id && $0.isCompleted == completed
            }
        }
    }

    private func smartFiltered(type: SmartListType, completed: Bool) -> [TaskItem] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
        let endOf7Days = calendar.date(byAdding: .day, value: 7, to: endOfToday)!

        var tasks: [TaskItem]
        switch type {
        case .today:
            tasks = allTasks.filter { t in
                t.isCompleted == completed && (t.dueDate.map { $0 < endOfToday } ?? false)
            }
        case .tomorrow:
            tasks = allTasks.filter { t in
                t.isCompleted == completed &&
                (t.dueDate.map { $0 >= endOfToday && $0 < endOfTomorrow } ?? false)
            }
        case .next7Days:
            tasks = allTasks.filter { t in
                t.isCompleted == completed && (t.dueDate.map { $0 < endOf7Days } ?? false)
            }
        case .all:
            tasks = allTasks.filter { $0.isCompleted == completed }
        case .calendar:
            tasks = []
        }

        if completed {
            tasks.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        } else {
            tasks.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        }
        return tasks
    }

    private var navigationTitle: String {
        switch selection {
        case .smartList(let type): return type.title
        case .taskList(let id):
            return allLists.first { $0.persistentModelID == id }?.name ?? "清單"
        }
    }

    private var canReorder: Bool {
        if case .taskList = selection { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(activeTasks) { task in
                    let isSelected = selectedTask?.persistentModelID == task.persistentModelID
                    TaskRow(task: task, onComplete: { completeTask(task) })
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTask = task }
                        .listRowBackground(
                            isSelected
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .contextMenu {
                            Button("刪除", role: .destructive) { deleteTask(task) }
                        }
                }
                .onMove(perform: canReorder ? moveTask : nil)

                if !completedTasks.isEmpty {
                    Section {
                        if showCompleted {
                            ForEach(completedTasks) { task in
                                let isSelected = selectedTask?.persistentModelID == task.persistentModelID
                                TaskRow(task: task, onComplete: { completeTask(task) })
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTask = task }
                                    .listRowBackground(
                                        isSelected
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.clear
                                    )
                                    .contextMenu {
                                        Button("刪除", role: .destructive) { deleteTask(task) }
                                    }
                            }
                        }
                    } header: {
                        Button(action: { showCompleted.toggle() }) {
                            HStack {
                                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .frame(width: 12)
                                Text("已完成（\(completedTasks.count)）")
                                    .font(.subheadline)
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)

            AddTaskBar(isActive: $isAddingTask, text: $newTaskTitle, onSubmit: addTask)
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                Button(action: { isAddingTask = true }) {
                    Image(systemName: "square.and.pencil")
                }
                .help("新增任務 (⌘N)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in
            isAddingTask = true
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            newTaskTitle = ""
            isAddingTask = false
            return
        }

        let task = TaskItem(title: title)

        if case .taskList(let id) = selection {
            task.list = allLists.first { $0.persistentModelID == id }
        }

        if case .smartList(let type) = selection, type == .today {
            task.dueDate = Calendar.current.startOfDay(for: Date())
        }

        task.order = activeTasks.count
        context.insert(task)
        newTaskTitle = ""
        isAddingTask = false

        DispatchQueue.main.async {
            selectedTask = task
        }
    }

    private func completeTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
            if task.recurrence != nil, let nextDate = task.nextDueDate() {
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
            }
        } else {
            task.completedAt = nil
        }
    }

    private func deleteTask(_ task: TaskItem) {
        if selectedTask?.persistentModelID == task.persistentModelID {
            selectedTask = nil
        }
        context.delete(task)
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        var reordered = activeTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.order = index
        }
    }
}
