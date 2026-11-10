import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.system.rawValue
    @AppStorage("taskFontSize") private var fontSize: Double = 14
    @AppStorage(MissedRecurrenceMode.storageKey) private var missedModeRaw: String = MissedRecurrenceMode.default.rawValue

    var body: some View {
        Form {
            Section("Language") {
                Picker("App Language", selection: $appLanguageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Display") {
                Picker("Font Size", selection: $fontSize) {
                    Text("Small (12 pt)").tag(12.0)
                    Text("Default (14 pt)").tag(14.0)
                    Text("Large (16 pt)").tag(16.0)
                    Text("Extra Large (18 pt)").tag(18.0)
                }
                .pickerStyle(.inline)

                HStack {
                    Text("Preview")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                    Text("Remember to bring your laptop to today's meeting.")
                        .font(.system(size: fontSize))
                }
                .padding(.top, 4)
            }

            Section {
                Picker("Missed Recurrences", selection: $missedModeRaw) {
                    ForEach(MissedRecurrenceMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Recurring Tasks")
            } footer: {
                Text("When the app opens after days have passed, choose how to handle missed recurring tasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding(.vertical)
    }
}
