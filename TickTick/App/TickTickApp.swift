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
    }
}

extension Notification.Name {
    static let newTask = Notification.Name("com.nickycho.ticktick.newTask")
}
