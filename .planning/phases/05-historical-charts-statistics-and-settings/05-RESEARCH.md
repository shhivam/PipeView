# Phase 5: Historical Charts, Statistics, and Settings - Research

**Researched:** 2026-03-24
**Domain:** Swift Charts bar charts, GRDB data queries, SwiftUI preferences with @AppStorage, SMAppService
**Confidence:** HIGH

## Summary

Phase 5 completes the popover experience by adding a History tab (bar charts + cumulative stats), replacing the Preferences placeholder with actual settings controls, and wiring user preferences to the StatusBarController and NetworkMonitor. The core technical challenges are: (1) querying pre-aggregated GRDB data by time range and summing across interfaces for chart display, (2) building grouped BarMark charts with Swift Charts including interactive hover tooltips, (3) implementing @AppStorage-backed preferences with immediate effect propagation to non-SwiftUI AppKit code (StatusBarController), and (4) adding an SMAppService login-item toggle.

The codebase is well-structured for this phase. The five aggregation tier tables (minute_samples through month_samples) already store totalBytesIn/totalBytesOut per interface per bucket. The PopoverContentView already has a tab system with a segmented control. The SpeedFormatter and DisplayMode/UnitMode enums already exist and are used in SpeedTextBuilder/StatusBarController. The primary work is: new database query methods on AppDatabase, new chart/stats views, a new PreferencesView, and wiring @AppStorage changes into the existing observation pattern.

**Primary recommendation:** Use direct GRDB read queries (not GRDBQuery @Query) for chart data fetches triggered by time-range selection changes. Use @AppStorage for preferences with UserDefaults.standard KVO observation in StatusBarController. Use Swift Charts BarMark with `.position(by:)` for grouped download/upload bars and `.chartXSelection(value:)` for hover tooltips.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Three tabs in the popover: Metrics (live data), History (charts + stats), Preferences (settings). Segmented control at top, consistent with Phase 4 pattern
- **D-02:** Expand popover to ~400x550 to give charts breathing room (Phase 4 D-13 spacious feel)
- **D-03:** History tab layout: time range picker at top -> chart -> cumulative stats cards below. Chart is the hero element
- **D-04:** Time range selector is a segmented control with "1H | 24H | 7D | 30D" options -- consistent with the existing tab segmented control style
- **D-05:** Bar chart type -- discrete bars per time bucket, clear visual separation between periods. Uses Swift Charts BarMark
- **D-06:** Two grouped/side-by-side bar marks per bucket -- download in accent color, upload in secondary color, shared X axis
- **D-07:** Aggregate data only in charts (not per-interface breakdown) -- cleaner, matches "at a glance" philosophy
- **D-08:** Interactive with hover/tap tooltip -- shows exact value + timestamp at the selected point. Uses Swift Charts chartOverlay or chartXSelection
- **D-09:** Total bytes combined (in+out) as the primary number per card, with small per-direction breakdown below (up-arrow X / down-arrow Y)
- **D-10:** Auto-scaled human-readable formatting (e.g., "1.2 GB", "45.3 GB") -- consistent with SpeedFormatter patterns
- **D-11:** Horizontal row of 3 compact cards below the chart: Today | This Week | This Month
- **D-12:** Empty state: chart shows zero baseline with centered "No data yet" overlay text
- **D-13:** Four settings: display mode (auto/both/upload/download), unit preference (auto/KB/MB/GB), update interval (1s/2s/5s), launch-at-login toggle
- **D-14:** UserDefaults with @AppStorage for SwiftUI bindings -- native, simple persistence
- **D-15:** Settings take effect immediately on change -- standard macOS behavior, no save/apply button
- **D-16:** Grouped Form with Section layout: "Display" section (mode, unit) and "Advanced" section (interval, login item)

