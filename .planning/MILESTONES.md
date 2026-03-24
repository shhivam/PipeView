# Milestones

## v1.0 MVP (Shipped: 2026-03-24)

**Phases completed:** 7 phases, 14 plans, 29 tasks

**Key accomplishments:**

- Xcode project with sysctl IFMIB_IFDATA byte counter reader, interface filter logic, speed computation with counter reset handling, and 19 passing unit tests
- NWPathMonitor interface detection with SystemConfiguration name resolution, sleep/wake handling, and @Observable NetworkMonitor engine orchestrating the full polling pipeline
- SpeedFormatter and SpeedTextBuilder with 31 TDD tests covering SI-unit conversion, adaptive precision, unit modes, display modes, and edge cases
- NSStatusItem with live speed text, monospaced digits, context menu, and auto-login via SMAppService
- GRDB.swift database layer with DatabaseWriter protocol, v1 migration creating 6 tables, RawSample and 5 aggregation tier record types, and 7 passing database tests
- BandwidthRecorder observes NetworkMonitor via withObservationTracking, accumulates 5 snapshots (10s window), and writes per-interface RawSample records to SQLite off the main thread
- Cascading 5-tier aggregation engine (raw->minute->hour->day->week/month) with UTC bucketing, watermark optimization, and 24h raw sample pruning on background timers
- Six SwiftUI popover views with segmented tab switcher, per-interface breakdown, SF Symbol icons, semantic-only colors, and VoiceOver accessibility
- StatusBarController refactored for left-click NSPopover with live per-interface data and right-click context menu with Metrics/Preferences/About/Quit
- Shared types, preference enums, byte formatter, history time ranges, and AppDatabase chart/stats queries with 42 passing tests
- History tab with grouped download/upload bar charts via Swift Charts, interactive selection tooltips, and 3 cumulative stats cards (Today/Week/Month)
- Full preferences form with display mode, unit, interval, and launch-at-login settings wired to live menu bar updates via @AppStorage and UserDefaults observation
- Fixed BandwidthRecorder to use mutable pollingInterval synced with user preferences, ensuring correct byte calculations at 1s/2s/5s intervals
- Phase 4 VERIFICATION.md created with 15/15 truths verified, and all 18 v1 requirement checkboxes fixed to checked with 100% traceability coverage

---
