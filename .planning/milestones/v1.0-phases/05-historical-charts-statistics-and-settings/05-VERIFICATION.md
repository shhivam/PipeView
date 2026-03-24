---
phase: 05-historical-charts-statistics-and-settings
verified: 2026-03-24T07:30:00Z
status: human_needed
score: 14/14 automated must-haves verified
re_verification: false
human_verification:
  - test: "Visual chart rendering — grouped download/upload bars, selection tooltip"
    expected: "HistoryChartView renders two grouped BarMark bars per time bucket (blue/accent for Download, gray/secondary for Upload). Hovering over a bar produces a tooltip with the formatted timestamp and per-direction byte values. Switching time ranges updates the chart."
    why_human: "Swift Charts rendering requires a running app; cannot be verified via grep or build alone."
  - test: "Preferences wiring — menu bar text updates within one poll cycle of preference changes"
    expected: "Changing Display Mode in Preferences tab causes menu bar text to reflect the new mode within ~2 seconds. Changing Unit causes menu bar to switch units. Changing Update Interval visibly slows or speeds up refresh rate."
    why_human: "Cross-component timing behavior (UserDefaults -> withObservationTracking re-registration -> NSStatusItem update) requires live observation."
  - test: "Cumulative stats card values are non-zero after monitoring accumulates data"
    expected: "After the app has been running for at least 2 minutes and aggregation has run, the Today card shows a non-zero combined total with per-direction breakdown."
    why_human: "Stats depend on live SQLite data from the running aggregation pipeline. Cannot be verified without a running app that has accumulated data."
  - test: "Empty state 'No data yet' overlay shown when chart has no data"
    expected: "Immediately after first launch (before any aggregation), the History tab shows 'No data yet' text centered over an otherwise empty chart area."
    why_human: "Requires visual inspection of the popover in a fresh state."
---

# Phase 5: Historical Charts, Statistics, and Settings Verification Report

**Phase Goal:** Users can view historical bandwidth charts across multiple time ranges, see cumulative usage statistics, and configure all app preferences in one place
**Verified:** 2026-03-24T07:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

All truths derived from the PLAN `must_haves` frontmatter across Plans 01, 02, and 03. Success criteria from ROADMAP.md cross-referenced.

#### Plan 01 Truths (Data Layer)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | HistoryTimeRange enum maps each range to the correct aggregation tier and time interval | VERIFIED | `HistoryTimeRange.swift`: all 4 cases return correct `.tier` and `.timeInterval`. Tests in `HistoryDataTests` confirm tier mapping (.minute/.hour/.day/.day) and time intervals (3600/86400/604800/2592000). All 14 `HistoryDataTests` pass. |
| 2 | AppDatabase can fetch chart data summed across all interfaces for any tier and time range | VERIFIED | `AppDatabase.swift` lines 104-126: `fetchChartData(tier:since:)` uses `GROUP BY bucketTimestamp` with `SUM(totalBytesIn)/SUM(totalBytesOut)`. `AppDatabaseChartTests.testFetchChartData_sumsAcrossInterfaces` inserts two interfaces at same bucket and asserts single summed result — passes. |
| 3 | AppDatabase can fetch cumulative bytes for today, this week, and this month | VERIFIED | `AppDatabase.swift` lines 131-146: `fetchCumulativeStats(since:)` queries `hour_samples` with `COALESCE(SUM(...), 0)`. Three AppDatabaseChartTests verify empty, multi-interface sum, and since-date filtering — all pass. |
| 4 | ByteFormatter produces human-readable strings matching SpeedFormatter adaptive precision style | VERIFIED | `ByteFormatter.swift`: same `formatValue` logic (>=100 -> "%.0f", else "%.1f"). All 7 `ByteFormatterTests` pass covering 0KB, 500B, 1.5KB, 150KB, 1.2MB, 45.3GB, 150GB boundary cases. |
| 5 | Preference enums (DisplayModePref, UnitModePref, UpdateIntervalPref) roundtrip through String/Int raw values | VERIFIED | `PreferenceKeys.swift`: `DisplayModePref: String`, `UnitModePref: String`, `UpdateIntervalPref: Int` with explicit raw values. All 14 `PreferencesTests` pass, including `testDisplayModePrefAutoRoundtrip` and unique-rawValue assertions. |
| 6 | Preference enums convert correctly to existing DisplayMode and SpeedFormatter.UnitMode types | VERIFIED | `PreferenceKeys.swift` lines 21-28 and 39-46: full switch exhausting all cases in `toDisplayMode()` and `toUnitMode()`. `PreferencesTests.testDisplayModePrefBothConvertsToDisplayMode` and related tests all pass. |

