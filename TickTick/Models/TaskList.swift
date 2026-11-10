import Foundation
import SwiftData

@Model
final class TaskList {
    var id: UUID
    var name: String
    var colorHex: String
    var order: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem] = []

    init(name: String, colorHex: String = "#4A90E2", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.order = order
        self.createdAt = Date()
    }

    static let presetColors: [(name: String, hex: String)] = [
        ("Blue", "#4A90E2"),
        ("Green", "#5CB85C"),
        ("Red", "#D9534F"),
        ("Orange", "#F0AD4E"),
        ("Purple", "#9B59B6"),
        ("Pink", "#E91E8C"),
        ("Teal", "#17A2B8"),
        ("Gray", "#6C757D"),
    ]
}
