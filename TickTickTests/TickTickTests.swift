import XCTest
import SwiftData
@testable import TickTick

// MARK: - nextDate 靜態方法測試

final class NextDateTests: XCTestCase {

    func testNextDate_daily() {
        let rule = RecurrenceRule(frequency: .daily)
        // 使用固定日期避免測試受系統時間影響
        let base = date(year: 2024, month: 1, day: 1) // Monday
        let result = TaskItem.nextDate(from: base, rule: rule)
        XCTAssertEqual(result, date(year: 2024, month: 1, day: 2))
    }

    func testNextDate_workdays_fromFriday_skipsWeekend() {
        let rule = RecurrenceRule(frequency: .workdays)
        let friday = date(year: 2023, month: 12, day: 29) // Dec 29, 2023 = Friday
        let result = TaskItem.nextDate(from: friday, rule: rule)!
        let weekday = Calendar.current.component(.weekday, from: result)
        XCTAssertEqual(weekday, 2, "週五後的工作日應是週一（weekday=2）")
    }

    func testNextDate_workdays_fromMonday_isNextDay() {
        let rule = RecurrenceRule(frequency: .workdays)
        let monday = date(year: 2024, month: 1, day: 1) // Monday
        let result = TaskItem.nextDate(from: monday, rule: rule)!
        XCTAssertEqual(result, date(year: 2024, month: 1, day: 2))
    }

    func testNextDate_weekly_noSpecificDays() {
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [])
        let base = date(year: 2024, month: 1, day: 1)
        let result = TaskItem.nextDate(from: base, rule: rule)
        XCTAssertEqual(result, date(year: 2024, month: 1, day: 8))
    }

    func testNextDate_weekly_specificDays_fromMonday() {
        // 週一 (2024-01-01)，規則為週三(3)與週五(5)，預期下一個是週三
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [3, 5]) // 0=Sun,1=Mon,...
        let monday = date(year: 2024, month: 1, day: 1)
        let result = TaskItem.nextDate(from: monday, rule: rule)!
        let weekday = Calendar.current.component(.weekday, from: result) - 1 // 轉為 0-indexed
        XCTAssertEqual(weekday, 3, "週一後第一個指定日應是週三（0-indexed=3）")
    }

    func testNextDate_weekly_specificDays_wrapsToNextWeek() {
        // 週五 (2023-12-29)，規則為週一(1)，下一個在下週一
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [1]) // Monday
        let friday = date(year: 2023, month: 12, day: 29)
        let result = TaskItem.nextDate(from: friday, rule: rule)!
        XCTAssertEqual(result, date(year: 2024, month: 1, day: 1), "週五後的週一應是下週一")
    }

    // MARK: - Helper

    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0; comps.minute = 0; comps.second = 0
        return Calendar.current.date(from: comps)!
    }
}

// MARK: - cloneForRecurrence 測試

@MainActor
final class CloneForRecurrenceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: TaskItem.self, TaskList.self, Subtask.self, RecurrenceRule.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    func testCloneForRecurrence_copiesBasicProperties() throws {
        let task = makeRecurringTask(title: "每日站會", frequency: .daily)
        task.notes = "10:00 開始"
        task.priorityRaw = Priority.high.rawValue
        task.hasDueTime = true

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let clone = task.cloneForRecurrence(dueDate: tomorrow, in: context)