### Claude's Discretion
- Exact chart colors and opacity for download vs upload bars
- Bar width and spacing within Swift Charts
- Tooltip formatting and positioning
- How @AppStorage keys are named and how changes propagate to StatusBarController
- SMAppService toggle implementation details
- How to map time ranges to aggregation tiers (1H -> minute_samples, 24H -> hour_samples, 7D -> hour_samples or day_samples, 30D -> day_samples)
- AppDatabase query methods design (static vs instance, async vs sync)
- GRDBQuery @Query usage vs manual database reads for chart data
- Chart axis labels and formatting (time format per range)
- ScrollView behavior if stats cards overflow

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| POP-02 | Popover shows historical bar/area charts with switchable time ranges (hour, day, week, month) | Swift Charts BarMark with grouped bars, time range -> tier mapping, GRDB aggregated queries, chartXSelection for interactivity |
| POP-04 | Popover shows cumulative statistics (total data today, this week, this month) | GRDB SUM queries across interfaces for current day/week/month buckets, ByteCountFormatter or custom formatter for human-readable byte totals |
| SYS-02 | App provides a preferences/settings interface for configuring display options and update interval | @AppStorage with String RawRepresentable enums, Form with Section layout, UserDefaults KVO observation in StatusBarController, SMAppService toggle |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** macOS only, native Swift, no cross-platform frameworks
- **Architecture:** Hybrid AppKit (NSStatusItem, ~20%) + SwiftUI (popover content, ~80%)
- **Data storage:** GRDB.swift 7.10.0 for SQLite, GRDBQuery 0.11.0 available
- **Charts:** Swift Charts (first-party Apple framework, macOS 13+)
- **macOS target:** macOS 13+ minimum (macOS 14 recommended for @Observable)
- **Concurrency:** Swift 6.2 strict concurrency, @MainActor @Observable pattern
- **Colors:** Semantic SwiftUI colors only (.primary, .secondary, .accentColor)
- **Dependencies:** SPM only, no CocoaPods/Carthage
- **Avoid:** SwiftData, Electron, getifaddrs, DispatchSourceTimer

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| Swift Charts | macOS 13+ (Charts framework) | BarMark grouped charts, time-series X axis | First-party, import Charts |
| GRDB.swift | 7.10.0 | Query aggregated tier tables for chart/stats data | Already in SPM, verified |
| GRDBQuery | 0.11.0 | Available but NOT recommended for chart data (see rationale below) | Already in SPM |
| SwiftUI @AppStorage | Built-in | Preferences persistence via UserDefaults | No additional dependency |
| ServiceManagement (SMAppService) | macOS 13+ | Launch-at-login toggle | First-party, import ServiceManagement |

### Why NOT GRDBQuery @Query for Chart Data

GRDBQuery's @Query property wrapper is designed for views that observe a single, long-lived database request -- it re-fetches on every database change. Chart data is fetched on-demand when the user switches time ranges, not continuously observed. Using @Query would cause unnecessary re-fetches when new raw samples are written (every 10 seconds), even though aggregated tier data only changes every 2 minutes.

**Recommendation:** Use direct `AppDatabase.dbWriter.read { }` calls triggered by:
1. Tab selection changing to History
2. Time range picker changing
3. A manual refresh timer (optional, every 2 minutes to match aggregation)

This approach avoids ValueObservation overhead and gives explicit control over when data is fetched.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct GRDB reads | GRDBQuery @Query | @Query auto-refreshes but adds overhead; chart data is infrequently changed |
| Custom byte formatter | ByteCountFormatter | ByteCountFormatter uses "kB" not "KB" and localized strings; custom formatter matches existing SpeedFormatter style |
| @AppStorage enum | Separate UserDefaults wrapper | @AppStorage works directly with String/Int RawRepresentable enums; no wrapper needed |

## Architecture Patterns

### Recommended Project Structure
```
BandwidthMonitor/
  Popover/
    PopoverTab.swift              # MODIFY: Add .history case
    PopoverContentView.swift      # MODIFY: Add History tab routing, update frame height to 550
    PreferencesPlaceholderView.swift  # DELETE: Replaced by PreferencesView
    PreferencesView.swift         # NEW: Full preferences form
    HistoryView.swift             # NEW: History tab container (range picker + chart + stats)
    HistoryChartView.swift        # NEW: Swift Charts bar chart
    CumulativeStatsView.swift     # NEW: Three stats cards row
    StatCardView.swift            # NEW: Individual stat card
  Persistence/
    AppDatabase.swift             # MODIFY: Add query methods for chart/stats data
  MenuBar/
    StatusBarController.swift     # MODIFY: Observe @AppStorage changes via UserDefaults KVO
    SpeedFormatter.swift          # REUSE: For chart tooltip speed formatting
  Monitoring/
    NetworkMonitor.swift          # MODIFY: pollingInterval updated from preferences
  Shared/
    ByteFormatter.swift           # NEW: Format total bytes (not speed) for stats cards
    PreferenceKeys.swift          # NEW: @AppStorage key constants and enum types
```

