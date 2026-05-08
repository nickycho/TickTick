import SwiftUI

struct SettingsView: View {
    @AppStorage("taskFontSize") private var fontSize: Double = 14
    @AppStorage(MissedRecurrenceMode.storageKey) private var missedModeRaw: String = MissedRecurrenceMode.default.rawValue

    var body: some View {
        Form {
            Section("顯示") {
                Picker("字型大小", selection: $fontSize) {
                    Text("小（12pt）").tag(12.0)
                    Text("預設（14pt）").tag(14.0)
                    Text("大（16pt）").tag(16.0)
                    Text("特大（18pt）").tag(18.0)
                }
                .pickerStyle(.inline)

                HStack {
                    Text("預覽")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                    Text("今天開會記得帶筆電")
                        .font(.system(size: fontSize))
                }
                .padding(.top, 4)
            }

            Section {
                Picker("錯過的日期", selection: $missedModeRaw) {
                    ForEach(MissedRecurrenceMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("重複任務")
            } footer: {
                Text("跨日或久未開啟 app 時，如何處理錯過的重複任務。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding(.vertical)
    }
}
