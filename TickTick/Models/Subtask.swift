import Foundation
import SwiftData

@Model
final class Subtask {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var order: Int
    var parent: TaskItem?

    init(title: String, parent: TaskItem? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.order = 0
        self.parent = parent
    }
}