### Pattern 1: Time Range to Aggregation Tier Mapping
**What:** Each time range maps to a specific aggregation tier and query parameters.
**When to use:** Every chart data fetch.

```swift
// Source: Derived from existing AggregationTier enum + Phase 5 D-04
enum HistoryTimeRange: String, CaseIterable, Sendable {
    case oneHour = "1H"
    case twentyFourHours = "24H"
    case sevenDays = "7D"
    case thirtyDays = "30D"

    /// Which aggregation tier table to query
    var tier: AggregationTier {
        switch self {
        case .oneHour:        return .minute   // ~60 bars (1 per minute)
        case .twentyFourHours: return .hour    // 24 bars (1 per hour)
        case .sevenDays:      return .hour     // ~168 bars -> could use day for 7 bars
        case .thirtyDays:     return .day      // 30 bars (1 per day)
        }
    }

    /// How far back from now to query
    var timeInterval: TimeInterval {
        switch self {
        case .oneHour:        return 3600
        case .twentyFourHours: return 86400
        case .sevenDays:      return 604800
        case .thirtyDays:     return 2_592_000
        }
    }
}
```

**Design note for 7D:** Using `.hour` tier gives 168 data points which is too many bars. Using `.day` tier gives only 7 bars which is clean and readable. **Recommend `.day` for 7D** -- 7 bars showing daily totals is the natural visual for a week view.

### Pattern 2: Aggregated Chart Data Query (Sum Across Interfaces per D-07)
**What:** Query a tier table, sum totalBytesIn and totalBytesOut across all interfaces per bucket.
**When to use:** When fetching chart data for any time range.

```swift
// Source: Based on existing GRDB patterns in AppDatabase + AggregationEngine
extension AppDatabase {
    /// Fetch aggregated chart data for a time range, summing across all interfaces (per D-07).
    /// Returns array of (bucketTimestamp, totalIn, totalOut) sorted by time.
    func fetchChartData(
        tier: AggregationTier,
        since: Date
    ) throws -> [ChartDataPoint] {
        try dbWriter.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT bucketTimestamp,
                       SUM(totalBytesIn) AS totalIn,
                       SUM(totalBytesOut) AS totalOut
                FROM \(tier.tableName)
                WHERE bucketTimestamp >= ?
                GROUP BY bucketTimestamp
                ORDER BY bucketTimestamp ASC
                """,
                arguments: [since.timeIntervalSince1970]
            )
            return rows.map { row in
                ChartDataPoint(
                    timestamp: Date(timeIntervalSince1970: row["bucketTimestamp"]),
                    totalBytesIn: row["totalIn"],
                    totalBytesOut: row["totalOut"]
                )
            }
        }
    }
}
```

### Pattern 3: Grouped BarMark Chart with Download/Upload (D-05, D-06)
**What:** Swift Charts grouped bar chart with two series per bucket.
**When to use:** The History tab chart.

```swift
// Source: Apple Developer Documentation (Charts/BarMark) + avanderlee.com
struct HistoryChartView: View {
    let dataPoints: [ChartDataPoint]
    @State private var selectedTimestamp: Date?

    var body: some View {
        Chart {
            ForEach(dataPoints) { point in
                // Download bar
                BarMark(
                    x: .value("Time", point.timestamp, unit: .hour),
                    y: .value("Bytes", point.totalBytesIn)
                )
                .foregroundStyle(by: .value("Direction", "Download"))
                .position(by: .value("Direction", "Download"))

                // Upload bar
                BarMark(
                    x: .value("Time", point.timestamp, unit: .hour),
                    y: .value("Bytes", point.totalBytesOut)
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
                .position(by: .value("Direction", "Upload"))
            }

            // Selection indicator
            if let selectedTimestamp {
                RuleMark(x: .value("Selected", selectedTimestamp))
                    .foregroundStyle(.primary.opacity(0.3))
                    .annotation(position: .top) {
                        // Tooltip view
                    }
            }
        }
        .chartForegroundStyleScale([
            "Download": Color.accentColor,
            "Upload": Color.secondary
        ])
        .chartXSelection(value: $selectedTimestamp)
    }
}
```

