import SwiftUI
import SwiftData

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "Follow System"
        case .english: return "English"
        case .traditionalChinese: return "Chinese (Traditional)"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return Locale(identifier: Self.systemLocaleIdentifier())
        case .english:
            return Locale(identifier: "en")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant")
        case .japanese:
            return Locale(identifier: "ja")
        case .korean:
            return Locale(identifier: "ko")
        }
    }

    static func locale(for rawValue: String) -> Locale {
        (AppLanguage(rawValue: rawValue) ?? .system).locale
    }

    private static func systemLocaleIdentifier() -> String {
        for preferredLanguage in Locale.preferredLanguages {
            let languageCode = preferredLanguage
                .split(separator: "-")
                .first
                .map(String.init)?
                .lowercased()

            switch languageCode {
            case "en": return "en"
            case "zh": return "zh-Hant"
            case "ja": return "ja"
            case "ko": return "ko"
            default: continue
            }
        }
        return "en"
    }
}

enum Priority: Int, Codable, CaseIterable, Comparable, Hashable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: LocalizedStringKey {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
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

    var label: LocalizedStringKey {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .workdays: return "Every weekday"
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

    var title: LocalizedStringKey {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .next7Days: return "Next 7 Days"
        case .all: return "All Tasks"
        case .calendar: return "Calendar"
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

    var label: LocalizedStringKey {
        switch self {
        case .allMissed: return "Generate every missed occurrence"
        case .todayOnly: return "Generate only the latest occurrence"
        }
    }
}
