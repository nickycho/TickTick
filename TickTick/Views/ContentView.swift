import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var sidebarSelection: SidebarSelection = .smartList(.today)
    @State private var selectedTask: TaskItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $sidebarSelection, selectedTask: $selectedTask)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            TaskListView(selection: sidebarSelection, selectedTask: $selectedTask)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 400)
        } detail: {
            if let task = selectedTask {
                TaskDetailView(task: task)
            } else {
                ContentUnavailableView("選擇一個任務", systemImage: "checkmark.circle")
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: sidebarSelection) {
            selectedTask = nil
        }
    }
}