### Pattern 4: @AppStorage with RawRepresentable Enums (D-14)
**What:** Store enum preferences directly in UserDefaults via @AppStorage.
**When to use:** PreferencesView bindings and StatusBarController reading.

```swift
// Source: Apple Developer Documentation (SwiftUI/AppStorage) + hackingwithswift.com
// Enums must have String or Int RawValue for @AppStorage
enum DisplayModePref: String, CaseIterable, Sendable {
    case auto = "auto"
    case both = "both"
    case uploadOnly = "uploadOnly"
    case downloadOnly = "downloadOnly"
}

enum UnitModePref: String, CaseIterable, Sendable {
    case auto = "auto"
    case fixedKB = "fixedKB"
    case fixedMB = "fixedMB"
    case fixedGB = "fixedGB"
}

enum UpdateIntervalPref: Int, CaseIterable, Sendable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5
}

// In PreferencesView:
struct PreferencesView: View {
    @AppStorage("displayMode") private var displayMode: DisplayModePref = .auto
    @AppStorage("unitMode") private var unitMode: UnitModePref = .auto
    @AppStorage("updateInterval") private var updateInterval: UpdateIntervalPref = .twoSeconds
    // SMAppService toggle reads from system, not @AppStorage
}
```

### Pattern 5: UserDefaults KVO Observation in StatusBarController (D-15)
**What:** StatusBarController reads @AppStorage-written preferences via UserDefaults KVO.
**When to use:** Making preferences take effect immediately in menu bar text.

```swift
// Source: fatbobman.com (UserDefaults and Observation in SwiftUI) + Apple docs
// In StatusBarController, replace hardcoded displayMode/unitMode:
private var displayModeObserver: NSKeyValueObservation?
private var unitModeObserver: NSKeyValueObservation?
private var intervalObserver: NSKeyValueObservation?

private func observePreferences() {
    displayModeObserver = UserDefaults.standard.observe(
        \.displayMode,  // requires @objc dynamic property or string key path
        options: [.new]
    ) { [weak self] _, _ in
        Task { @MainActor in
            self?.updateDisplayMode()
            self?.startObserving() // re-render with new mode
        }
    }
}
// Alternative: Use NotificationCenter for UserDefaults.didChangeNotification
// This fires on ANY UserDefaults change but is simpler to implement.
```

**Simpler alternative:** Read from UserDefaults.standard directly in the `startObserving()` method each time it re-registers. Since StatusBarController re-runs `startObserving()` every 2 seconds (on each poll cycle change), it will naturally pick up preference changes within one poll cycle.

### Pattern 6: SMAppService Login Toggle (D-13)
**What:** Toggle launch-at-login with SMAppService.
**When to use:** Preferences "Advanced" section.

```swift
// Source: nilcoalescing.com/blog/LaunchAtLoginSetting/ + Apple docs
import ServiceManagement

// In PreferencesView:
@State private var launchAtLogin = false

Toggle("Launch at login", isOn: $launchAtLogin)
    .onChange(of: launchAtLogin) { _, newValue in
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.lifecycle.error("Failed to toggle login item: \(error.localizedDescription)")
        }
    }
    .onAppear {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
```

**Key insight:** Do NOT store launchAtLogin in @AppStorage. Read from SMAppService.mainApp.status directly, because users can change this in System Settings > Login Items independently of the app.