        XCTAssertEqual(clone.title, "每日站會")
        XCTAssertEqual(clone.notes, "10:00 開始")
        XCTAssertEqual(clone.priorityRaw, Priority.high.rawValue)
        XCTAssertEqual(clone.hasDueTime, true)
        XCTAssertEqual(clone.dueDate, tomorrow)
        XCTAssertFalse(clone.isCompleted)
    }

    func testCloneForRecurrence_inheritsSeriesID() throws {
        let sid = UUID()
        let task = makeRecurringTask(title: "Weekly Review", frequency: .weekly)
        task.seriesID = sid

        let clone = task.cloneForRecurrence(dueDate: Date(), in: context)
        XCTAssertEqual(clone.seriesID, sid)
    }

    func testCloneForRecurrence_createsNewRecurrenceRuleInstance() throws {
        let task = makeRecurringTask(title: "週五總結", frequency: .weekly, weekdays: [5])
        let originalRuleID = task.recurrence!.id

        let clone = task.cloneForRecurrence(dueDate: Date(), in: context)
        XCTAssertNotNil(clone.recurrence)
        XCTAssertEqual(clone.recurrence?.frequency, .weekly)
        XCTAssertEqual(clone.recurrence?.weekdays, [5])
        XCTAssertNotEqual(clone.recurrence?.id, originalRuleID, "應建立全新 RecurrenceRule")
    }

    func testCloneForRecurrence_subtasksAllResetToUncompleted() throws {
        let task = makeRecurringTask(title: "週報", frequency: .weekly)
        let sub1 = Subtask(title: "寫摘要", parent: task)
        sub1.isCompleted = true // 原任務上次已勾選
        sub1.order = 0
        let sub2 = Subtask(title: "發信", parent: task)
        sub2.order = 1
        context.insert(sub1)
        context.insert(sub2)
        try context.save()

        let clone = task.cloneForRecurrence(dueDate: Date(), in: context)
        try context.save()

        XCTAssertEqual(clone.subtasks.count, 2, "子任務數量應與原任務相同")
        XCTAssertTrue(clone.subtasks.allSatisfy { !$0.isCompleted }, "複製的子任務應全部重置為未完成")
    }

    func testCloneForRecurrence_customOrderUsedWhenProvided() throws {
        let task = makeRecurringTask(title: "Test", frequency: .daily)
        task.order = 3

        let clone = task.cloneForRecurrence(dueDate: Date(), order: 99, in: context)
        XCTAssertEqual(clone.order, 99)
    }

    func testCloneForRecurrence_inheritsOrderWhenNotProvided() throws {
        let task = makeRecurringTask(title: "Test", frequency: .daily)
        task.order = 7

        let clone = task.cloneForRecurrence(dueDate: Date(), in: context)
        XCTAssertEqual(clone.order, 7)
    }

    // MARK: - Helper

    @discardableResult
    private func makeRecurringTask(title: String, frequency: RecurrenceFrequency, weekdays: [Int] = []) -> TaskItem {
        let task = TaskItem(title: title)
        task.dueDate = Date()
        let rule = RecurrenceRule(frequency: frequency, weekdays: weekdays)
        context.insert(task)
        context.insert(rule)
        task.recurrence = rule
        return task
    }
}

// MARK: - 重複補生防護測試（核心 Bug 情境）

