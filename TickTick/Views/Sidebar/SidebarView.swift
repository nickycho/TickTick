import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarSelection
    @Binding var selectedTask: TaskItem?
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @State private var isAddingList = false
    @State private var newListName = ""
    @State private var editingList: TaskList?

    var body: some View {
        List(selection: $selection) {
            Section("Smart Lists") {
                ForEach(SmartListType.allCases) { type in
                    Label(type.title, systemImage: type.systemImage)
                        .foregroundStyle(type.color)
                        .tag(SidebarSelection.smartList(type))
                }
            }

            Section("My Lists") {
                ForEach(lists) { list in
                    HStack {
                        Circle()
                            .fill(Color(hex: list.colorHex))
                            .frame(width: 10, height: 10)
                        Text(list.name)
                    }
                    .tag(SidebarSelection.taskList(list.persistentModelID))
                    .contextMenu {
                        Button("Rename / Change Color") {
                            editingList = list
                        }
                        Divider()
                        Button("Delete List", role: .destructive) {
                            deleteList(list)
                        }
                    }
                }
                .onMove(perform: moveLists)

                if isAddingList {
                    HStack {
                        Circle()
                            .fill(Color(hex: "#4A90E2"))
                            .frame(width: 10, height: 10)
                        TextField("List Name", text: $newListName)
                            .textFieldStyle(.plain)
                            .onSubmit { commitNewList() }
                            .onExitCommand {
                                isAddingList = false
                                newListName = ""
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isAddingList = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationTitle("TickTick")
        .sheet(item: $editingList) { list in
            ListEditSheet(list: list)
        }
    }

    private func commitNewList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isAddingList = false
            newListName = ""
            return
        }
        let newList = TaskList(name: name, order: lists.count)
        context.insert(newList)
        isAddingList = false
        newListName = ""
        // Delay selection until next run loop so persistentModelID is valid
        DispatchQueue.main.async {
            selection = .taskList(newList.persistentModelID)
        }
    }

    private func deleteList(_ list: TaskList) {
        if case .taskList(let id) = selection, id == list.persistentModelID {
            selection = .smartList(.all)
        }
        context.delete(list)
    }

    private func moveLists(from source: IndexSet, to destination: Int) {
        var reordered = lists
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in reordered.enumerated() {
            list.order = index
        }
    }
}