### Anti-Patterns to Avoid
- **Anti-pattern: GRDBQuery @Query for chart data.** ValueObservation fires on every raw_samples write (every 10 seconds). Chart data from aggregated tiers only changes every 2 minutes. Use direct reads instead.
- **Anti-pattern: Storing SMAppService state in UserDefaults.** The system is the source of truth for login item status. Always read from SMAppService.mainApp.status.
- **Anti-pattern: Creating new DisplayMode/UnitMode types.** The existing `DisplayMode` and `SpeedFormatter.UnitMode` enums already exist but lack String RawValue for @AppStorage. Create new `DisplayModePref`/`UnitModePref` enums with String raw values, with a mapping function to convert to the existing types.
- **Anti-pattern: Passing AppDatabase through SwiftUI Environment for one-shot reads.** The chart data is fetched imperatively when the time range changes. Pass AppDatabase directly to the HistoryView or use a dedicated ViewModel rather than setting up full GRDBQuery environment plumbing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Byte count formatting for stats | Custom division/unit logic | Custom ByteFormatter based on SpeedFormatter pattern OR ByteCountFormatter | SpeedFormatter already handles adaptive precision and unit selection for speed; adapt the same pattern for total bytes. ByteCountFormatter is an option but uses lowercase "kB" and localized strings that may not match the existing style |
| Chart hover/selection | Manual gesture recognizer + coordinate math | Swift Charts `.chartXSelection(value:)` | Built-in since macOS 14, handles coordinate-to-value mapping automatically |
| Login item management | LSSharedFileListItem or launchd plist | SMAppService.mainApp | Modern API, App Store compatible, handles all registration edge cases |
| Preferences persistence | File-based or database-backed settings | UserDefaults via @AppStorage | Native SwiftUI integration, automatic view updates, no serialization needed |

**Key insight:** Swift Charts provides `.chartXSelection(value:)` (macOS 14+) which completely eliminates the need for chartOverlay + onContinuousHover gesture tracking. Since the project targets macOS 14+, use chartXSelection.

## Common Pitfalls

### Pitfall 1: BarMark X-axis Unit Mismatch
**What goes wrong:** Chart bars overlap, stack, or disappear when the `.value("Time", date, unit:)` unit doesn't match the data granularity.
**Why it happens:** If data has hourly buckets but the BarMark uses `unit: .minute`, Swift Charts creates minute-width bars from hourly data, causing visual artifacts.
**How to avoid:** Match the BarMark unit to the time range's tier granularity:
- 1H (minute tier) -> `unit: .minute`
- 24H (hour tier) -> `unit: .hour`
- 7D (day tier) -> `unit: .day`
- 30D (day tier) -> `unit: .day`
**Warning signs:** Bars are paper-thin, overlapping, or the chart looks empty despite data existing.

### Pitfall 2: @AppStorage Enum Without RawRepresentable
**What goes wrong:** Compiler error: "@AppStorage requires a type that conforms to RawRepresentable with RawValue of String or Int."
**Why it happens:** The existing `DisplayMode` and `SpeedFormatter.UnitMode` enums don't have String/Int raw values -- they're plain enums.
**How to avoid:** Create new preference-specific enums with explicit String/Int raw values, plus conversion methods to the existing types.
**Warning signs:** Build fails when adding @AppStorage to existing enum types.

### Pitfall 3: PopoverContentView Frame Height Not Updated
**What goes wrong:** Adding a third tab makes content overflow or clip at the bottom.
**Why it happens:** PopoverContentView currently has `.frame(width: 400, height: 500)` hardcoded. D-02 requires expanding to ~550.
**How to avoid:** Update the frame height in PopoverContentView.swift from 500 to 550. Also update `popover.contentSize` in StatusBarController.swift.
**Warning signs:** Chart or stats cards are clipped at the bottom of the popover.

### Pitfall 4: StatusBarController Not Reacting to Preference Changes
**What goes wrong:** User changes display mode in preferences, but menu bar text doesn't update.
**Why it happens:** StatusBarController currently hardcodes `displayMode: .auto` and `unitMode: .auto`. It has no mechanism to read from UserDefaults.
**How to avoid:** In StatusBarController's `startObserving()` method, read the current preference values from UserDefaults.standard each time before building the text. Since startObserving re-registers on every NetworkMonitor change (every ~2 seconds), preferences will take effect within one poll cycle.
**Warning signs:** Changing preferences in the Preferences tab has no visible effect on the menu bar.