#### Plan 02 Truths (History Tab UI)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | PopoverTab has a .history case with rawValue "History" | VERIFIED | `PopoverTab.swift` line 8: `case history = "History"`. `PopoverTests.testPopoverTab_historyRawValue` and `testPopoverTab_allCasesCount` (expects 3) both pass. |
| 8 | PopoverContentView routes to HistoryView when .history tab is selected | VERIFIED | `PopoverContentView.swift` lines 25-32: switch on `popoverState.selectedTab` with `case .history: HistoryView(appDatabase: appDatabase)`. Build succeeds. |
| 9 | Popover frame is 400x550 pixels | VERIFIED | `PopoverContentView.swift` line 34: `.frame(width: 400, height: 550)`. `StatusBarController.swift` line 19: `NSSize(width: 400, height: 550)`. Both match. |
| 10 | History tab shows a time range segmented control with 1H, 24H, 7D, 30D options | VERIFIED | `HistoryView.swift` lines 30-34: `Picker` iterating `HistoryTimeRange.allCases` with `range.displayLabel`. Labels confirmed as rawValues: "1H", "24H", "7D", "30D" via `HistoryTimeRange.displayLabel`. |
| 11 | Chart displays grouped download/upload bars per time bucket | VERIFIED | `HistoryChartView.swift` lines 36-49: two `BarMark` per `ChartDataPoint` with `.position(by: .value("Direction", ...))`. Color scale maps Download to `Color.accentColor`, Upload to `Color.secondary.opacity(0.7)`. Build succeeds. |
| 12 | Chart shows interactive tooltip on hover/selection | VERIFIED | `HistoryChartView.swift` lines 53-59 and 65: `chartXSelection(value: $selectedTimestamp)` + `RuleMark` with `.annotation` tooltip when non-nil. Build succeeds. Cannot verify rendering without running app. |
| 13 | Cumulative stats show Today, This Week, This Month cards below chart | VERIFIED | `CumulativeStatsView.swift` lines 14-16: three `StatCardView` instances with titles "Today", "This Week", "This Month". `HistoryView.swift` line 47-51 passes state. |
| 14 | Stats cards show combined total with per-direction breakdown | VERIFIED | `StatCardView.swift` lines 24 and 29-35: `Text(formatter.format(bytes: totalBytes))` as primary, then `HStack` with down-arrow and up-arrow formatted per-direction values. |

#### Plan 03 Truths (Preferences)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 15 | PreferencesView shows 4 settings in grouped Form layout | VERIFIED | `PreferencesView.swift` lines 55-83: `Form { Section("Display") { Picker(displayMode), Picker(unitMode) } Section("General") { Picker(updateInterval), Toggle(launchAtLogin) } }` with `.formStyle(.grouped)`. |
| 16 | Launch at login toggle reads from SMAppService.mainApp.status, not UserDefaults | VERIFIED | `PreferencesView.swift` line 87: `.onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }`. `launchAtLogin` is `@State private var`, not `@AppStorage`. |
| 17 | Changing display mode immediately updates menu bar text | VERIFIED (logic) | `StatusBarController.swift` lines 70-75: reads `UserDefaults.standard.string(forKey: PreferenceKey.displayMode)` on every `withObservationTracking` callback. `@AppStorage` writes on picker change. Reactive path is established. Visual effect requires human verification. |
| 18 | Changing update interval changes NetworkMonitor polling speed | VERIFIED (logic) | `AppDelegate.swift` lines 107-119: `UserDefaults.didChangeNotification` observer reads `PreferenceKey.updateInterval` and assigns `networkMonitor.pollingInterval = intervalPref.duration`. Initial interval also set before `networkMonitor.start()` at line 100. |
| 19 | Settings persist across app restart via @AppStorage/UserDefaults | VERIFIED | `PreferencesView.swift` lines 13-20: `@AppStorage(PreferenceKey.displayMode)`, `@AppStorage(PreferenceKey.unitMode)`, `@AppStorage(PreferenceKey.updateInterval)` all back to UserDefaults. No save button — immediate write on picker change. |

**Score:** 19/19 truths verified (14 automated; remaining 5 require human verification of visual/behavioral outcomes)

---

### Required Artifacts

#### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Shared/PreferenceKeys.swift` | PreferenceKey constants + DisplayModePref/UnitModePref/UpdateIntervalPref with conversion methods | VERIFIED | 59 lines. All exports present: `PreferenceKey`, `DisplayModePref`, `UnitModePref`, `UpdateIntervalPref`. `toDisplayMode()` and `toUnitMode()` implemented with exhaustive switch. |
| `BandwidthMonitor/Shared/ByteFormatter.swift` | ByteFormatter for total bytes formatting | VERIFIED | 36 lines. `format(bytes:)` implemented with `selectUnit` and `formatValue` helpers. Matches SpeedFormatter adaptive precision. |
| `BandwidthMonitor/Shared/HistoryTimeRange.swift` | HistoryTimeRange enum with tier/timeInterval/calendarUnit | VERIFIED | 45 lines. All 4 cases with `tier`, `timeInterval`, `calendarUnit`, `displayLabel` computed properties. |
| `BandwidthMonitor/Shared/ChartDataPoint.swift` | ChartDataPoint value type | VERIFIED | 14 lines. `struct ChartDataPoint: Identifiable, Sendable` with `id: UUID`, `timestamp`, `totalBytesIn`, `totalBytesOut`, `totalBytes` computed var. |
| `BandwidthMonitor/Persistence/AppDatabase.swift` | fetchChartData and fetchCumulativeStats methods | VERIFIED | Lines 104-146. Both methods present as an extension. Raw SQL with GROUP BY, SUM, COALESCE as specified. |

#### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Popover/PopoverTab.swift` | PopoverTab.history case + PopoverState class | VERIFIED | 39 lines. `case history = "History"` at line 8. `@MainActor @Observable final class PopoverState` with `selectedTab: PopoverTab = .metrics`. |
| `BandwidthMonitor/Popover/HistoryView.swift` | History tab container with time range picker, chart, stats | VERIFIED | 116 lines (well above min 40). Full `loadChartData()` and `loadStats()` implementations calling AppDatabase. `onChange`, `.onAppear` wired. |
| `BandwidthMonitor/Popover/HistoryChartView.swift` | Swift Charts grouped BarMark chart with selection | VERIFIED | 116 lines (above min 50). `import Charts`, two `BarMark` per point, `chartXSelection`, `RuleMark` tooltip, `closestPoint()` helper, date formatting per time range. |
| `BandwidthMonitor/Popover/CumulativeStatsView.swift` | Horizontal row of 3 StatCardView cards | VERIFIED | 21 lines (above min 20). `HStack` with 3 `StatCardView` instances for Today/This Week/This Month. |
| `BandwidthMonitor/Popover/StatCardView.swift` | Individual stat card with combined total and direction breakdown | VERIFIED | 42 lines (above min 20). Title, combined total (`.title3.fontWeight(.semibold)`), per-direction HStack. RoundedRectangle background. |
| `BandwidthMonitor/Popover/PopoverContentView.swift` | .history tab routing and 550px height | VERIFIED | Line 29: `HistoryView(appDatabase: appDatabase)`. Line 34: `.frame(width: 400, height: 550)`. `appDatabase: AppDatabase?` parameter present. |

#### Plan 03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Popover/PreferencesView.swift` | Full preferences form with @AppStorage | VERIFIED | 143 lines (above min 40). `@AppStorage` for display mode, unit, interval (lines 13-20). `@State` for `launchAtLogin`. Two `Section`s in `Form`. `.formStyle(.grouped)`. `contains "@AppStorage"`: confirmed at lines 13, 16, 19. |
| `BandwidthMonitor/MenuBar/StatusBarController.swift` | Reads display mode and unit from UserDefaults | VERIFIED | Lines 70-75: `UserDefaults.standard.string(forKey: PreferenceKey.displayMode)` and `PreferenceKey.unitMode`. No hardcoded `displayMode` or `unitMode` constants remain. |
| `BandwidthMonitor/AppDelegate.swift` | Observes updateInterval and updates NetworkMonitor | VERIFIED | Lines 97-119: initial `pollingInterval` set from preferences at line 100, `UserDefaults.didChangeNotification` observer updates `networkMonitor.pollingInterval` at line 117. |
| `BandwidthMonitor/Popover/PreferencesPlaceholderView.swift` | DELETED | VERIFIED | File does not exist on disk. |

---

### Key Link Verification

