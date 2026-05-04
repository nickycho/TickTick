# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# 重新產生 Xcode project（改 project.yml 後必須執行）
xcodegen generate

# 編譯
xcodebuild -project TickTick.xcodeproj -scheme TickTick -destination 'platform=macOS' build

# 執行（編譯後）
open ~/Library/Developer/Xcode/DerivedData/TickTick-*/Build/Products/Debug/TickTick.app
```

> 無測試目標，目前不需要 `xcodebuild test`。

## v1 產品設計決策

這些決策在專案初期已明確確認，未來功能開發應以此為基準。

### v1 功能範圍（已實作）
- Task CRUD、List 管理、到期日+時間、優先級、子任務（一層）、重複任務、Smart List
- 優先級視覺：旗子 icon，高=紅、中=橘、低=藍
- 重複規則：每天、每週（指定星期幾）、每個工作日
- Smart List 今天 = `dueDate < endOfToday`（含 overdue）且未完成

### 明確排除 v1 的功能
標籤、番茄鐘、行事曆視圖、Markdown、Menu bar 常駐、通知提醒、雲端同步。

加入這些功能前請先確認是否進入 v2 排程。

### UI 佈局原則
- 三欄 layout（Sidebar / TaskList / Detail），Detail 為 inline panel，不跳 modal
- 新增 Task：底部 AddTaskBar（快速輸入）+ ⌘N；不開額外視窗
- 已完成 Task：底部折疊區塊（`showCompleted` toggle），不自動刪除
- Smart List 的任務依 dueDate 自動排序；UserList 依 `order` 欄位手動排序（支援 drag & drop）

---

## 架構概覽

### 導覽狀態機

整個 app 的導覽由 `ContentView` 的兩個 `@State` 驅動：

```
sidebarSelection: SidebarSelection   ──→  決定中間欄顯示哪個清單
selectedTask: TaskItem?              ──→  決定右側欄顯示哪個任務
```

`SidebarSelection` 是 enum，有兩個 case：
- `.smartList(SmartListType)` — 系統內建的智能列表（今天/明天/近7天/全部）
- `.taskList(PersistentIdentifier)` — 使用者建立的 TaskList（以 SwiftData 的 PersistentIdentifier 識別）

切換 `sidebarSelection` 時會自動清空 `selectedTask`（`.onChange` 連動）。

### 資料過濾策略

`TaskListView` 用 `@Query(sort: \TaskItem.order)` 一次抓取**全部** TaskItem，然後在 memory 中 filter：
- **UserList**：`$0.list?.persistentModelID == id`
- **SmartList**：按日期邊界計算（`endOfToday`、`endOfTomorrow`、`endOf7Days`），不用 SwiftData predicate

之所以不用動態 `#Predicate` 是因為 optional chaining 在 SwiftData predicate 中有限制，且本 app 資料量不大。

### 重複任務的完成邏輯

完成有 recurrence 的任務時，**不修改原任務**，而是：
1. 將原任務標記為 completed（帶 completedAt 時間戳）
2. 複製一筆新的 TaskItem，dueDate 設為 `task.nextDueDate()`
3. 同時複製一份新的 RecurrenceRule

`nextDueDate()` 在 `TaskItem` 上實作，`RecurrenceRule.weekdays` 使用 0=Sunday、1=Monday ... 6=Saturday 的慣例（Calendar.component(.weekday) - 1）。

### SwiftData 關聯結構

```
TaskList  ──(cascade delete)──→  [TaskItem]
TaskItem  ──(cascade delete)──→  [Subtask]
TaskItem  ──(cascade delete)──→  RecurrenceRule?
```

`priority` 在 `TaskItem` 中以 `priorityRaw: Int` 儲存，`priority: Priority` 是 computed property（SwiftData 不能直接儲存 enum）。同理，`RecurrenceRule.frequency` 以 `frequencyRaw: String` 儲存。

### ⌘N 的實作方式

`TickTickApp` 定義 `Notification.Name.newTask`，menu bar command 發送此 notification，`TaskListView` 透過 `.onReceive` 接收並開啟 `AddTaskBar`。