@MainActor
final class DuplicatePreventionTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: TaskItem.self, TaskList.self, Subtask.self, RecurrenceRule.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - 核心 Bug 情境

    /// Bug 情境：Task A（昨天，過期未完成）+ Task B（今天，已完成）
    /// → 完成 Task A 不應再建立今天的 Task B'
    func testNoDuplicate_whenCompletingOverdueTask_andNextOccurrenceAlreadyCompleted() throws {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let today = cal.startOfDay(for: Date())
        let series = UUID()

        let taskA = makeTask(title: "每日站會", dueDate: yesterday, series: series)
        let taskB = makeTask(title: "每日站會", dueDate: today, series: series, completed: true)
        try context.save()

        let snapshot = try fetchAll()
        XCTAssertEqual(snapshot.count, 2)

        simulateComplete(taskA, allTasks: snapshot)
        try context.save()

        let after = try fetchAll()
        let todayTasksInSeries = after.filter { t in
            guard let d = t.dueDate else { return false }
            return cal.isDateInToday(d) && t.seriesID == series
        }
        XCTAssertEqual(after.count, 2, "Task B（已完成）已存在，不應再補生 Task B'")
        XCTAssertEqual(todayTasksInSeries.count, 1, "今天同 series 應只有一筆任務")
        _ = taskB // 避免 unused warning
    }

    /// 正常情境：Task A（昨天），今天無任何 spawned 任務 → 完成後應補生今天
    func testSpawnCreated_whenNoExistingNextOccurrence() throws {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let series = UUID()

        let taskA = makeTask(title: "每日站會", dueDate: yesterday, series: series)
        try context.save()

        let snapshot = try fetchAll()
        simulateComplete(taskA, allTasks: snapshot)
        try context.save()

        let todayUncompleted = try fetchAll().filter { t in
            guard let d = t.dueDate else { return false }
            return cal.isDateInToday(d) && t.seriesID == series && !t.isCompleted
        }
        XCTAssertEqual(todayUncompleted.count, 1, "今天沒有任務時，完成 Task A 應補生今天的任務")
    }

    /// 正常情境：Task A（昨天）+ Task B（今天，未完成）→ 完成 Task A 不應重複建立今天任務
    func testNoDuplicate_whenNextOccurrenceExistsAndUncompleted() throws {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let today = cal.startOfDay(for: Date())
        let series = UUID()

        let taskA = makeTask(title: "每日站會", dueDate: yesterday, series: series)
        let taskB = makeTask(title: "每日站會", dueDate: today, series: series)
        try context.save()

        let snapshot = try fetchAll()
        let before = snapshot.count

        simulateComplete(taskA, allTasks: snapshot)
        try context.save()

        XCTAssertEqual(try fetchAll().count, before, "今天已有 Task B（未完成），完成 Task A 不應再建立任務")
        _ = taskB
    }

    /// 不同 series 的任務不應互相干擾
    func testNoInterference_betweenDifferentSeries() throws {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let today = cal.startOfDay(for: Date())
        let seriesA = UUID()
        let seriesB = UUID()

        let taskA = makeTask(title: "任務 A", dueDate: yesterday, series: seriesA)
        // Series B 今天已完成，不應阻擋 Series A 的補生
        let taskBOtherSeries = makeTask(title: "任務 B", dueDate: today, series: seriesB, completed: true)
        try context.save()

        let snapshot = try fetchAll()
        simulateComplete(taskA, allTasks: snapshot)
        try context.save()

        let todaySeriesA = try fetchAll().filter { t in
            guard let d = t.dueDate else { return false }
            return cal.isDateInToday(d) && t.seriesID == seriesA && !t.isCompleted
        }
        XCTAssertEqual(todaySeriesA.count, 1, "不同 series 不應互相干擾，Series A 應正常補生今天任務")
        _ = taskBOtherSeries
    }

    // MARK: - Helpers

    /// 鏡像修正後的 completeTask 完成分支邏輯（不含 UI 層）
    private func simulateComplete(_ task: TaskItem, allTasks: [TaskItem]) {
        task.isCompleted = true
        task.completedAt = Date()
        guard task.recurrence != nil, let nextDate = task.nextDueDate() else { return }
        // 修正後的判斷：含已完成任務在內的全部 occurrence
        if !nextOccurrenceExists(for: task, onDate: nextDate, allTasks: allTasks) {
            task.cloneForRecurrence(dueDate: nextDate, in: context)
        }
    }

    private func nextOccurrenceExists(for task: TaskItem, onDate nextDate: Date, allTasks: [TaskItem]) -> Bool {
        guard let series = task.seriesID else { return false }
        let cal = Calendar.current
        return allTasks.contains { t in
            t.id != task.id &&
            t.seriesID == series &&
            t.recurrence != nil &&
            (t.dueDate.map { cal.isDate($0, inSameDayAs: nextDate) } ?? false)
        }
    }

    @discardableResult
    private func makeTask(title: String, dueDate: Date, series: UUID, completed: Bool = false) -> TaskItem {
        let task = TaskItem(title: title)
        task.dueDate = dueDate
        task.seriesID = series
        task.isCompleted = completed
        if completed { task.completedAt = Date() }
        let rule = RecurrenceRule(frequency: .daily)
        context.insert(task)
        context.insert(rule)
        task.recurrence = rule
        return task
    }

    private func fetchAll() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>())
    }
}

// MARK: - 三條 spawn 路徑統一行為測試（Calendar 路徑斷鏈 Bug）

