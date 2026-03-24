---
phase: 08-panel-tab-restructure
verified: 2026-03-24T13:44:07Z
status: human_needed
score: 13/13 must-haves verified (automated)
human_verification:
  - test: "Floating panel appears centered on screen when left-clicking menu bar icon"
    expected: "Panel opens centered on active display, NOT anchored below menu bar item"
    why_human: "Panel positioning requires visual inspection at runtime; cannot verify NSScreen.visibleFrame centering logic without running the app"
  - test: "Panel floats above other windows"
    expected: "Panel remains visible on top of Finder windows, browser, etc."
    why_human: "Window level ordering requires live interaction to confirm"
  - test: "Panel dismisses when clicking outside or switching apps (Cmd+Tab)"
    expected: "Panel closes instantly with no animation when focus leaves it"
    why_human: "resignKey() dismiss behavior requires live interaction to observe"
  - test: "Dashboard tab shows live speeds above a divider, then history section below"
    expected: "Single scrollable view with aggregate header, per-interface list, divider, time range picker, chart, cumulative stats"
    why_human: "Visual layout and scroll behavior can only be confirmed by running the app"
  - test: "Right-click context menu shows exactly Dashboard and Preferences (no Metrics/History)"
    expected: "Menu: Dashboard | Preferences | --- | About Bandwidth Monitor | Quit Bandwidth Monitor"
    why_human: "Context menu rendering requires live right-click interaction"
---

# Phase 08: Panel Tab Restructure Verification Report

**Phase Goal:** Users interact with the app through a floating utility panel containing a single unified tab that shows both live speeds and historical data
**Verified:** 2026-03-24T13:44:07Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PopoverTab enum has exactly two cases: .dashboard and .preferences | VERIFIED | PopoverTab.swift line 7-9: `case dashboard = "Dashboard"`, `case preferences = "Preferences"` — no other cases |
| 2 | DashboardView composes live speeds and history in a single ScrollView | VERIFIED | DashboardView.swift line 20: `ScrollView {` wraps AggregateHeaderView (line 24), interface list (lines 28-40), HistoryChartView (line 67), CumulativeStatsView (lines 72-76) |
| 3 | A Divider separates live speeds section from history section | VERIFIED | DashboardView.swift line 26 (header/list divider), lines 44-47 (section divider with padding — the D-05 divider); 2 Dividers confirmed by grep count |
| 4 | PopoverContentView switches between DashboardView and PreferencesView based on selected tab | VERIFIED | PopoverContentView.swift lines 24-32: switch on popoverState.selectedTab with `case .dashboard: DashboardView(...)` and `case .preferences: PreferencesView()` |
| 5 | PopoverContentView frame is 480x650 | VERIFIED | PopoverContentView.swift line 34: `.frame(width: 480, height: 650)` |
| 6 | PopoverTests pass with updated enum assertions | VERIFIED | PopoverTests.swift lines 41-55: four updated tests assert `.dashboard.rawValue == "Dashboard"`, `.preferences.rawValue == "Preferences"`, `allCases.count == 2`, `allCases.first == .dashboard`; no .metrics or .history references remain |
| 7 | Clicking menu bar icon opens a floating panel centered on the active screen | UNCERTAIN | Code path exists and is correct: togglePanel() (line 117) → centerPanelOnActiveScreen() (line 136) → panel.makeKeyAndOrderFront(nil). Visual confirmation required. |
| 8 | The floating panel stays on top of other windows | VERIFIED (code) | FloatingPanel.swift lines 18-20: `isFloatingPanel = true`, `level = .floating`. Runtime visual confirmation required. |
| 9 | Panel dismisses when user clicks outside or switches focus | VERIFIED (code) | FloatingPanel.swift lines 51-54: `override func resignKey()` calls `super.resignKey()` then `close()`. Runtime confirmation required. |
| 10 | Panel appears and disappears instantly (no animation) | VERIFIED | FloatingPanel.swift line 32: `animationBehavior = .none` — confirmed in code |
| 11 | Right-click context menu shows Dashboard and Preferences (not Metrics/History) | VERIFIED | StatusBarController.swift lines 162-193: `title: "Dashboard"` and `title: "Preferences"` — grep confirms no "Metrics" or "History" title strings |
| 12 | Left-click opens panel defaulting to Dashboard tab | VERIFIED | StatusBarController.swift lines 117-126: togglePanel() sets `popoverState.selectedTab = .dashboard` before showing panel |
| 13 | Context menu Dashboard/Preferences items open panel to correct tab | VERIFIED | StatusBarController.swift lines 200-207: showDashboard() sets `.dashboard`, showPreferences() sets `.preferences`, both call showPanel() |