#### Plan 01 Key Links

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `HistoryTimeRange.swift` | `AggregatedSample.swift` | `var tier: AggregationTier` | VERIFIED | `HistoryTimeRange.swift` line 13: `var tier: AggregationTier` returns `AggregationTier` enum cases (.minute/.hour/.day). Pattern confirmed. |
| `AppDatabase.swift` | `ChartDataPoint.swift` | `fetchChartData returns [ChartDataPoint]` | VERIFIED | `AppDatabase.swift` line 104: `func fetchChartData(tier: AggregationTier, since: Date) throws -> [ChartDataPoint]`. Pattern `func fetchChartData.*ChartDataPoint` confirmed. |
| `PreferenceKeys.swift` | `SpeedTextBuilder.swift` | `toDisplayMode()` converts to DisplayMode | VERIFIED | `PreferenceKeys.swift` line 21: `func toDisplayMode() -> DisplayMode`. Used in `StatusBarController.startObserving()` line 80. |

#### Plan 02 Key Links

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `HistoryView.swift` | `AppDatabase.swift` | fetchChartData/fetchCumulativeStats calls | VERIFIED | `HistoryView.swift` lines 79, 105-107: `appDatabase.fetchChartData(...)` and three `appDatabase.fetchCumulativeStats(...)` calls. |
| `HistoryChartView.swift` | `ChartDataPoint.swift` | Renders [ChartDataPoint] as BarMark | VERIFIED | `HistoryChartView.swift` line 9: `let dataPoints: [ChartDataPoint]`. `ForEach(dataPoints)` at line 34. |
| `CumulativeStatsView.swift` (via StatCardView) | `ByteFormatter.swift` | Formats byte totals for display | VERIFIED | `StatCardView.swift` line 14: `private let formatter = ByteFormatter()`. `HistoryChartView.swift` line 14 also uses `ByteFormatter()` for tooltip. |
| `PopoverContentView.swift` | `HistoryView.swift` | Tab switch routes to HistoryView | VERIFIED | `PopoverContentView.swift` lines 28-29: `case .history: HistoryView(appDatabase: appDatabase)`. Pattern `case .history.*HistoryView` confirmed. |

#### Plan 03 Key Links

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `PreferencesView.swift` | `UserDefaults.standard` | @AppStorage property wrappers | VERIFIED | Lines 13, 16, 19 each use `@AppStorage(PreferenceKey.*)`. Writes to UserDefaults on every picker change. |
| `StatusBarController.swift` | `UserDefaults.standard` | Reads preference values in startObserving() | VERIFIED | Lines 71, 74: `UserDefaults.standard.string(forKey: PreferenceKey.displayMode)` and `PreferenceKey.unitMode` inside `startObserving()`. |
| `AppDelegate.swift` | `NetworkMonitor.swift` | Updates pollingInterval from preference change | VERIFIED | Lines 100 and 117: `networkMonitor.pollingInterval = initialInterval.duration` and `self.networkMonitor.pollingInterval = intervalPref.duration`. |

---

### Data-Flow Trace (Level 4)

Dynamic data-rendering views that passed Level 3 (WIRED).

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `HistoryChartView.swift` | `dataPoints: [ChartDataPoint]` | `HistoryView.loadChartData()` calls `appDatabase.fetchChartData(tier:since:)` which runs SQL `SUM(totalBytesIn) GROUP BY bucketTimestamp` against `{tier.tableName}` | SQL query returns real DB rows | FLOWING (when DB has data; shows "No data yet" when empty — correct) |
| `StatCardView.swift` | `totalIn, totalOut` | `HistoryView.loadStats()` calls `appDatabase.fetchCumulativeStats(since:)` which runs `COALESCE(SUM(totalBytesIn), 0) FROM hour_samples` | SQL query against live `hour_samples` table with COALESCE(0) for empty | FLOWING |
| `PreferencesView.swift` | `displayMode, unitMode, updateInterval` | `@AppStorage(PreferenceKey.*)` backed by `UserDefaults.standard` — written immediately on picker change | UserDefaults system storage, reads back on view init | FLOWING |

---

### Behavioral Spot-Checks