### Pitfall 5: Chart Data Empty Despite Database Having Records
**What goes wrong:** Chart shows "No data yet" even though the app has been running and recording.
**Why it happens:** Aggregation runs every 2 minutes. If the user opens the History tab within the first 2 minutes of app launch, no aggregated tier records exist yet (only raw_samples). The chart queries aggregated tiers, not raw_samples.
**How to avoid:** (1) The empty state message per D-12 handles this gracefully. (2) Optionally trigger an aggregation run when the History tab opens, but this adds complexity. The 2-minute wait is acceptable for v1.
**Warning signs:** Chart is empty on first launch but populates after a few minutes.

### Pitfall 6: UTC vs Local Time for Stats Cards
**What goes wrong:** "Today" card shows wrong total because it queries based on UTC day boundaries, but the user is in a different timezone.
**Why it happens:** All aggregation uses UTC bucketing (per Phase 3 design). "Today" means the current local calendar day, not the current UTC day.
**How to avoid:** For cumulative stats (Today, This Week, This Month), convert the local day/week/month start to UTC epoch before querying. Use Calendar.current.startOfDay(for: .now).timeIntervalSince1970 for "Today."
**Warning signs:** Stats card totals seem too high or too low, especially for users far from UTC.

### Pitfall 7: NetworkMonitor pollingInterval Not Updating
**What goes wrong:** User changes update interval in preferences but polling speed doesn't change.
**Why it happens:** NetworkMonitor.pollingInterval is set once at start. Changing it requires either restarting the monitor or having the polling loop read the interval on each iteration.
**How to avoid:** NetworkMonitor already reads `self.pollingInterval` on each Task.sleep call. Setting `networkMonitor.pollingInterval = .seconds(newValue)` from AppDelegate (observing UserDefaults) will take effect on the next poll cycle.
**Warning signs:** Changing interval in preferences has no visible effect on update frequency.

## Code Examples

### Chart Data Point Model
```swift
// Sendable value type for chart consumption
struct ChartDataPoint: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let totalBytesIn: Double
    let totalBytesOut: Double

    var totalBytes: Double { totalBytesIn + totalBytesOut }
}
```

### Cumulative Stats Query
```swift
// Source: Adapted from existing AggregationEngine SQL patterns
extension AppDatabase {
    /// Fetch cumulative bytes for a period starting at `since`, summed across all interfaces.
    func fetchCumulativeStats(since: Date) throws -> (totalIn: Double, totalOut: Double) {
        try dbWriter.read { db in
            // Query the finest available tier that covers the period
            // For "Today": query hour_samples for completed hours + minute_samples for current hour
            // Simplified: query all tiers and deduplicate, or query the tier that best covers the range
            let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(totalBytesIn), 0) AS totalIn,
                       COALESCE(SUM(totalBytesOut), 0) AS totalOut
                FROM day_samples
                WHERE bucketTimestamp >= ?
                """,
                arguments: [since.timeIntervalSince1970]
            )
            return (
                totalIn: row?["totalIn"] as? Double ?? 0,
                totalOut: row?["totalOut"] as? Double ?? 0
            )
        }
    }
}
```

**Important nuance for "Today" stats:** The day_samples tier may not have the current partial day yet (aggregation cascades: raw -> minute -> hour -> day). For accurate "Today" totals, query hour_samples for today's date range, plus minute_samples for the current partial hour. Or accept that "Today" lags by up to 2 minutes (the aggregation cycle). For v1, querying hour_samples for today is the pragmatic choice.

### Byte Formatter for Stats Cards
```swift
// Source: Adapted from existing SpeedFormatter pattern (MenuBar/SpeedFormatter.swift)
struct ByteFormatter: Sendable {
    /// Format a byte count as a human-readable string (e.g., "1.2 GB", "45.3 MB")
    /// Uses the same adaptive precision as SpeedFormatter (D-10)
    func format(bytes: Double) -> String {
        if bytes < 1_000 {
            return "0 KB"
        } else if bytes < 1_000_000 {
            let value = bytes / 1_000
            return "\(formatValue(value)) KB"
        } else if bytes < 1_000_000_000 {
            let value = bytes / 1_000_000
            return "\(formatValue(value)) MB"
        } else {
            let value = bytes / 1_000_000_000
            return "\(formatValue(value)) GB"
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
```