@MainActor
final class SharedSpawnTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: TaskItem.self, TaskList.self, Subtask.self, RecurrenceRule.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    /// 核心 Bug：Calendar 路徑舊實作以 `TaskItem.init` 手刻 clone，會配發全新 seriesID，
    /// 斷開重複序列鏈。統一後補生的下一筆必須「繼承」原任務 seriesID。
    func testSpawnNextIfNeeded_inheritsSeriesID() throws {
        let series = UUID()
        let task = makeTask(title: "番茄鐘", dueDate: Calendar.current.startOfDay(for: Date()), series: series)
        try context.save()

        let spawned = task.spawnNextIfNeeded(among: try fetchAll(), in: context)

        XCTAssertNotNil(spawned, "完成有重複規則的任務應補生下一筆")
        XCTAssertEqual(spawned?.seriesID, series, "補生的下一筆必須繼承同一 seriesID，不可配發新的")
    }

    /// 跨路徑去重：當啟動補生已用同一 series 補出今天的 occurrence，
    /// Calendar 路徑完成昨天任務時，因 seriesID 一致，不應再補出第二筆。
    func testSpawnNextIfNeeded_noDuplicateWhenSeriesOccurrenceExists() throws {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let today = cal.startOfDay(for: Date())
        let series = UUID()

        let taskA = makeTask(title: "看書", dueDate: yesterday, series: series)
        _ = makeTask(title: "看書", dueDate: today, series: series) // 啟動補生產出的今天 occurrence
        try context.save()

        let before = try fetchAll().count
        let spawned = taskA.spawnNextIfNeeded(among: try fetchAll(), in: context)
        try context.save()

        XCTAssertNil(spawned, "同 series 今天已有 occurrence，不應再補生")
        XCTAssertEqual(try fetchAll().count, before, "任務總數不應增加")
    }

    /// 非重複任務不補生。
    func testSpawnNextIfNeeded_noopForNonRecurring() throws {
        let task = TaskItem(title: "一次性任務")
        task.dueDate = Calendar.current.startOfDay(for: Date())
        context.insert(task)
        try context.save()

        let spawned = task.spawnNextIfNeeded(among: try fetchAll(), in: context)
        XCTAssertNil(spawned)
    }

    @discardableResult
    private func makeTask(title: String, dueDate: Date, series: UUID, completed: Bool = false) -> TaskItem {
        let task = TaskItem(title: title)
        task.dueDate = dueDate
        task.seriesID = series
        task.isCompleted = completed
        if completed { task.completedAt = Date() }
        let rule = RecurrenceRule(frequency: .daily)
        context.insert(task)
        context.insert(rule)
        task.recurrence = rule
        return task
    }

    private func fetchAll() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>())
    }
}

// MARK: - 持久化路徑與 legacy store 遷移測試

final class PersistenceStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TickTickPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testStoreURLIsAppSpecificAndNotGlobalDefaultStore() throws {
        let url = try PersistenceStore.storeURL(applicationSupportDirectory: temporaryDirectory)

        XCTAssertEqual(url.lastPathComponent, "TickTick.store")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "com.nickycho.TickTick")
        XCTAssertNotEqual(url.lastPathComponent, "default.store")
    }

    func testLegacyMigrationCopiesStoreAndSQLiteSidecars() throws {
        let fileManager = FileManager.default
        let legacyURL = PersistenceStore.legacyStoreURL(applicationSupportDirectory: temporaryDirectory)
        let legacyWALURL = URL(fileURLWithPath: legacyURL.path + "-wal")
        let legacySHMURL = URL(fileURLWithPath: legacyURL.path + "-shm")
        let legacyContents = [
            legacyURL: Data("store".utf8),
            legacyWALURL: Data("wal".utf8),
            legacySHMURL: Data("shm".utf8),
        ]

        for (url, data) in legacyContents {
            fileManager.createFile(atPath: url.path, contents: data)
        }

        try PersistenceStore.migrateLegacyStoreIfNeeded(
            applicationSupportDirectory: temporaryDirectory,
            fileManager: fileManager
        )

        let destinationURL = try PersistenceStore.storeURL(applicationSupportDirectory: temporaryDirectory)
        XCTAssertEqual(try Data(contentsOf: destinationURL), legacyContents[legacyURL])
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: destinationURL.path + "-wal")),
            legacyContents[legacyWALURL]
        )
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: destinationURL.path + "-shm")),
            legacyContents[legacySHMURL]
        )
    }
}
