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
                    backfillSeriesIDsIfNeeded()
                    generateMissedRecurrencesIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
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

    private func backfillSeriesIDsIfNeeded() {
        let context = container.mainContext
        guard let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) else { return }

        // 同 (title, listID, recurrence?) 視為同一條歷史 series，共用同一 UUID。
        // 非重複任務各自獨立 UUID。
        var groupIDs: [String: UUID] = [:]
        var changed = false
        for task in tasks where task.seriesID == nil {
            if task.recurrence != nil {
                let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
                let groupKey = "\(task.title)|\(listKey)"
                let id = groupIDs[groupKey] ?? UUID()
                groupIDs[groupKey] = id
                task.seriesID = id
            } else {
                task.seriesID = UUID()
            }
            changed = true
        }
        if changed { try? context.save() }
    }

    private func generateMissedRecurrencesIfNeeded() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let udKey = "lastMissedRecurrenceCheck"
        guard UserDefaults.standard.string(forKey: udKey) != today else { return }
        // 提前寫入：避免 didBecomeActive 與 NSCalendarDayChanged 短時間內接連觸發造成重複補生
        UserDefaults.standard.set(today, forKey: udKey)

        let context = container.mainContext
        guard let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) else { return }

        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        // 補生 dedupe key（同 series + 同日）
        var existingKeys = Set<String>()
        for task in tasks {
            guard task.recurrence != nil, let d = task.dueDate, let series = task.seriesID else { continue }
            let dayTS = Int(calendar.startOfDay(for: d).timeIntervalSince1970)
            existingKeys.insert("\(series.uuidString)|\(dayTS)")
        }

        // 每個清單（含 nil-list）目前最大 order，作為遞增 spawn 起點
        var maxOrderByList: [String: Int] = [:]
        for task in tasks {
            let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
            maxOrderByList[listKey] = max(maxOrderByList[listKey] ?? -1, task.order)
        }

        for task in tasks {
            guard !task.isCompleted,
                  let rule = task.recurrence,
                  let dueDate = task.dueDate,
                  let series = task.seriesID else { continue }

            var current = dueDate
            while let next = TaskItem.nextDate(from: current, rule: rule), next < endOfToday {
                let dayTS = Int(calendar.startOfDay(for: next).timeIntervalSince1970)
                let entryKey = "\(series.uuidString)|\(dayTS)"

                if !existingKeys.contains(entryKey) {
                    let listKey = task.list.map { String(describing: $0.persistentModelID) } ?? "nil"
                    let nextOrder = (maxOrderByList[listKey] ?? -1) + 1
                    maxOrderByList[listKey] = nextOrder
                    task.cloneForRecurrence(dueDate: next, order: nextOrder, in: context)
                    existingKeys.insert(entryKey)
                }
                current = next
            }
        }

        try? context.save()
    }
}

extension Notification.Name {
    static let newTask = Notification.Name("com.nickycho.ticktick.newTask")
}
