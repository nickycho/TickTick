import SwiftUI
import SwiftData

enum Priority: Int, Codable, CaseIterable, Comparable, Hashable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .none: return "無"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case workdays = "workdays"

    var label: String {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每週"
        case .workdays: return "每個工作日"
        }
    }
}

enum SmartListType: String, CaseIterable, Hashable, Identifiable {
    case today
    case tomorrow
    case next7Days
    case all
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .tomorrow: return "明天"
        case .next7Days: return "近7天"
        case .all: return "全部"
        case .calendar: return "行事曆"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max.fill"
        case .tomorrow: return "moon.stars.fill"
        case .next7Days: return "calendar.badge.clock"
        case .all: return "tray.full.fill"
        case .calendar: return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .today: return .orange
        case .tomorrow: return .purple
        case .next7Days: return .blue
        case .all: return .gray
        case .calendar: return .green
        }
    }
}

enum SidebarSelection: Hashable {
    case smartList(SmartListType)
    case taskList(PersistentIdentifier)
}

enum MissedRecurrenceMode: String, CaseIterable, Identifiable {
    case allMissed
    case todayOnly

    static let storageKey = "missedRecurrenceMode"
    static let `default`: MissedRecurrenceMode = .allMissed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allMissed: return "逐日補生（每個錯過的日期一筆任務）"
        case .todayOnly: return "只補生最新一筆"
        }
    }
}
