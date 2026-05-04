import Foundation
import SwiftData

@Model
final class RecurrenceRule {
    var id: UUID
    var frequencyRaw: String
    var weekdays: [Int]
    var task: TaskItem?

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    init(frequency: RecurrenceFrequency, weekdays: [Int] = []) {
        self.id = UUID()
        self.frequencyRaw = frequency.rawValue
        self.weekdays = weekdays
    }
}
