---
phase: 09-chart-fixes-layout-polish
verified: 2026-03-24T18:30:00Z
status: human_needed
score: 7/7 must-haves verified
re_verification: false
human_verification:
  - test: "Open the app, switch to 7D time range, verify x-axis labels show numeric dates like '3/18' (M/d format), NOT day-of-week names like 'Mon'"
    expected: "Each bar has a short numeric date label (M/d format). REQUIREMENTS.md says 'Mon, Tue, etc.' but the plan documents a user decision to use numeric dates instead. Human confirmation of the accepted format is needed."
    why_human: "CHRT-02 wording in REQUIREMENTS.md says 'day labels (Mon, Tue, etc.)' but implementation uses M/d numeric format. The plan explicitly cites 'per user decision: short numeric date, NOT day-of-week'. A human should confirm the approved format to resolve the requirements text discrepancy."
  - test: "Open the app, hover or click different bars in 24H, 7D, and 30D chart views"
    expected: "Y-axis labels (KB/MB/GB with tick values) remain completely static — no shifting, reflowing, or rescaling during interaction"
    why_human: "chartYScale(domain: 0...yAxisMax) locks the domain programmatically but Swift Charts rendering behavior during selection animations can only be verified by visual inspection of the live app"
  - test: "Open the app with a fresh database and with an existing database containing data approaching 999 GB total"
    expected: "Stat card primary text (Today / This Week / This Month) is fully visible without overflow or wrapping at extreme byte values"
    why_human: "lineLimit(1) + minimumScaleFactor(0.7) safety net is code-verified but actual rendering at extreme values (e.g. '999 GB', '1.2 TB') requires a live visual check with real data or a SwiftUI preview"
---

# Phase 9: Chart Fixes & Layout Polish Verification Report

**Phase Goal:** Charts render correctly across all time ranges with readable axes and proper interaction, and stat cards display without layout issues
**Verified:** 2026-03-24T18:30:00Z
**Status:** human_needed (all automated checks passed; 3 visual items need human confirmation)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ChartAxisFormatter.selectUnit returns KB/MB/GB based on thresholds | VERIFIED | Implementation at line 21-25 of ChartAxisFormatter.swift; 7 test cases cover all thresholds |
| 2 | ChartAxisFormatter.niceTickValues returns 5 values including 0 | VERIFIED | Implementation at line 29-38; 5 test cases; 26 total XCTAssert calls in test file |
| 3 | ChartAxisFormatter.formatTick produces strings like '25 MB' with correct unit | VERIFIED | Implementation at line 56-64; 5 formatTick test cases |
| 4 | yAxisMax helper returns max * 1.1 with a floor of 1024 | VERIFIED | Line 70: `return max(maxValue * 1.1, 1024)`; 3 yAxisMaxValue test cases |
| 5 | Y-axis does not shift on hover/selection (chartYScale locks domain) | VERIFIED (code) / ? HUMAN (visual) | chartYScale(domain: 0...yAxisMax) at HistoryChartView.swift line 142; visual confirmation needed |
| 6 | All four time range x-axis labels are formatted correctly | VERIFIED (code) / ? HUMAN (CHRT-02 format) | All 4 stride patterns present: .minute count:15 (1H), .hour count:6 (24H), .day (7D M/d), .day count:5 (30D MMM d) |
| 7 | Stat card primary text not truncated at large byte values | VERIFIED (code) / ? HUMAN (visual) | lineLimit(1) + minimumScaleFactor(0.7) on primary text; lineLimit(1) on both breakdown texts |