### Preference Keys Constants
```swift
// Centralized @AppStorage key constants
enum PreferenceKey {
    static let displayMode = "displayMode"
    static let unitMode = "unitMode"
    static let updateInterval = "updateInterval"
    // launchAtLogin is NOT stored in UserDefaults -- read from SMAppService
}
```

### StatusBarController Preference Reading
```swift
// Replace hardcoded displayMode/unitMode in startObserving():
private func startObserving() {
    withObservationTracking {
        let speed = self.networkMonitor.aggregateSpeed
        let hasInterfaces = !self.networkMonitor.interfaceSpeeds.isEmpty

        // Read current preferences from UserDefaults
        let displayModePref = DisplayModePref(
            rawValue: UserDefaults.standard.string(forKey: PreferenceKey.displayMode) ?? "auto"
        ) ?? .auto
        let unitModePref = UnitModePref(
            rawValue: UserDefaults.standard.string(forKey: PreferenceKey.unitMode) ?? "auto"
        ) ?? .auto

        let text = self.textBuilder.build(
            speed: speed,
            mode: displayModePref.toDisplayMode(),
            unit: unitModePref.toUnitMode(),
            hasInterfaces: hasInterfaces
        )

        self.updateStatusItemText(text: text)
    } onChange: {
        Task { @MainActor [weak self] in
            self?.startObserving()
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| chartOverlay + onContinuousHover for selection | `.chartXSelection(value:)` modifier | macOS 14 / WWDC 2023 | Single line replaces 15+ lines of coordinate translation code |
| SMLoginItemSetEnabled | SMAppService.mainApp.register() | macOS 13 / 2022 | Modern API, no helper bundle needed, App Store safe |
| ObservableObject + @Published | @Observable macro | macOS 14 / Swift 5.9 | Already used in this project (NetworkMonitor) |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled`: Deprecated in macOS 13. Use SMAppService.
- `chartOverlay` for selection: Still works but unnecessarily complex vs chartXSelection on macOS 14+.
- `@ObservedObject`/`@StateObject`: Replaced by @Observable macro in this project.

## Open Questions

1. **Cumulative stats accuracy for partial periods**
   - What we know: Aggregation cascades every 2 minutes (raw -> minute -> hour -> day). "Today" may miss up to 2 minutes of data if queried from day_samples.
   - What's unclear: Whether to query hour_samples (more current, slightly more rows) or day_samples (simpler but potentially stale for current day) for the "Today" card.
   - Recommendation: Query the finest available tier for "Today" (hour_samples) and day_samples for "This Week" and "This Month". The lag is acceptable for v1.

2. **Chart X-axis label formatting per time range**
   - What we know: 1H needs "10:05", 24H needs "10 AM", 7D needs "Mon", 30D needs "Mar 1".
   - What's unclear: Whether Swift Charts auto-formats Date x-axis labels appropriately for each range, or if custom axis content is needed.
   - Recommendation: Start with default Date axis formatting. If labels are poor, add `.chartXAxis { AxisMarks(values: .automatic) { AxisValueLabel(format:) } }` with custom DateFormatStyle per range.

3. **AppDatabase thread safety for chart reads**
   - What we know: AppDatabase uses DatabasePool (WAL mode), which supports concurrent reads and writes. Chart reads happen on the main thread (from SwiftUI views).
   - What's unclear: Whether to dispatch chart data fetches to a background thread to avoid main-thread blocking.
   - Recommendation: For v1, synchronous reads on main thread are fine -- the aggregated tier tables are small (at most ~720 rows for hour_samples over 30 days). If performance is an issue, wrap in Task { }.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | BandwidthMonitor.xcodeproj (test target: BandwidthMonitorTests) |