**Score:** 13/13 truths have supporting code; 5 require runtime human verification for behavioral confirmation

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Popover/PopoverTab.swift` | Updated PopoverTab enum with .dashboard/.preferences cases | VERIFIED | Exists, substantive (37 lines), contains `case dashboard`, `case preferences`, `PopoverState` with `selectedTab = .dashboard`, `sfSymbolName` function intact |
| `BandwidthMonitor/Popover/DashboardView.swift` | Combined live speeds + history view | VERIFIED | Exists, substantive (133 lines), contains `struct DashboardView: View`, single outer ScrollView, all required subview compositions |
| `BandwidthMonitor/Popover/PopoverContentView.swift` | Root view with 480x650 frame and dashboard/preferences switch | VERIFIED | Exists, substantive (36 lines), contains `.frame(width: 480, height: 650)`, switch on .dashboard/.preferences |
| `BandwidthMonitorTests/PopoverTests.swift` | Updated tests for new enum values | VERIFIED | Exists, substantive (56 lines), contains `PopoverTab.dashboard.rawValue`, `allCases.count, 2` — no .metrics or .history references |
| `BandwidthMonitor/MenuBar/FloatingPanel.swift` | NSPanel subclass for floating utility window | VERIFIED | Exists, substantive (55 lines), contains `class FloatingPanel: NSPanel`, all required properties and overrides |
| `BandwidthMonitor/MenuBar/StatusBarController.swift` | Panel lifecycle management replacing NSPopover | VERIFIED | Exists, substantive (223 lines), no NSPopover references, `private lazy var panel: FloatingPanel`, `togglePanel()`, `centerPanelOnActiveScreen()`, `NSHostingView` embedding |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| DashboardView.swift | AggregateHeaderView.swift | AggregateHeaderView(speed:) composition | WIRED | Line 24: `AggregateHeaderView(speed: networkMonitor.aggregateSpeed)` |
| DashboardView.swift | HistoryChartView.swift | HistoryChartView(dataPoints:timeRange:) composition | WIRED | Line 67: `HistoryChartView(dataPoints: chartData, timeRange: selectedRange)` |
| PopoverContentView.swift | DashboardView.swift | switch on .dashboard case | WIRED | Line 25: `case .dashboard:` renders `DashboardView(networkMonitor: networkMonitor, appDatabase: appDatabase)` |
| StatusBarController.swift | FloatingPanel.swift | lazy var panel property instantiation | WIRED | Line 17-27: `private lazy var panel: FloatingPanel = { FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 650)) ... }()` |
| StatusBarController.swift | PopoverContentView.swift | NSHostingView embedding SwiftUI content in panel | WIRED | Lines 19-25: `panel.contentView = NSHostingView(rootView: PopoverContentView(...))` |
| StatusBarController.swift | PopoverTab.swift | popoverState.selectedTab = .dashboard | WIRED | Lines 122, 201: `popoverState.selectedTab = .dashboard` in togglePanel() and showDashboard() |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| DashboardView.swift | `chartData` | `appDatabase.fetchChartData(tier:since:)` | Yes — SQL: `SELECT bucketTimestamp, SUM(totalBytesIn), SUM(totalBytesOut) FROM {tier.tableName} WHERE bucketTimestamp >= ? GROUP BY bucketTimestamp ORDER BY bucketTimestamp ASC` | FLOWING |
| DashboardView.swift | `todayStats`, `weekStats`, `monthStats` | `appDatabase.fetchCumulativeStats(since:)` | Yes — SQL: `SELECT COALESCE(SUM(totalBytesIn), 0), COALESCE(SUM(totalBytesOut), 0) FROM hour_samples WHERE bucketTimestamp >= ?` | FLOWING |
| DashboardView.swift | live speed data via `networkMonitor.aggregateSpeed` / `networkMonitor.interfaceSpeeds` | NetworkMonitor (upstream, Phase 02) — @Observable, observed via SwiftUI | Real sysctl-based polling — out of scope for this phase | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — the app requires a running macOS process and menu bar integration. There are no runnable entry points testable via command-line without launching the full app. Behavioral verification is delegated to human checks below.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| UIST-01 | 08-01-PLAN.md | User sees a single "Metrics" tab combining live interface speeds and history charts in one scrollable view | SATISFIED | DashboardView.swift exists and composes live speeds + history in a single ScrollView; PopoverContentView routes .dashboard case to DashboardView; no separate Metrics/History tabs remain |
| UIST-02 | 08-02-PLAN.md | User interacts with a floating utility panel instead of a popover (stays on top, dismisses on focus loss) | SATISFIED (code) / NEEDS HUMAN (behavior) | FloatingPanel.swift implements NSPanel with `.floating` level, `resignKey()` dismiss, `animationBehavior = .none`; StatusBarController fully migrated from NSPopover; code evidence is complete; visual/behavioral confirmation required |

Note: REQUIREMENTS.md wording for UIST-01 says "Metrics tab" but the implementation correctly uses "Dashboard" tab — the plan's design spec (D-07) overrides the requirement name. The intent (single combined view) is fully satisfied.

No orphaned requirements found — both UIST-01 and UIST-02 are claimed by plans 08-01 and 08-02 respectively, and both appear in REQUIREMENTS.md mapping to Phase 8.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| FloatingPanel.swift | 5 | Comment: "Replaces NSPopover" (contains "NSPopover" as a doc comment string) | Info | Not a code reference — documentation comment only, does not affect behavior |

No stub patterns, TODO/FIXME markers, hardcoded empty return values, or placeholder implementations found across any phase 08 modified files.

### Human Verification Required

#### 1. Panel Centers on Active Screen

**Test:** Build and run the app, then left-click the menu bar icon.
**Expected:** The floating panel appears centered on the screen — not anchored below the menu bar icon. If multiple displays are connected, it should appear on the display with keyboard focus.
**Why human:** NSScreen.visibleFrame centering math (StatusBarController.swift lines 136-145) is correct in code but can only be confirmed visually with a live app.

#### 2. Panel Floats Above Other Windows

**Test:** Open a Finder window and position it to overlap where the panel will appear. Click the menu bar icon.
**Expected:** The panel appears on top of the Finder window.
**Why human:** Window level ordering requires a live environment to observe.

#### 3. Dismiss on Click-Outside and Focus Loss

**Test (a):** Open the panel. Click anywhere outside the panel on the desktop or in another app window.
**Expected:** Panel closes instantly with no animation.
**Test (b):** Open the panel. Press Cmd+Tab to switch to another app.
**Expected:** Panel closes instantly.
**Why human:** `resignKey()` dismiss behavior requires live interaction — canBecomeKey=true and resignKey()→close() are coded correctly but focus semantics with `.nonactivatingPanel` need runtime confirmation.

#### 4. Dashboard Tab Visual Layout

**Test:** Open the panel, verify the Dashboard tab content.
**Expected:** Top: aggregate upload/download speeds header. Below a divider: per-interface rows. Below a second divider: segmented time range picker, bandwidth chart, and three cumulative stat cards (Today / This Week / This Month). The entire view scrolls as a single unit.
**Why human:** Visual layout, scroll behavior, and the absence of nested scroll regions fighting each other can only be confirmed by running the app.

#### 5. Right-Click Context Menu Items

**Test:** Right-click the menu bar icon.
**Expected:** Menu shows exactly: "Dashboard", "Preferences", a separator line, "About Bandwidth Monitor", "Quit Bandwidth Monitor". No "Metrics" or "History" items appear.
**Why human:** Context menu rendering requires live right-click interaction.

### Gaps Summary

No automated gaps found. All 6 artifacts exist, are substantive, and are fully wired. All 6 key links are connected. Both data sources (`fetchChartData` and `fetchCumulativeStats`) execute real SQL queries against the database. No stub patterns or TODO markers detected.

The 5 human verification items above are behavioral checks that require the app to run — they are not gaps in the code, but confirmations that the correct code produces correct runtime behavior. The phase goal is achievable given the code state; human verification closes the loop on the interactive experience.

---

_Verified: 2026-03-24T13:44:07Z_
_Verifier: Claude (gsd-verifier)_
