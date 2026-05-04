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
        ("藍", "#4A90E2"),
        ("綠", "#5CB85C"),
        ("紅", "#D9534F"),
        ("橘", "#F0AD4E"),
        ("紫", "#9B59B6"),
        ("粉", "#E91E8C"),
        ("青", "#17A2B8"),
        ("灰", "#6C757D"),
    ]
}
