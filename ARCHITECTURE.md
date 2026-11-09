# TickTick Clone — 架構與技術細節

## 類比：這個 App 像什麼？

想像一個有三層抽屜的文件櫃：
- **左抽屜（Sidebar）**：放清單索引，告訴你去哪找任務
- **中抽屜（TaskList）**：放任務卡片，依選中的清單過濾
- **右抽屜（Detail）**：放某張任務卡片的完整內容

整個 app 的 UI 狀態，就是「現在打開了哪個左抽屜格 × 現在手上拿的哪張任務卡」。

---

## 技術棧

| 層面 | 技術 |
|------|------|
| UI 框架 | SwiftUI（NavigationSplitView 三欄佈局） |
| 資料持久層 | SwiftData（iOS 17 / macOS 14+） |
| 平台 | macOS（原生 `.app`） |
| 建置工具 | XcodeGen（`project.yml` → `.xcodeproj`） |
| 語言 | Swift 5.9+ |
| 設定儲存 | `UserDefaults`（@AppStorage） |

---

## 整體架構圖

```
TickTickApp (App Entry)
│
├── ModelContainer          ← SwiftData 持久層（4 個 Model）
│   ├── TaskItem
│   ├── TaskList
│   ├── Subtask
│   └── RecurrenceRule
│
├── WindowGroup
│   └── ContentView          ← 根視圖，持有全域導覽狀態
│       ├── @State sidebarSelection: SidebarSelection
│       ├── @State selectedTask: TaskItem?
│       │
│       ├── SidebarView      ← 左欄：清單選擇
│       ├── TaskListView     ← 中欄：任務列表（或 CalendarView）
│       └── TaskDetailView   ← 右欄：任務詳情
│
└── Settings
    └── SettingsView         ← ⌘, 偏好設定視窗（字型大小）
```

---

## 導覽狀態機

整個 app 的選取狀態由兩個 `@State` 驅動，集中在 `ContentView`：

```
ContentView
  ├── sidebarSelection: SidebarSelection  ─→  決定中欄顯示哪個清單
  └── selectedTask: TaskItem?             ─→  決定右欄顯示哪個任務
```

`SidebarSelection` 是一個 enum，兩個 case：

```swift
enum SidebarSelection: Hashable {
    case smartList(SmartListType)           // 今天 / 明天 / 近7天 / 全部 / 行事曆
    case taskList(PersistentIdentifier)    // 使用者建立的清單（SwiftData ID）
}
```

切換 `sidebarSelection` 時，`.onChange` 會自動清空 `selectedTask`，避免右欄顯示已不屬於當前清單的任務。

---

## 資料模型關聯圖

```
TaskList ──(cascade delete)──→ [TaskItem]
                                    │
                         ┌──────────┴──────────┐
                         ↓                     ↓
               [Subtask] (cascade)    RecurrenceRule? (cascade)
```

### TaskItem

| 欄位 | 型別 | 說明 |
|------|------|------|
| `title` | String | 任務名稱 |
| `notes` | String | 備註 |
| `isCompleted` | Bool | 是否完成 |
| `completedAt` | Date? | 完成時間戳 |
| `dueDate` | Date? | 到期日（含可選時間） |
| `hasDueTime` | Bool | dueDate 是否包含時刻 |
| `priorityRaw` | Int | Priority enum 的 rawValue（0–3） |
| `order` | Int | 手動排序索引 |
| `list` | TaskList? | 所屬清單（optional） |
| `subtasks` | [Subtask] | 子任務（一層） |
| `recurrence` | RecurrenceRule? | 重複規則 |

**Gotcha**：SwiftData 無法直接儲存 enum，所以 `priority` 用 `priorityRaw: Int` 存，`priority: Priority` 是 computed property。`RecurrenceRule.frequency` 同理用 `frequencyRaw: String`。

### RecurrenceRule

| 欄位 | 型別 | 說明 |
|------|------|------|
| `frequencyRaw` | String | `"daily"` / `"weekly"` / `"workdays"` |
| `weekdays` | [Int] | 週幾觸發（0=日 … 6=六），只有 weekly 使用 |

**Weekday 慣例**：`Calendar.component(.weekday)` 回傳 1–7（1=日），程式碼統一 `-1` 轉成 0–6。

---

## 資料過濾策略

`TaskListView` 用 `@Query(sort: \TaskItem.order)` 一次抓取**所有** TaskItem，再於 memory 中 filter：

```
為什麼不用 SwiftData Predicate？
→ optional chaining（task.list?.persistentModelID）在 #Predicate 中有限制
→ 資料量不大，記憶體過濾效能足夠
```

### Smart List 日期邊界

```
now
 │
 ├── startOfToday   = 今天 00:00:00
 ├── endOfToday     = 明天 00:00:00   ← 今天清單：dueDate < endOfToday（含 overdue）
 ├── endOfTomorrow  = 後天 00:00:00   ← 明天清單：endOfToday ≤ dueDate < endOfTomorrow
 └── endOf7Days     = 7天後的 00:00:00 ← 近7天：dueDate < endOf7Days
```

Smart List 排序依 `dueDate` 升冪；UserList 依 `order` 欄位（支援 drag & drop `onMove`）。

---

## 重複任務邏輯

### 完成時（`completeTask`）

