# Phase 9: Chart Fixes & Layout Polish - Research

**Researched:** 2026-03-24
**Domain:** Swift Charts axis customization, y-axis stability, x-axis date formatting, byte value formatting
**Confidence:** HIGH

## Summary

This phase fixes five specific chart and layout issues in the existing `HistoryChartView` and `StatCardView`/`CumulativeStatsView`. The codebase already has a working grouped bar chart with `BarMark`, `chartXSelection`, tooltip annotations, and `ByteFormatter`. The changes are surgical: (1) lock the y-axis domain to prevent reflow on hover/selection, (2) customize x-axis labels for 7D and 30D views using `AxisMarks` with date formatting, (3) add human-readable y-axis labels using a custom `AxisMarks` closure, and (4) verify stat card layout (likely already fixed by Phase 8's panel resize to 480x650).

All required APIs (`chartYScale(domain:)`, `AxisMarks(values:)`, `AxisValueLabel` with custom closures) are stable Swift Charts APIs available on macOS 13+. No new dependencies are needed. The existing `ByteFormatter` can be extended or a parallel `ChartAxisFormatter` helper created for axis-specific formatting (same unit for all ticks, round numbers).

**Primary recommendation:** Fix y-axis stability first (CHRT-01) since it is the prerequisite for all other chart work -- a stable axis domain is needed before customizing axis labels.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **CHRT-01 (Chart hover stability):** Fix `.chartYScale(domain:)` to pre-computed max value from visible data points. Add ~10% headroom above max value. Keep current RuleMark + tooltip interaction style.
- **CHRT-02 (7D view axis labels):** X-axis labels use short date format (3/18, 3/19, 3/20...) -- NOT day-of-week abbreviations. One bar per day, exactly 7 data points.
- **CHRT-03 (30D view axis labels):** Show every 5th day label with short date format ("Mar 1", "Mar 5"...). One bar per day, 30 data points.
- **CHRT-04 (Y-axis formatting):** Auto-scale: pick one unit for entire axis based on max value (all KB, all MB, or all GB). Show unit suffix in labels. 4-5 ticks with round numbers (e.g., 0, 25, 50, 75, 100 MB).
- **LYOT-01 (Stat card layout):** Verify-only first. Stat cards already look good after Phase 8 panel resize to 480x650. If edge case found, apply `.lineLimit(1)` + `.minimumScaleFactor(0.7)` as safety net. No proactive code change.

### Claude's Discretion
- Exact round-number tick calculation algorithm for y-axis
- Whether to use `.chartXAxis` modifier or custom `AxisMarks` for label formatting
- Internal implementation of the auto-scale unit picker (thresholds for KB to MB to GB transition)
- How to ensure exactly 7 or 30 data points are returned from the database query

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHRT-01 | User can hover/select a chart bar without the y-axis shifting or the chart compressing | Use `.chartYScale(domain: 0...maxWithHeadroom)` with pre-computed max. See Architecture Pattern 1. |
| CHRT-02 | User sees one bar per day with short date labels (3/18, 3/19) in the 7D view | Use `.chartXAxis` with `AxisMarks(values: .stride(by: .day))` and custom `DateFormatter`. See Architecture Pattern 2. |
| CHRT-03 | User sees one bar per day with readable date labels in the 30D view | Use `.chartXAxis` with `AxisMarks(values: .stride(by: .day, count: 5))` and `DateFormatter`. See Architecture Pattern 2. |
| CHRT-04 | User sees human-readable y-axis labels (auto-scaled KB/MB/GB) instead of raw bytes | Use `.chartYAxis` with `AxisMarks` and custom `AxisValueLabel` closure using `ChartAxisFormatter`. See Architecture Pattern 3. |
| LYOT-01 | User sees stat card text fully visible without truncation or wrapping | Verify existing layout at 480x650 panel width. Apply `.lineLimit(1)` + `.minimumScaleFactor(0.7)` only if edge case found. See Architecture Pattern 4. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** macOS only, native Swift, no cross-platform frameworks
- **Target:** macOS 13+ (for Swift Charts and modern SwiftUI APIs)
- **Architecture:** Hybrid AppKit + SwiftUI -- AppKit for status item, SwiftUI for all views
- **Charts:** Use Swift Charts (first-party Apple framework), not third-party
- **Database:** GRDB.swift 7.10.0 for SQLite access
- **Concurrency:** Use structured concurrency (`Task.sleep`, async/await), not GCD
- **Dependencies:** Swift Package Manager only, no CocoaPods/Carthage
- **GSD Workflow:** Must use GSD commands for all file changes

## Standard Stack

No new dependencies needed. This phase modifies existing views using APIs already available.

### Core (already in project)
| Library/Framework | Version | Purpose | Status |
|-------------------|---------|---------|--------|
| Swift Charts | macOS 13+ | Bar charts, axis customization | Already imported in HistoryChartView.swift |
| SwiftUI | macOS 13+ | View modifiers, layout | Already used throughout |
| GRDB.swift | 7.10.0 | Database queries for chart data | Already used in AppDatabase.swift |

### Key APIs Used in This Phase
| API | Framework | Purpose |
|-----|-----------|---------|
| `.chartYScale(domain:)` | Charts | Lock y-axis range to prevent reflow on selection |
| `.chartXAxis { AxisMarks }` | Charts | Custom x-axis label formatting per time range |
| `.chartYAxis { AxisMarks }` | Charts | Custom y-axis labels with human-readable byte units |
| `AxisMarks(values: .stride(by:count:))` | Charts | Control which axis values get labels |
| `AxisValueLabel { }` | Charts | Custom label content with formatted text |
| `.lineLimit(1)` + `.minimumScaleFactor()` | SwiftUI | Safety net for stat card text truncation |

## Architecture Patterns

### Recommended Modifications

```
BandwidthMonitor/
  Popover/
    HistoryChartView.swift      # PRIMARY: Add chartYScale, chartXAxis, chartYAxis modifiers
    StatCardView.swift          # VERIFY: Check truncation at large values, add safety net if needed
    CumulativeStatsView.swift   # NO CHANGE expected
    DashboardView.swift         # MINOR: May need to adjust data loading for exact 7/30 data points
  Shared/
    ChartAxisFormatter.swift    # NEW: Helper for y-axis unit selection and round-number tick calculation
    ByteFormatter.swift         # NO CHANGE: Existing formatter for tooltips/stat cards
    HistoryTimeRange.swift      # NO CHANGE: Already has correct calendarUnit mapping
  Persistence/
    AppDatabase.swift           # POSSIBLE: Adjust fetchChartData to ensure exact data point counts
```

### Pattern 1: Fixed Y-Axis Domain (CHRT-01)

**What:** Pre-compute the max value from visible data points, add 10% headroom, and lock the y-axis scale using `.chartYScale(domain:)`. This prevents the chart from reflowing when RuleMark annotations or tooltips appear during hover/selection.

**When to use:** Always -- apply to every chart render, not just on selection.

**Example:**
```swift
// Source: Apple Developer Documentation - chartYScale(domain:range:type:)
// + verified via multiple community sources

private var yAxisMax: Double {
    let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
    return maxValue * 1.1  // 10% headroom
}

var body: some View {
    Chart {
        // ... existing BarMark + RuleMark content ...
    }
    .chartYScale(domain: 0...yAxisMax)
    .chartForegroundStyleScale([...])
    .chartXSelection(value: $selectedTimestamp)
}
```

**Why this works:** Without `.chartYScale(domain:)`, Swift Charts auto-computes the y-axis range on every render. When a RuleMark annotation appears (tooltip on hover), it can change the layout geometry, causing the chart to recompute and the y-axis to shift. By locking the domain, the axis stays fixed regardless of what overlays appear.

**Edge case:** When `dataPoints` is empty, `yAxisMax` would be 0. Use a minimum floor (e.g., `max(yAxisMax, 1024)`) to avoid a degenerate 0...0 range.

### Pattern 2: Custom X-Axis Labels per Time Range (CHRT-02, CHRT-03)

**What:** Use `.chartXAxis` with `AxisMarks` to control which x-axis labels appear and how dates are formatted. Different time ranges need different formatting.

**When to use:** Always -- the x-axis formatting depends on `timeRange`.

**Example:**
```swift
// Source: Swift Charts documentation, AxisMarks(values: .stride(by:count:))
// Verified via multiple community implementations

private var xAxisMarks: some View {
    switch timeRange {
    case .oneHour:
        // Default: auto marks, show "h:mm a" format
        return AnyView(chart.chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 15)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        })
    case .twentyFourHours:
        // Default: auto marks, show "h a" format
        return AnyView(chart.chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        })
    case .sevenDays:
        // Every day, short numeric date (3/18, 3/19...)
        return AnyView(chart.chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(shortDateString(date))  // "3/18" format
                    }
                }
            }
        })
    case .thirtyDays:
        // Every 5th day, "Mar 1" format
        return AnyView(chart.chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(mediumDateString(date))  // "Mar 1" format
                    }
                }
            }
        })
    }
}

// Helper: "3/18" format
private func shortDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d"
    return formatter.string(from: date)
}

// Helper: "Mar 1" format
private func mediumDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}
```

**Implementation note:** Rather than wrapping in AnyView with a switch, a cleaner approach is to use a `@ViewBuilder` computed property or apply the `.chartXAxis` modifier conditionally inside the chart body. The planner should choose the cleanest approach -- likely a computed `chartXAxisContent` property that returns `some AxisContent`.

### Pattern 3: Human-Readable Y-Axis Labels (CHRT-04)

**What:** Create a `ChartAxisFormatter` that picks a single unit (KB, MB, or GB) based on the max value in the dataset, then formats all y-axis tick labels using that unit. Calculate round-number tick values.

**When to use:** Always -- raw byte values on the y-axis are unreadable.

**Example:**
```swift
// Source: Training data + verified API patterns from community sources

/// Selects one unit for the entire y-axis based on max bytes value.
struct ChartAxisFormatter {
    enum ByteUnit: String {
        case KB, MB, GB

        var divisor: Double {
            switch self {
            case .KB: return 1_000
            case .MB: return 1_000_000
            case .GB: return 1_000_000_000
            }
        }
    }

    /// Select unit based on max value -- same unit for all ticks.
    static func selectUnit(forMax maxBytes: Double) -> ByteUnit {
        if maxBytes >= 1_000_000_000 { return .GB }
        if maxBytes >= 1_000_000 { return .MB }
        return .KB
    }

    /// Calculate nice round tick values for the y-axis.
    /// Returns 4-5 values including 0 and the ceiling.
    static func niceTickValues(maxBytes: Double, unit: ByteUnit) -> [Double] {
        let maxInUnit = maxBytes / unit.divisor
        let niceMax = ceilToNice(maxInUnit)
        let step = niceMax / 4.0  // 5 ticks: 0, step, 2*step, 3*step, 4*step
        return stride(from: 0, through: niceMax * unit.divisor, by: step * unit.divisor).map { $0 }
    }

    /// Rounds up to a "nice" number (1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500...)
    private static func ceilToNice(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let exponent = floor(log10(value))
        let fraction = value / pow(10, exponent)
        let niceFraction: Double
        if fraction <= 1.0 { niceFraction = 1.0 }
        else if fraction <= 2.0 { niceFraction = 2.0 }
        else if fraction <= 2.5 { niceFraction = 2.5 }
        else if fraction <= 5.0 { niceFraction = 5.0 }
        else { niceFraction = 10.0 }
        return niceFraction * pow(10, exponent)
    }

    /// Format a byte value using the given unit.
    static func formatTick(_ bytes: Double, unit: ByteUnit) -> String {
        let value = bytes / unit.divisor
        if value == 0 { return "0" }
        if value >= 100 { return String(format: "%.0f", value) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}

// Usage in HistoryChartView:
private var yAxisUnit: ChartAxisFormatter.ByteUnit {
    let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
    return ChartAxisFormatter.selectUnit(forMax: maxValue)
}

// In chart body:
.chartYAxis {
    let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
    let unit = ChartAxisFormatter.selectUnit(forMax: maxValue)
    let ticks = ChartAxisFormatter.niceTickValues(maxBytes: maxValue * 1.1, unit: unit)
    AxisMarks(values: ticks) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
            if let bytes = value.as(Double.self) {
                Text("\(ChartAxisFormatter.formatTick(bytes, unit: unit)) \(unit.rawValue)")
            }
        }
    }
}
```

**Key insight:** The unit suffix should appear on each tick label (e.g., "25 MB", "50 MB", "75 MB") per user decision. The thresholds for KB/MB/GB transition match the existing `ByteFormatter.selectUnit()` thresholds (1,000 and 1,000,000,000) so behavior is consistent across tooltips and axis labels.

### Pattern 4: Stat Card Layout Verification (LYOT-01)

**What:** Phase 8 resized the panel to 480x650. At this width, three `StatCardView` cards in an `HStack` have ~150pt each (480 - 16*2 horizontal padding - 8*2 spacing = 432pt / 3 = 144pt per card). This should be sufficient for most byte values.

**When to verify:** Check with extreme values like "999 GB" (7 characters + unit) in the primary `.title3.semibold` text, and "999 GB" in both download/upload `.caption2` breakdown text.

**Safety net (apply only if truncation found):**
```swift
// In StatCardView body:
Text(formatter.format(bytes: totalBytes))
    .font(.title3)
    .fontWeight(.semibold)
    .lineLimit(1)
    .minimumScaleFactor(0.7)
```

### Anti-Patterns to Avoid

- **Computing yAxisMax inside the Chart closure:** This can cause infinite re-renders. Compute it as a separate property outside the Chart builder.
- **Using `AnyView` type erasure for conditional axis content:** Use `@ViewBuilder` or apply modifiers conditionally instead.
- **Recreating DateFormatter on every render:** DateFormatter allocation is expensive. Store formatters as static or instance properties.
- **Using `.automatic` AxisMarks values for 30D view:** This will show too many or too few labels. Use explicit `.stride(by: .day, count: 5)`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Y-axis locking | Manual axis drawing or overlay hacks | `.chartYScale(domain:)` | First-party API, one line, handles all edge cases |
| Date label formatting | Manual x-position calculation | `AxisMarks(values: .stride(by:count:))` | Framework handles date math, DST transitions, positioning |
| "Nice number" rounding | Complex multi-pass algorithm | Simple ceil-to-nice function (1, 2, 2.5, 5, 10 series) | The Graphics Gems algorithm is overkill; 4-5 ticks with round numbers only needs basic rounding |
| Axis label placement | Absolute positioning or spacers | `AxisValueLabel` inside `AxisMarks` closure | Framework positions labels correctly relative to axis |

**Key insight:** Swift Charts provides all the axis customization APIs needed. The only custom code is the byte unit selection and nice-number calculation, which are simple pure functions.

## Common Pitfalls

### Pitfall 1: Y-Axis Domain of 0...0 When Data is Empty
**What goes wrong:** If `dataPoints` is empty, `max()` returns nil, and using `0...0` as the domain crashes or produces a degenerate chart.
**Why it happens:** Edge case when no data has been recorded yet.
**How to avoid:** Guard with `max(computedMax, 1024)` (1 KB minimum) so the domain is always valid.
**Warning signs:** Chart disappears or crashes when switching to a time range with no data.

### Pitfall 2: DateFormatter Allocation in Render Loop
**What goes wrong:** Creating a new `DateFormatter` inside `AxisMarks` closure runs for every axis tick on every render, causing CPU spikes.
**Why it happens:** `DateFormatter` is expensive to initialize.
**How to avoid:** Use static/lazy formatter instances or use `.dateTime` format style (which is value-type and cheap).
**Warning signs:** Instruments shows DateFormatter allocation hotspot in HistoryChartView.

### Pitfall 3: Inconsistent Unit Between Y-Axis Labels and Tooltip
**What goes wrong:** Y-axis shows "25 MB" but tooltip shows "25,000 KB" because they use different formatters.
**Why it happens:** ByteFormatter (tooltip) auto-selects unit per value; ChartAxisFormatter (axis) selects one unit for all ticks.
**How to avoid:** This is intentional -- the tooltip uses per-value formatting for precision, the axis uses uniform unit for readability. Document this as expected behavior.
**Warning signs:** User confusion about different units on same chart.

### Pitfall 4: 7D/30D Data Point Count Mismatch
**What goes wrong:** Database returns fewer than 7 or 30 data points if the app hasn't been running long enough.
**Why it happens:** `fetchChartData` uses `WHERE bucketTimestamp >= ?` which only returns existing records.
**How to avoid:** This is acceptable -- the chart simply shows fewer bars for days without data. Do NOT pad with zero-value data points, as that would mislead the user into thinking they had zero bandwidth on days the app wasn't running.
**Warning signs:** Fewer bars than expected in 7D/30D view.

### Pitfall 5: AxisMarks Closure Cannot Contain Complex Logic
**What goes wrong:** Putting `let` bindings or complex computations inside `AxisMarks { value in ... }` causes compiler errors because it is a result builder context.
**Why it happens:** `AxisContent` result builders only accept specific view-like types.
**How to avoid:** Compute tick values, units, and formatters OUTSIDE the `AxisMarks` closure. Pass pre-computed values into the closure by referencing properties.
**Warning signs:** "Cannot convert value of type..." compiler errors inside AxisMarks.

### Pitfall 6: chartYScale Domain Must Use Raw Byte Values
**What goes wrong:** If you set `chartYScale(domain: 0...100)` thinking in MB, but your BarMark y-values are in raw bytes (100,000,000), the bars extend way beyond the chart.
**Why it happens:** The domain must match the unit of the data in BarMark y-values.
**How to avoid:** Keep BarMark y-values in raw bytes. Set `chartYScale(domain: 0...maxRawBytes)`. Format only the LABELS using the unit conversion.
**Warning signs:** Bars extend far beyond the chart area or are invisible.

## Code Examples

### Complete HistoryChartView Pattern (Target State)

```swift
// Source: Synthesized from Apple documentation patterns + existing codebase

struct HistoryChartView: View {
    let dataPoints: [ChartDataPoint]
    let timeRange: HistoryTimeRange

    @State private var selectedTimestamp: Date?

    private let formatter = ByteFormatter()

    // CHRT-01: Pre-computed max for stable y-axis
    private var yAxisMax: Double {
        let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
        return max(maxValue * 1.1, 1024)  // 10% headroom, 1KB minimum
    }

    // CHRT-04: Unit for all y-axis labels
    private var yAxisUnit: ChartAxisFormatter.ByteUnit {
        let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
        return ChartAxisFormatter.selectUnit(forMax: maxValue)
    }

    // CHRT-04: Pre-computed tick values
    private var yAxisTicks: [Double] {
        ChartAxisFormatter.niceTickValues(maxBytes: yAxisMax, unit: yAxisUnit)
    }

    var body: some View {
        ZStack {
            Chart {
                ForEach(dataPoints) { point in
                    BarMark(
                        x: .value("Time", point.timestamp, unit: timeRange.calendarUnit),
                        y: .value("Bytes", point.totalBytesIn)
                    )
                    .foregroundStyle(by: .value("Direction", "Download"))
                    .position(by: .value("Direction", "Download"))

                    BarMark(
                        x: .value("Time", point.timestamp, unit: timeRange.calendarUnit),
                        y: .value("Bytes", point.totalBytesOut)
                    )
                    .foregroundStyle(by: .value("Direction", "Upload"))
                    .position(by: .value("Direction", "Upload"))
                }

                if let selectedTimestamp, let closest = closestPoint(to: selectedTimestamp) {
                    RuleMark(x: .value("Selected", closest.timestamp, unit: timeRange.calendarUnit))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .annotation(position: .top, alignment: .center) {
                            tooltipView(for: closest)
                        }
                }
            }
            .chartYScale(domain: 0...yAxisMax)  // CHRT-01: Locked y-axis
            .chartYAxis {                         // CHRT-04: Human-readable labels
                AxisMarks(values: yAxisTicks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text("\(ChartAxisFormatter.formatTick(bytes, unit: yAxisUnit)) \(yAxisUnit.rawValue)")
                        }
                    }
                }
            }
            .chartXAxis { xAxisContent }          // CHRT-02, CHRT-03: Per-range labels
            .chartForegroundStyleScale([
                "Download": Color.accentColor,
                "Upload": Color.secondary.opacity(0.7)
            ])
            .chartXSelection(value: $selectedTimestamp)
            .frame(height: 200)

            if dataPoints.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    // CHRT-02, CHRT-03: X-axis configuration per time range
    @AxisContentBuilder
    private var xAxisContent: some AxisContent {
        switch timeRange {
        case .oneHour:
            AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        case .twentyFourHours:
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        case .sevenDays:
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.shortDateFormatter.string(from: date))
                    }
                }
            }
        case .thirtyDays:
            AxisMarks(values: .stride(by: .day, count: 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Self.mediumDateFormatter.string(from: date))
                    }
                }
            }
        }
    }

    // Static formatters to avoid repeated allocation (Pitfall 2)
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"  // "3/18" format per user decision
        return f
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"  // "Mar 1" format per user decision
        return f
    }()

    // ... existing tooltipView, closestPoint, formatTimestamp methods unchanged ...
}
```

**Note on `@AxisContentBuilder`:** This result builder may not exist as a public API. If the compiler rejects this, the alternative is to apply `.chartXAxis` conditionally using a helper method that returns `some View` (the chart with the appropriate modifier applied). The planner should verify this compiles and fall back to the conditional-modifier pattern if needed.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Auto y-axis scaling (current code) | `.chartYScale(domain:)` with pre-computed max | Available since macOS 13 / iOS 16 | Prevents selection-induced reflow |
| Default axis labels (current code) | Custom `AxisMarks` with formatted labels | Available since macOS 13 / iOS 16 | Human-readable units on axes |
| `chartXSelection` without fixed domain | `chartXSelection` + fixed y-domain | Pattern established in community | Stable interactive charts |

## Open Questions

1. **`@AxisContentBuilder` availability**
   - What we know: `AxisMarks` works inside `.chartXAxis { }` closures. The closure is an `AxisContent` result builder.
   - What's unclear: Whether `switch` statements work directly in the `AxisContent` builder, or if a workaround is needed.
   - Recommendation: Try the switch approach first. If it fails, extract into separate computed properties per time range and apply `.chartXAxis` conditionally.

2. **Data point count for 7D/30D**
   - What we know: `fetchChartData(tier: .day, since:)` returns all day_samples in the range. If the app has been running for less than 7 days, fewer than 7 data points are returned.
   - What's unclear: Whether the chart looks odd with, say, 3 bars in a "7D" view.
   - Recommendation: This is acceptable behavior -- do not pad with zeros. The chart shows actual data. If the app has only 3 days of data, 3 bars is correct.

3. **Tick label width affecting chart area**
   - What we know: Longer y-axis labels (e.g., "100 MB" vs "0") take more horizontal space, which can compress the chart drawing area.
   - What's unclear: Whether this causes visible compression when switching between time ranges with different data magnitudes.
   - Recommendation: Use `AxisMarks(position: .leading)` to keep labels consistently placed. The fixed tick count (4-5) means label width is predictable.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in, via Xcode) |
