import SwiftUI
import SwiftData

@main
struct TickTickApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TaskItem.self, TaskList.self, Subtask.self, RecurrenceRule.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    generateMissedRecurrencesIfNeeded()
                }
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新增任務") {
                    NotificationCenter.default.post(name: .newTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func generateMissedRecurrencesIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let udKey = "lastMissedRecurrenceCheck"
        guard UserDefaults.standard.string(forKey: udKey) != today else { return }

        let context = container.mainContext
        guard let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) else { return }

        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        var existingKeys = Set<String>()
        for task in tasks {
            guard task.recurrence != nil, let d = task.dueDate else { continue }
            let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
            let dayTS = Int(calendar.startOfDay(for: d).timeIntervalSince1970)
            existingKeys.insert("\(task.title)|\(listKey)|\(dayTS)")
        }

        for task in tasks {
            guard !task.isCompleted,
                  let rule = task.recurrence,
                  let dueDate = task.dueDate else { continue }

            var current = dueDate
            while let next = TaskItem.nextDate(from: current, rule: rule), next < endOfToday {
                let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
                let dayTS = Int(calendar.startOfDay(for: next).timeIntervalSince1970)
                let entryKey = "\(task.title)|\(listKey)|\(dayTS)"

                if !existingKeys.contains(entryKey) {
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
                    existingKeys.insert(entryKey)
                }
                current = next
            }
        }

        try? context.save()
        UserDefaults.standard.set(today, forKey: udKey)
    }
}

extension Notification.Name {
    static let newTask = Notification.Name("com.nickycho.ticktick.newTask")
}