```
使用者勾選完成
     │
     ├── task.isCompleted = true，completedAt = now
     │
     └── 有 recurrence？
           ├── YES → 計算 nextDueDate
           │          └── 該日期是否已有 spawnedNextTask？
           │                ├── 已有 → 不重複建立
           │                └── 沒有 → 建立新 TaskItem（複製屬性 + 新 RecurrenceRule）
           └── NO  → 只標記完成
```

**關鍵設計**：完成時**不修改原任務**，而是建立新任務（複製一份）。這樣已完成的任務會留在歷史中，新任務代表下一次重複。

### 取消完成時

若取消勾選，會找到對應的「下一筆」任務並刪除，避免出現孤立的 spawned task。

### 補生跨日遺漏的重複任務（`generateMissedRecurrencesIfNeeded`）

在 app 啟動（`NSApplication.didBecomeActiveNotification`）或跨日（`NSCalendarDayChanged`）時觸發：

```
lastMissedRecurrenceCheck == today？
  ├── YES → 跳過（已處理過）
  └── NO  → 掃描所有未完成且有 recurrence 的任務
              對每筆任務從 dueDate 向前滾動，直到今天
              每個日期若不存在對應任務 → 建立之
              記錄 today 到 UserDefaults，避免重複執行
```

去重用 `"標題|清單ID|日期時間戳"` 組成的 key set。

---

## ⌘N 的訊號流

```
Menu Bar "新增任務" (⌘N)
     │
     ↓
NotificationCenter.post(.newTask)
     │
     ↓
TaskListView.onReceive(.newTask)
     │
     ↓
isAddingTask = true
     │
     ↓
AddTaskBar 展開，獲得焦點
```

這樣 Menu Bar Command 不需要直接參考任何 View，解耦合。

---

## macOS 的 List 選取問題

macOS 上 `List(selection:)` 配合 SwiftData `@Bindable` 有不可靠行為，因此本專案用 **`onTapGesture`** 手動設定 `selectedTask`，並透過 `listRowBackground` 模擬選中高亮：

```swift
TaskRow(...)
    .onTapGesture { selectedTask = task }
    .listRowBackground(
        isSelected ? Color.accentColor.opacity(0.12) : Color.clear
    )
```

---

## 行事曆模式

```
SidebarSelection == .smartList(.calendar)
     │
     ├── 中欄 → CalendarView（月視圖 / 週視圖）
     │           ├── 月視圖：LazyVGrid 42 格（6週×7天）
     │           └── 週視圖：HStack 7 個 CalendarWeekDayColumn
     │
     └── 右欄 → 選中任務 → TaskDetailView
                未選任務 → CalendarDayDetailView（顯示當日任務清單）
```

所有任務過濾：`allTasks.filter { Calendar.isDate(due, inSameDayAs: date) }`（同樣是記憶體過濾）。

---

## View 組件職責表

| 檔案 | 職責 |
|------|------|
| `TickTickApp.swift` | App 進入點、ModelContainer、重複任務補生、⌘N 定義 |
| `ContentView.swift` | 三欄 NavigationSplitView、全域導覽狀態 |
| `SidebarView.swift` | 清單列表、新增/刪除/重新命名清單、drag-to-reorder |
| `TaskListView.swift` | 任務過濾+排序、完成邏輯、新增任務 |
| `TaskRow.swift` | 單一任務列表行（checkbox、標題、到期日、badges） |
| `AddTaskBar.swift` | 底部快速輸入欄 |
| `TaskDetailView.swift` | 任務詳情面板（標題、備註、到期日、優先級、重複、子任務） |
| `RecurrencePicker.swift` | 重複規則選取（頻率 + 週幾選擇器） |
| `SubtaskSection.swift` | 子任務列表（新增、勾選、刪除） |
| `CalendarView.swift` | 月/週行事曆視圖 |
| `CalendarDayDetailView.swift` | 行事曆右欄：點擊日期時顯示當日任務 |
| `ListEditSheet.swift` | 清單名稱+顏色編輯 Sheet |
| `SettingsView.swift` | 偏好設定（字型大小，@AppStorage） |
| `Enums.swift` | Priority、RecurrenceFrequency、SmartListType、SidebarSelection |
| `Color+Hex.swift` | `Color(hex:)` 擴充，用於清單顏色 |

---

## SwiftData Schema 注意事項

持久化 store 使用 app 專屬路徑：

```text
~/Library/Application Support/com.nickycho.TickTick/TickTick.store
```

首次啟動時，如果專屬 store 尚不存在，`PersistenceStore` 會將舊版使用的
`~/Library/Application Support/default.store` 及其 `-wal`、`-shm` sidecar 複製到新路徑。
之後 app 只會開啟專屬 store，避免與其他使用 SwiftData 預設 `default.store` 的 macOS
服務互相碰撞。

> **新增 model 屬性前必讀**：SwiftData auto-migration 在某些情況下會失敗並清空資料庫。建議在開發時備份資料，或提供 `VersionedSchema` + `MigrationPlan`（目前 v1 尚未實作 migration plan）。

---

## 建置流程

```bash
# 1. 重新產生 Xcode project（修改 project.yml 後執行）
xcodegen generate

# 2. 編譯
xcodebuild -project TickTick.xcodeproj \
           -scheme TickTick \
           -destination 'platform=macOS' build

# 3. 執行
open ~/Library/Developer/Xcode/DerivedData/TickTick-*/Build/Products/Debug/TickTick.app
```
