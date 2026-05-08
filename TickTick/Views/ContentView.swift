import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var sidebarSelection: SidebarSelection = .smartList(.today)
    @State private var selectedTask: TaskItem?
    @State private var selectedCalendarDate: Date? = Date()
    @State private var selectedCalendarTask: TaskItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]
    @AppStorage("lastMissedRecurrenceCheck") private var lastCheckDateStr = ""

    private var isCalendarMode: Bool {
        sidebarSelection == .smartList(.calendar)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $sidebarSelection, selectedTask: $selectedTask)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            if isCalendarMode {
                CalendarView(selectedDate: $selectedCalendarDate, selectedTask: $selectedCalendarTask)
                    .navigationSplitViewColumnWidth(min: 500, ideal: 620)
            } else {
                TaskListView(selection: sidebarSelection, selectedTask: $selectedTask)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 400)
            }
        } detail: {
            if isCalendarMode {
                if let task = selectedCalendarTask {
                    TaskDetailView(task: task)
                        .navigationSplitViewColumnWidth(min: 260, ideal: 320)
                } else {
                    CalendarDayDetailView(date: selectedCalendarDate)
                        .navigationSplitViewColumnWidth(min: 260, ideal: 320)
                }
            } else if let task = selectedTask {
                TaskDetailView(task: task)
            } else {
                ContentUnavailableView("選擇一個任務", systemImage: "checkmark.circle")
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onChange(of: sidebarSelection) {
            selectedTask = nil
            selectedCalendarTask = nil
        }
        .onAppear { generateMissedRecurrencesIfNeeded() }
        .onChange(of: allTasks) { _, _ in generateMissedRecurrencesIfNeeded() }
    }

    private func generateMissedRecurrencesIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard lastCheckDateStr != today, !allTasks.isEmpty else { return }
        lastCheckDateStr = today
        generateMissedRecurrences()
    }

    private func generateMissedRecurrences() {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        var existingKeys = Set<String>()
        for task in allTasks {
            guard task.recurrence != nil, let d = task.dueDate else { continue }
            let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
            let dayTS = Int(calendar.startOfDay(for: d).timeIntervalSince1970)
            existingKeys.insert("\(task.title)|\(listKey)|\(dayTS)")
        }

        for task in allTasks {
            guard !task.isCompleted,
                  let rule = task.recurrence,
                  let dueDate = task.dueDate else { continue }

            var current = dueDate
            while let next = TaskItem.nextDate(from: current, rule: rule), next < endOfToday {
                let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
                let dayTS = Int(calendar.startOfDay(for: next).timeIntervalSince1970)
                let key = "\(task.title)|\(listKey)|\(dayTS)"

                if !existingKeys.contains(key) {
                    let newTask = TaskItem(title: task.title, list: task.list)
                    newTask.notes = task.notes
                    newTask.priorityRaw = task.priorityRaw
                    newTask.dueDate = next
                    newTask.hasDueTime = task.hasDueTime
                    newTask.order = task.order
                    let newRule = RecurrenceRule(frequency: rule.frequency, weekdays: rule.weekdays)
                    context.insert(newRule)
                    newTask.recurrence = newRule
                    context.insert(newTask)
                    existingKeys.insert(key)
                }
                current = next
            }
        }
    }
}