**Score:** 7/7 truths verified (3 also need human visual confirmation)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Shared/ChartAxisFormatter.swift` | Y-axis unit selection, nice tick calculation, tick label formatting | VERIFIED | 72 lines, `struct ChartAxisFormatter: Sendable`, all 4 static methods present |
| `BandwidthMonitorTests/ChartAxisFormatterTests.swift` | Unit tests for ChartAxisFormatter | VERIFIED | 134 lines, `final class ChartAxisFormatterTests: XCTestCase`, 26 XCTAssert calls (plan required >= 15) |
| `BandwidthMonitor/Popover/HistoryChartView.swift` | Fixed y-axis domain, custom x-axis per time range, human-readable y-axis | VERIFIED | 205 lines, contains chartYScale, chartYAxis, chartXAxis, ChartAxisFormatter calls (5 references) |
| `BandwidthMonitor/Popover/StatCardView.swift` | Stat card with truncation safety net | VERIFIED | 46 lines, contains 3x lineLimit(1) and 1x minimumScaleFactor(0.7) |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `BandwidthMonitorTests/ChartAxisFormatterTests.swift` | `BandwidthMonitor/Shared/ChartAxisFormatter.swift` | `@testable import BandwidthMonitor` + direct method calls | WIRED | `ChartAxisFormatter.` appears in test file; pattern confirmed |
| `BandwidthMonitor/Popover/HistoryChartView.swift` | `BandwidthMonitor/Shared/ChartAxisFormatter.swift` | ChartAxisFormatter.selectUnit, .niceTickValues, .formatTick, .yAxisMaxValue calls | WIRED | 5 `ChartAxisFormatter.` references found in HistoryChartView.swift |
| `BandwidthMonitor/Popover/HistoryChartView.swift` | `BandwidthMonitor/Shared/HistoryTimeRange.swift` | switch on timeRange for x-axis formatting | WIRED | `switch timeRange` at line 51 drives all 4 chartXAxis branches |
| `BandwidthMonitor/Popover/StatCardView.swift` | `BandwidthMonitor/Popover/CumulativeStatsView.swift` | StatCardView instantiation | WIRED | CumulativeStatsView.swift lines 14-16 instantiate all 3 StatCardView cards |
| `BandwidthMonitor/Popover/HistoryChartView.swift` | consumer views | HistoryChartView instantiation | WIRED | Used in DashboardView.swift line 67 and HistoryView.swift line 40 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `HistoryChartView.swift` | `dataPoints: [ChartDataPoint]` | Passed as prop from DashboardView/HistoryView (backed by GRDB database queries from prior phases) | Yes — props flow from DB-backed query results established in Phase 5/7 | FLOWING |
| `StatCardView.swift` | `totalIn: Double, totalOut: Double` | Props from CumulativeStatsView, which receives `today`, `week`, `month` from DB queries | Yes — data originates from AppDatabase cumulative stats queries | FLOWING |
| `ChartAxisFormatter.swift` | Pure functions — no state | Input: `dataPoints` array or scalar `maxBytes` | N/A — pure static functions, no data source | N/A |

---

### Behavioral Spot-Checks

Module-level checks only (app requires Xcode build to run; no CLI entry point):

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ChartAxisFormatter.swift exports expected struct | `grep "struct ChartAxisFormatter: Sendable"` | Found at line 6 | PASS |
| All 4 static methods defined | `grep "selectUnit\|niceTickValues\|formatTick\|yAxisMaxValue"` in formatter | 5 lines (4 definitions + 1 comment) | PASS |
| HistoryChartView has >= 4 ChartAxisFormatter references | `grep -c "ChartAxisFormatter\."` | 5 references | PASS |
| StatCardView has >= 3 lineLimit calls | `grep -c "lineLimit"` | 3 matches | PASS |
| StatCardView has >= 1 minimumScaleFactor call | `grep -c "minimumScaleFactor"` | 1 match | PASS |
| All 4 x-axis stride patterns present | `grep "stride(by:"` | 4 matches at lines 54, 62, 70, 82 | PASS |
| Date format strings correct | `grep "M/d\|MMM d"` in HistoryChartView | Both present at lines 37, 44 | PASS |
| Commits cd20593, 572efd4, d01d9f3, 9c83e23 exist | `git log --oneline` | All 4 confirmed | PASS |
| Live app build/test | xcodebuild (requires Xcode) | SKIPPED — requires Xcode GUI/build system | SKIP |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CHRT-01 | 09-01, 09-02 | Y-axis does not shift on hover/selection | SATISFIED | chartYScale(domain: 0...yAxisMax) at HistoryChartView.swift:142; yAxisMax computed from ChartAxisFormatter.yAxisMaxValue |
| CHRT-02 | 09-02 | 7D view: one bar per day with day labels | SATISFIED (with note) | Daily stride x-axis (`.stride(by: .day)`) with M/d format (shortDateFormatter). REQUIREMENTS.md says "Mon, Tue" but plan documents user decision for numeric M/d format instead. Implementation matches plan intent. |
| CHRT-03 | 09-02 | 30D view: one bar per day with day labels | SATISFIED | 5-day stride x-axis (`.stride(by: .day, count: 5)`) with MMM d format (mediumDateFormatter) |
| CHRT-04 | 09-01, 09-02 | Human-readable y-axis labels (KB/MB/GB) | SATISFIED | chartYAxis with ChartAxisFormatter.formatTick + yAxisUnit.rawValue suffix; niceTickValues produces round-number ticks |
| LYOT-01 | 09-02 | Stat card text fully visible, no truncation | SATISFIED | lineLimit(1) on all 3 texts, minimumScaleFactor(0.7) on primary text |

**Note on CHRT-02:** The REQUIREMENTS.md description says "day labels (Mon, Tue, etc.)" but the implementation uses numeric M/d format ("3/18", "3/19"). The plan explicitly states "per user decision: short numeric date, NOT day-of-week" and the PLAN's must_haves truth also says "short numeric date labels (M/d format like 3/18)". REQUIREMENTS.md was not updated to reflect the decision. This is a documentation staleness issue, not an implementation gap — but the requirements text should be updated.

**Orphaned requirements:** None. All 5 phase-9 requirements (CHRT-01 through CHRT-04, LYOT-01) are claimed by plans 09-01 and 09-02 and have implementation evidence.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | — |

Scanned all 4 phase files for: TODO/FIXME/PLACEHOLDER/coming soon comments, `return null`/`return []`/`return {}` stubs, hardcoded empty values, empty handlers. Zero matches.

---

### Human Verification Required

#### 1. CHRT-02 Format Confirmation

**Test:** Open the app, switch to 7D time range in the chart, examine x-axis labels
**Expected:** Labels should show short numeric dates like "3/18", "3/19", "3/20" (M/d format) — NOT day-of-week abbreviations like "Mon", "Tue". Verify this is the approved/desired format.
**Why human:** REQUIREMENTS.md says "day labels (Mon, Tue, etc.)" but the plan documents a user decision to use numeric M/d format instead. The requirements text was not updated to reflect this decision. Human confirmation closes this discrepancy.

#### 2. CHRT-01 Hover Stability (Visual)

**Test:** In the running app, switch to any time range (24H, 7D, 30D), then hover or click different bars on the chart
**Expected:** The y-axis labels remain completely static — no shifting, jumping, reflowing, or rescaling during any interaction. The domain stays locked to the pre-computed max value.
**Why human:** `chartYScale(domain: 0...yAxisMax)` is present in code and the pre-computed `yAxisMax` is outside the Chart closure (correct placement), but Swift Charts animation behavior during selection state changes can only be confirmed by seeing the chart rendered live.

#### 3. LYOT-01 Stat Card Rendering at Edge Values

**Test:** View stat cards (Today, This Week, This Month) in the floating panel. Ideally with a SwiftUI preview configured with very large values (e.g., 999 GB total, 1.2 TB total).
**Expected:** Primary combined total text scales down gracefully (minimumScaleFactor 0.7) rather than clipping. Download/upload breakdown texts stay on one line.
**Why human:** `.lineLimit(1)` and `.minimumScaleFactor(0.7)` are present in code but the actual card width at runtime and the rendered string length of ByteFormatter output at edge values determines whether scaling is ever invoked. A live test with realistic or extreme values confirms the safety net functions as intended.

---

### Gaps Summary

No gaps found. All 7 must-have truths verified at the code level. All 4 artifacts exist, are substantive (meet or exceed min_lines thresholds), and are wired into the app via their consumer views. All 4 git commits are confirmed in the repository. All 5 requirement IDs are satisfied with implementation evidence.

The 3 human verification items above are standard visual/interactive checks required for a chart-heavy UI phase — they do not indicate implementation defects. The CHRT-02 requirements text discrepancy is a documentation issue only.

---

_Verified: 2026-03-24T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
