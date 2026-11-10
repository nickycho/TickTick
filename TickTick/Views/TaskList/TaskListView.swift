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
    @State private var pendingUncompleteTask: TaskItem?
    @State private var showUncompleteDialog = false

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

    private var navigationTitle: Text {
        switch selection {
        case .smartList(let type):
            return Text(type.title)
        case .taskList(let id):
            return Text(allLists.first { $0.persistentModelID == id }?.name ?? "List")
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
                    TaskRow(task: task, onComplete: { handleToggleCompletion(task) })
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTask = task }
                        .listRowBackground(
                            isSelected
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .contextMenu {
                            Button("Delete", role: .destructive) { deleteTask(task) }
                        }
                }
                .onMove(perform: canReorder ? moveTask : nil)

                if !completedTasks.isEmpty {
                    Section {
                        if showCompleted {
                            ForEach(completedTasks) { task in
                                let isSelected = selectedTask?.persistentModelID == task.persistentModelID
                                TaskRow(task: task, onComplete: { handleToggleCompletion(task) })
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTask = task }
                                    .listRowBackground(
                                        isSelected
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.clear
                                    )
                                    .contextMenu {
                                        Button("Delete", role: .destructive) { deleteTask(task) }
                                    }
                            }
                        }
                    } header: {
                        Button(action: { showCompleted.toggle() }) {
                            HStack {
                                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .frame(width: 12)
                                Text("Completed")
                                    .font(.subheadline)
                                Text("(\(completedTasks.count))")
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
                .help("Add a task (⌘N)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in
            isAddingTask = true
        }
        .confirmationDialog(
            "The next occurrence has been changed",
            isPresented: $showUncompleteDialog,
            presenting: pendingUncompleteTask
        ) { task in
            Button("Keep the next occurrence") {
                uncompleteKeepingSpawn(task)
                pendingUncompleteTask = nil
            }
            Button("Delete the next occurrence", role: .destructive) {
                completeTask(task)
                pendingUncompleteTask = nil
            }
            Button("Cancel", role: .cancel) {
                pendingUncompleteTask = nil
            }
        } message: { _ in
            Text("The next recurring task has been edited (title, notes, or subtasks). What should happen when you mark the original task as incomplete?")
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

    private func handleToggleCompletion(_ task: TaskItem) {
        // 只攔截「取消完成原任務、且 spawned 已被使用者修改」這個情境
        guard task.isCompleted,
              task.recurrence != nil,
              let nextDate = task.nextDueDate(),
              let spawned = spawnedNextTask(for: task, nextDate: nextDate),
              spawnedHasUserModifications(original: task, spawned: spawned) else {
            completeTask(task)
            return
        }
        pendingUncompleteTask = task
        showUncompleteDialog = true
    }

    private func spawnedHasUserModifications(original: TaskItem, spawned: TaskItem) -> Bool {
        if spawned.title != original.title { return true }
        if spawned.notes != original.notes { return true }
        if spawned.priorityRaw != original.priorityRaw { return true }
        if spawned.subtasks.count != original.subtasks.count { return true }
        if spawned.subtasks.contains(where: { $0.isCompleted }) { return true }
        return false
    }

    private func uncompleteKeepingSpawn(_ task: TaskItem) {
        task.isCompleted = false
        task.completedAt = nil
        // 不刪除 spawned，使用者保留變更；可能造成原任務與 spawned 同時為 active，需自行整理
    }

    private func completeTask(_ task: TaskItem) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
            task.spawnNextIfNeeded(among: allTasks, in: context)
        } else {
            task.completedAt = nil
            if let nextDate = task.nextDueDate(),
               let spawned = spawnedNextTask(for: task, nextDate: nextDate) {
                context.delete(spawned)
            }
        }
    }

    /// 找出同一 series 在指定日期的「未完成」spawned task，用於取消完成時刪除。
    private func spawnedNextTask(for task: TaskItem, nextDate: Date) -> TaskItem? {
        guard let series = task.seriesID else { return nil }
        let cal = Calendar.current
        return allTasks.first { t in
            t.id != task.id &&
            !t.isCompleted &&
            t.seriesID == series &&
            t.recurrence != nil &&
            (t.dueDate.map { cal.isDate($0, inSameDayAs: nextDate) } ?? false)
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
