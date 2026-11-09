# TickTick

A focused, native task manager for macOS, built with SwiftUI.

## Features

- Organize tasks in custom lists and built-in smart lists for Today, Tomorrow, the next 7 days, and all tasks.
- Set due dates, optional due times, priorities, and notes.
- Break work into subtasks.
- Create recurring tasks daily, on selected weekdays, or on workdays.
- Review scheduled tasks in monthly and weekly calendar views.
- Choose how missed recurring tasks are handled when the app becomes active again.
- Keep task data locally with SwiftData.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

Install XcodeGen with Homebrew if it is not already installed:

```bash
brew install xcodegen
```

Generate the Xcode project from `project.yml` and build the app:

```bash
xcodegen generate
xcodebuild -project TickTick.xcodeproj \
  -scheme TickTick \
  -destination 'platform=macOS' \
  build
```

You can also open `TickTick.xcodeproj` in Xcode after generating it.

## Project Structure

- `TickTick/App` — app entry point and local data store setup
- `TickTick/Models` — tasks, lists, subtasks, and recurrence models
- `TickTick/Views` — task lists, task details, calendar, and settings
- `TickTickTests` — unit tests

## License

No license file is currently included.
