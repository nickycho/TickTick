import SwiftUI

struct ListEditSheet: View {
    @Bindable var list: TaskList
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("編輯清單")
                .font(.headline)

            TextField("清單名稱", text: $list.name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 10) {
                Text("顏色")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(36)), count: 8),
                    spacing: 8
                ) {
                    ForEach(TaskList.presetColors, id: \.hex) { option in
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                    .opacity(list.colorHex == option.hex ? 1 : 0)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 2)
                            .onTapGesture { list.colorHex = option.hex }
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