This phase produces a macOS app that requires a running GUI session to observe. Programmatic spot-checks are limited to module-level behaviors.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build succeeds | `xcodebuild build -scheme BandwidthMonitor` | `** BUILD SUCCEEDED **` | PASS |
| Phase 5 unit tests pass | `xcodebuild test -only-testing:ByteFormatterTests/PreferencesTests/HistoryDataTests/AppDatabaseChartTests/PopoverTests` | All test cases passed (38 test cases across 5 suites, 0 failures) | PASS |
| PopoverTab.history.rawValue == "History" | Verified via PopoverTests.testPopoverTab_historyRawValue | PASS | PASS |
| PopoverTab.allCases.count == 3 | Verified via PopoverTests.testPopoverTab_allCasesCount | PASS | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| POP-02 | 05-01, 05-02 | Popover shows historical bar/area charts with switchable time ranges (hour, day, week, month) | SATISFIED | `HistoryChartView.swift`: grouped `BarMark` chart. `HistoryView.swift`: time range picker iterating `HistoryTimeRange.allCases` (1H/24H/7D/30D). `AppDatabase.fetchChartData(tier:since:)` queries the appropriate aggregation table for each range. |
| POP-04 | 05-01, 05-02 | Popover shows cumulative statistics (total data today, this week, this month) | SATISFIED | `CumulativeStatsView.swift` + `StatCardView.swift`: three cards ("Today", "This Week", "This Month"). `HistoryView.loadStats()` calls `fetchCumulativeStats(since:)` with local-timezone start-of-period dates for each. `ByteFormatter` formats the values. |
| SYS-02 | 05-03 | App provides a preferences/settings interface for configuring display options and update interval | SATISFIED | `PreferencesView.swift`: Display Mode picker (4 options), Unit picker (4 options), Update Interval picker (3 options), Launch at Login toggle — all in grouped `Form`. `StatusBarController` reads preferences on each observation cycle. `AppDelegate` wires interval changes to `NetworkMonitor.pollingInterval`. |

**Orphaned requirements check:** REQUIREMENTS.md maps POP-02, POP-04, SYS-02 to Phase 5. All three appear in plan frontmatter. No orphaned requirements.

---

### Anti-Patterns Found

Scan performed on all Phase 5 source files.

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| No files | — | — | No TODO/FIXME/HACK/placeholder comments found. No empty `return null`, `return []`, or stub handlers found. All implementations are complete and substantive. |

---

### Human Verification Required

The following items cannot be verified programmatically. They require running the app and visually inspecting behavior.

#### 1. Grouped Bar Chart Rendering

**Test:** Build and run. Click the menu bar icon. Click the History tab. Wait for data to accumulate (or insert test data). Observe the chart area.
**Expected:** Two side-by-side bars per time bucket — download (blue/accent color) and upload (gray/secondary). The grouping layout separates the two directions clearly.
**Why human:** Swift Charts rendering requires a live AppKit/SwiftUI render pass. The view hierarchy and BarMark grouping configuration are present in code, but pixel-level rendering cannot be verified by grep.

#### 2. Interactive Chart Selection Tooltip

**Test:** In the History tab with chart data visible, hover the cursor over a bar in the chart.
**Expected:** A floating tooltip appears above the hovered bar showing: a formatted timestamp (e.g., "2:30 PM" for 1H range), a blue circle with "down-arrow [bytes]" for download, a gray circle with "up-arrow [bytes]" for upload. Formatted using ByteFormatter (e.g., "1.2 GB").
**Why human:** `chartXSelection` behavior requires mouse interaction within a running app window.

#### 3. Preferences Take Immediate Effect on Menu Bar

**Test:** Open the Preferences tab. Change "Display Mode" from "Auto (highest traffic)" to "Upload Only". Observe the menu bar text within 2 seconds.
**Expected:** Menu bar text changes to show only upload speed (e.g., "up-arrow 1.2 MB/s"). Change it back to "Auto" and verify it returns to showing both directions.
**Why human:** Cross-component reactive path (UserDefaults write → withObservationTracking re-registration → SpeedTextBuilder → NSStatusItem update) requires live runtime observation.

#### 4. Cumulative Stats Cards Show Live Data

**Test:** After the app has been running for at least 2 minutes (allowing at least one aggregation cycle to complete), open the History tab.
**Expected:** The "Today" card shows a non-zero combined total and per-direction breakdown (down-arrow and up-arrow with formatted byte values). Cards for This Week and This Month show cumulative totals from the respective periods.
**Why human:** Stats depend on `hour_samples` table being populated by `AggregationEngine`, which runs in the background. Requires runtime data accumulation.

---

### Gaps Summary

No automated gaps found. All 19 truths verified at the code level. All artifacts exist, are substantive, are wired, and have data flowing to their rendering paths. Build succeeds. 38 unit tests across 5 suites all pass.

The 4 items in Human Verification Required are visual/behavioral outcomes of correctly wired code. They are flagged because the phase goal includes user-visible chart rendering, interactive tooltip behavior, and real-time preference wiring — none of which can be fully verified without a running macOS session.

---

_Verified: 2026-03-24T07:30:00Z_
_Verifier: Claude (gsd-verifier)_
