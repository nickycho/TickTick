import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var sidebarSelection: SidebarSelection = .smartList(.today)
    @State private var selectedTask: TaskItem?
    @State private var selectedCalendarDate: Date? = Date()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var isCalendarMode: Bool {
        sidebarSelection == .smartList(.calendar)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $sidebarSelection, selectedTask: $selectedTask)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            if isCalendarMode {
                CalendarView(selectedDate: $selectedCalendarDate)
                    .navigationSplitViewColumnWidth(min: 500, ideal: 620)
            } else {
                TaskListView(selection: sidebarSelection, selectedTask: $selectedTask)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 400)
            }
        } detail: {
            if isCalendarMode {
                CalendarDayDetailView(date: selectedCalendarDate)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 320)
            } else if let task = selectedTask {
                TaskDetailView(task: task)
            } else {
                ContentUnavailableView("選擇一個任務", systemImage: "checkmark.circle")
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onChange(of: sidebarSelection) {
            selectedTask = nil
        }
    }
}