| Config file | BandwidthMonitor.xcodeproj (Xcode project, BandwidthMonitorTests target) |
| Quick run command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -quiet 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHRT-01 | Y-axis domain locked to pre-computed max with 10% headroom | unit | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/ChartAxisFormatterTests -quiet` | Wave 0 |
| CHRT-02 | 7D x-axis shows short date format per day | manual-only | Visual verification in running app | N/A |
| CHRT-03 | 30D x-axis shows every-5th-day labels | manual-only | Visual verification in running app | N/A |
| CHRT-04 | Y-axis labels show auto-scaled KB/MB/GB with round ticks | unit | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/ChartAxisFormatterTests -quiet` | Wave 0 |
| LYOT-01 | Stat card text not truncated | manual-only | Visual verification in running app | N/A |

**Justification for manual-only tests:** CHRT-02, CHRT-03, and LYOT-01 are visual rendering properties of SwiftUI views. Swift Charts axis label rendering cannot be unit tested -- it requires visual inspection of the rendered chart. The underlying data formatting CAN be unit tested (and is, via ChartAxisFormatterTests).

### Sampling Rate
- **Per task commit:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -quiet 2>&1 | tail -20`
- **Per wave merge:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `BandwidthMonitorTests/ChartAxisFormatterTests.swift` -- covers CHRT-01 (y-axis max calculation) and CHRT-04 (unit selection, nice tick values, tick formatting)
- [ ] No shared fixtures needed -- ChartAxisFormatter is a pure struct with static methods

## Sources

### Primary (HIGH confidence)
- [Apple Developer: chartYScale(domain:range:type:)](https://developer.apple.com/documentation/swiftui/view/chartyscale(domain:range:type:)) -- Official API reference for locking y-axis domain
- [Apple Developer: Customizing axes in Swift Charts](https://developer.apple.com/documentation/charts/customizing-axes-in-swift-charts) -- Official guide for AxisMarks, AxisValueLabel, AxisTick, AxisGridLine
- [Apple Developer: Swift Charts](https://developer.apple.com/documentation/Charts) -- Framework reference
- Existing codebase: `HistoryChartView.swift`, `ByteFormatter.swift`, `ChartDataPoint.swift`, `HistoryTimeRange.swift`

### Secondary (MEDIUM confidence)
- [Mastering charts in SwiftUI: Customizations (Swift with Majid)](https://swiftwithmajid.com/2023/02/15/mastering-charts-in-swiftui-customizations/) -- AxisMarks patterns with stride and custom labels
- [Mastering charts in SwiftUI: Selection (Swift with Majid)](https://swiftwithmajid.com/2023/07/18/mastering-charts-in-swiftui-selection/) -- chartXSelection patterns
- [Swift Charts comprehensive guide (mvolkmann)](https://mvolkmann.github.io/blog/swift/SwiftCharts/?v=1.1.1) -- chartYScale domain examples, AxisMarks custom formatting
- [Apple Developer Forums: chartYScale domain issue](https://developer.apple.com/forums/thread/709119) -- BarMark + chartYScale domain interaction

### Tertiary (LOW confidence)
- Nice-number algorithm from Graphics Gems (Glassner, 1990) -- referenced in community for tick calculation; our simplified version uses 1/2/2.5/5/10 series

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all APIs are first-party Swift Charts, available on macOS 13+, well-documented
- Architecture: HIGH -- patterns are well-established in community, verified against Apple docs
- Pitfalls: HIGH -- based on direct code review of existing codebase and known Swift Charts behaviors
- Nice-number algorithm: MEDIUM -- simplified version based on established algorithm, but not tested against all edge cases yet

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable APIs, unlikely to change)
