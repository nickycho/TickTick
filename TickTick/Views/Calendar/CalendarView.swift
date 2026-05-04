import SwiftUI
import SwiftData

struct CalendarView: View {
    @Binding var selectedDate: Date?
    @Query(sort: \TaskItem.order) private var allTasks: [TaskItem]
    @State private var displayMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()

    private let weekdayHeaders = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation
            HStack {
                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle(displayMonth))
                    .font(.title3.bold())

                Spacer()

                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Weekday header
            HStack(spacing: 1) {
                ForEach(weekdayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 8)

            Divider()

            // Calendar grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(calendarDays, id: \.self) { date in
                        CalendarDayCell(
                            date: date,
                            displayMonth: displayMonth,
                            tasks: tasks(for: date),
                            isSelected: selectedDate.map {
                                Calendar.current.isDate($0, inSameDayAs: date)
                            } ?? false
                        ) {
                            selectedDate = date
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("行事曆")
    }

    // MARK: - Helpers

    private var calendarDays: [Date] {
        let cal = Calendar.current
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
        let weekday = cal.component(.weekday, from: firstOfMonth)
        // Sunday-start: weekday 1=Sun → offset 0, weekday 2=Mon → offset 1, ..., 7=Sat → offset 6
        let offset = weekday - 1
        let startDate = cal.date(byAdding: .day, value: -offset, to: firstOfMonth)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: startDate) }
    }

    private func tasks(for date: Date) -> [TaskItem] {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: date)
        }
    }

    private func shiftMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: displayMonth) {
            displayMonth = next
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }
}

// MARK: - Day Cell

struct CalendarDayCell: View {
    let date: Date
    let displayMonth: Date
    let tasks: [TaskItem]
    let isSelected: Bool
    let onTap: () -> Void
    @AppStorage("taskFontSize") private var taskFontSize: Double = 14

    private var chipFontSize: CGFloat { CGFloat(taskFontSize) - 4 }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: displayMonth)
    }

    private var day: Int { Calendar.current.component(.day, from: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Day number
            HStack {
                Text("\(day)")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white : (isCurrentMonth ? Color.primary : Color.secondary.opacity(0.5)))
                    .frame(width: 22, height: 22)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())
                Spacer()
            }

            // Tasks (max 3)
            ForEach(tasks.prefix(3)) { task in
                HStack(spacing: 3) {
                    Circle()
                        .fill(task.priority == .none ? Color.accentColor.opacity(0.6) : task.priority.color)
                        .frame(width: 5, height: 5)
                    Text(task.title)
                        .font(.system(size: chipFontSize))
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    (task.priority == .none ? Color.accentColor : task.priority.color).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 3)
                )
            }

            // Overflow indicator
            if tasks.count > 3 {
                Text("+\(tasks.count - 3) 個")
                    .font(.system(size: chipFontSize))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
            }

            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(minHeight: 90)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.5),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
        )
        .opacity(isCurrentMonth ? 1 : 0.45)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
