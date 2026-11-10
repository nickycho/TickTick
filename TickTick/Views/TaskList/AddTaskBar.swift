import SwiftUI

struct AddTaskBar: View {
    @Binding var isActive: Bool
    @Binding var text: String
    let onSubmit: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if isActive {
                HStack(spacing: 10) {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18))

                    TextField("Add a task…", text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit(onSubmit)
                        .onExitCommand {
                            text = ""
                            isActive = false
                        }

                    if !text.isEmpty {
                        Button(action: onSubmit) {
                            Image(systemName: "return")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.background)
            } else {
                Button(action: { isActive = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Add Task")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(.background)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue { isFocused = true }
        }
    }
}
