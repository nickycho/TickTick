import SwiftUI
import SwiftData

struct RecurrencePicker: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context

    private let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "repeat")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if let rule = task.recurrence {
                Menu {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                        Button(freq.label) {
                            rule.frequency = freq
                            if freq != .weekly { rule.weekdays = [] }
                        }
                    }
                    Divider()
                    Button("移除重複", role: .destructive) {
                        context.delete(rule)
                        task.recurrence = nil
                    }
                } label: {
                    Text(rule.frequency.label)
                        .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if rule.frequency == .weekly {
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let isSelected = rule.weekdays.contains(day)
                            Button(weekdayNames[day]) {
                                if isSelected {
                                    rule.weekdays.removeAll { $0 == day }
                                } else {
                                    rule.weekdays.append(day)
                                    rule.weekdays.sort()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                    }
                }
            } else {
                Button("新增重複") {
                    let rule = RecurrenceRule(frequency: .daily)
                    context.insert(rule)
                    task.recurrence = rule
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
