import SwiftUI
import SwiftData

private enum CalendarViewMode: String {
    case month, week
}

struct CalendarView: View {
    @Binding var selectedDate: Date?
    @Binding var selectedTask: TaskItem?
    @Query(sort: \TaskItem.order) private var allTasks: [TaskItem]
    @State private var displayDate: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()
    @State private var viewMode: CalendarViewMode = .month

    private let weekdayHeaders = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            HStack {
                Button(action: { shift(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(headerTitle)
                    .font(.title3.bold())

                Spacer()

                Button(action: { shift(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 0) {
                    ForEach([CalendarViewMode.month, .week], id: \.rawValue) { mode in
                        Button(mode == .month ? "月" : "週") { viewMode = mode }
                            .buttonStyle(.plain)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                viewMode == mode
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                viewMode == mode ? Color.accentColor : Color.secondary
                            )
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .padding(.leading, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if viewMode == .month {
                monthContent
            } else {
                weekContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("行事曆")
        .onChange(of: viewMode) { _, _ in
            displayDate = selectedDate ?? Date()
        }
    }

    // MARK: - Month View

    private var monthContent: some View {
        VStack(spacing: 0) {
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

            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(calendarDays, id: \.self) { date in
                        CalendarDayCell(
                            date: date,
                            displayMonth: displayDate,
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
    }

    // MARK: - Week View

    private var weekContent: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 4) {
                ForEach(weekDays, id: \.self) { date in
                    CalendarWeekDayColumn(
                        date: date,
                        tasks: tasks(for: date),
                        isSelected: selectedDate.map {
                            Calendar.current.isDate($0, inSameDayAs: date)
                        } ?? false,
                        selectedTask: selectedTask,
                        onDayTap: {
                            selectedDate = date
                            selectedTask = nil
                        },
                        onTaskTap: { task in
                            selectedDate = date
                            selectedTask = task
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Helpers

    private var calendarDays: [Date] {
        let cal = Calendar.current
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayDate))!
        let weekday = cal.component(.weekday, from: firstOfMonth)
        let offset = weekday - 1
        let startDate = cal.date(byAdding: .day, value: -offset, to: firstOfMonth)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: startDate) }
    }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: displayDate)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: displayDate)!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func tasks(for date: Date) -> [TaskItem] {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: date)
        }
    }

    private func shift(by value: Int) {
        let unit: Calendar.Component = viewMode == .month ? .month : .weekOfYear
        if let next = Calendar.current.date(byAdding: unit, value: value, to: displayDate) {
            displayDate = next
        }
    }

    private var headerTitle: String {
        viewMode == .month ? monthTitle(displayDate) : weekRangeTitle
    }

    private var weekRangeTitle: String {
        let days = weekDays
        guard let first = days.first, let last = days.last else { return "" }
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        if cal.component(.month, from: first) == cal.component(.month, from: last) {
            f.dateFormat = "yyyy年M月d"
            let firstStr = f.string(from: first)
            f.dateFormat = "d日"
            return "\(firstStr)-\(f.string(from: last))"
        } else {
            f.dateFormat = "M月d日"
            return "\(f.string(from: first)) - \(f.string(from: last))"
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }
}

// MARK: - Week Day Column

struct CalendarWeekDayColumn: View {
    let date: Date
    let tasks: [TaskItem]
    let isSelected: Bool
    let selectedTask: TaskItem?
    let onDayTap: () -> Void
    let onTaskTap: (TaskItem) -> Void
    @AppStorage("taskFontSize") private var taskFontSize: Double = 14

    private var chipFontSize: CGFloat { CGFloat(taskFontSize) - 4 }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var day: Int { Calendar.current.component(.day, from: date) }
    private var weekdayLabel: String {
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        return labels[Calendar.current.component(.weekday, from: date) - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            VStack(spacing: 2) {
                Text(weekdayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(day)")
                    .font(.system(size: 15, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 28, height: 28)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Divider()
                .padding(.bottom, 6)

            // Tasks
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tasks) { task in
                    let isTaskSelected = selectedTask?.persistentModelID == task.persistentModelID
                    let chipColor = task.priority == .none ? Color.accentColor : task.priority.color
                    Button(action: { onTaskTap(task) }) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(chipColor)
                                .frame(width: 6, height: 6)
                            Text(task.title)
                                .font(.system(size: chipFontSize))
                                .lineLimit(2)
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            chipColor.opacity(isTaskSelected ? 0.25 : 0.15),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    chipColor.opacity(isTaskSelected ? 0.7 : 0.3),
                                    lineWidth: isTaskSelected ? 1.5 : 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.08)
                    : Color(nsColor: .windowBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor).opacity(0.6),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onDayTap)
    }
}

// MARK: - Month Day Cell

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
            HStack {
                Text("\(day)")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white : (isCurrentMonth ? Color.primary : Color.secondary.opacity(0.5)))
                    .frame(width: 22, height: 22)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())
                Spacer()
            }

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