| Quick run command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -only-testing:BandwidthMonitorTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' 2>&1 \| tail -30` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| POP-02 | Chart data query returns correct aggregated data by time range | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/AppDatabaseTests/testFetchChartData` | Wave 0 |
| POP-02 | HistoryTimeRange maps to correct tier and interval | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/HistoryViewTests/testTimeRangeTierMapping` | Wave 0 |
| POP-04 | Cumulative stats query returns summed bytes for today/week/month | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/AppDatabaseTests/testFetchCumulativeStats` | Wave 0 |
| POP-04 | ByteFormatter formats bytes with adaptive precision | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/ByteFormatterTests/testFormat` | Wave 0 |
| SYS-02 | DisplayModePref/UnitModePref enum raw values roundtrip | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/PreferencesTests/testEnumRoundtrip` | Wave 0 |
| SYS-02 | Preference enums convert correctly to existing DisplayMode/UnitMode types | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/PreferencesTests/testEnumConversion` | Wave 0 |
| POP-02 | PopoverTab.history case exists with correct raw value | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/PopoverTests/testPopoverTab_historyRawValue` | Wave 0 |

### Sampling Rate
- **Per task commit:** Quick run of phase-specific test files
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before /gsd:verify-work

### Wave 0 Gaps
- [ ] `BandwidthMonitorTests/ByteFormatterTests.swift` -- covers POP-04 byte formatting
- [ ] `BandwidthMonitorTests/PreferencesTests.swift` -- covers SYS-02 enum roundtrip and conversion
- [ ] `BandwidthMonitorTests/HistoryViewTests.swift` -- covers POP-02 time range mapping
- [ ] Add `testFetchChartData` and `testFetchCumulativeStats` to existing `AppDatabaseTests.swift` -- covers POP-02 and POP-04 data layer

## Sources

### Primary (HIGH confidence)
- [Apple Developer: BarMark](https://developer.apple.com/documentation/charts/barmark) -- BarMark API, position(by:), foregroundStyle(by:)
- [Apple Developer: chartXSelection](https://developer.apple.com/documentation/swiftui/view/chartxselection(value:)) -- Selection modifier for interactive charts
- [Apple Developer: AppStorage](https://developer.apple.com/documentation/swiftui/appstorage) -- @AppStorage property wrapper documentation
- [Apple Developer: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) -- Login item API

### Secondary (MEDIUM confidence)
- [SwiftLee: Bar Chart creation using Swift Charts](https://www.avanderlee.com/swift-charts/bar-chart-creation-using-swift-charts/) -- Grouped BarMark with .position(by:) example, verified against Apple docs
- [nilcoalescing: Chart Annotations on Hover](https://nilcoalescing.com/blog/ChartAnnotationsOnHover/) -- macOS hover annotation pattern with chartOverlay
- [nilcoalescing: Launch at Login Setting](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) -- SMAppService toggle pattern for SwiftUI
- [Swift with Majid: Mastering Charts - Selection](https://swiftwithmajid.com/2023/07/18/mastering-charts-in-swiftui-selection/) -- chartXSelection and RuleMark annotation pattern
- [GRDBQuery GitHub](https://github.com/groue/GRDBQuery) -- Queryable protocol, @Query property wrapper
- [Hacking with Swift: @AppStorage](https://www.hackingwithswift.com/quick-start/swiftui/what-is-the-appstorage-property-wrapper) -- @AppStorage with enum RawRepresentable
- [Fat Bob Man: UserDefaults and Observation](https://fatbobman.com/en/posts/userdefaults-and-observation/) -- UserDefaults KVO patterns for non-SwiftUI consumers
- [Fat Bob Man: @AppStorage](https://fatbobman.com/en/posts/appstorage/) -- @AppStorage with custom types

### Tertiary (LOW confidence)
- None -- all findings verified against primary or secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All technologies (Swift Charts, GRDB, @AppStorage, SMAppService) are already in use or first-party Apple frameworks with stable APIs
- Architecture: HIGH -- Patterns directly extend existing codebase patterns (PopoverTab, AppDatabase queries, SpeedFormatter style)
- Pitfalls: HIGH -- Identified from direct code inspection of existing codebase (hardcoded values in StatusBarController, frame sizes in PopoverContentView, UTC bucketing in AggregationEngine)
- Chart patterns: MEDIUM -- Swift Charts grouped BarMark with .position(by:) verified across multiple sources; chartXSelection macOS behavior confirmed but not tested in this exact codebase

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (30 days -- stable frameworks, no breaking changes expected)
