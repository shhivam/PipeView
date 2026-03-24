# Phase 8: Panel & Tab Restructure - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the NSPopover with a floating utility panel and merge the Metrics + History tabs into a single combined "Dashboard" tab. Users interact with the app through a floating panel containing a unified view with live speeds and historical data, plus a Preferences tab.

</domain>

<decisions>
## Implementation Decisions

### Panel positioning & behavior
- **D-01:** Floating panel appears centered on the active screen, detached from the menu bar (not anchored below the status item)
- **D-02:** Panel dismisses when user clicks outside it or switches focus to another application (same semantic as current `.transient` popover behavior)
- **D-03:** No animation on appear/disappear — instant show/hide for snappiest feel

### Combined view layout
- **D-04:** Live speeds at top, history below — aggregate header + per-interface speeds at top, then time range picker + chart + cumulative stats below (natural reading order: current state then historical context)
- **D-05:** Subtle divider line (SwiftUI `Divider()`) between the live speeds section and the history section
- **D-06:** Entire view scrolls if combined content exceeds panel height — single `ScrollView` wrapping everything, aggregate header scrolls off-screen if user scrolls down

### Tab bar & navigation
- **D-07:** Keep 2-tab segmented control: "Dashboard" (combined live + history) and "Preferences"
- **D-08:** Right-click context menu updated to match: "Dashboard" replaces separate "Metrics"/"History" items; "Preferences" stays; "About" and "Quit" unchanged
- **D-09:** Left-click opens panel defaulting to Dashboard tab (same pattern as current `.metrics` default)

### Panel sizing
- **D-10:** Panel size increased to 480x650 (from current 400x550) to give charts and stat cards more room with the combined content

### Claude's Discretion
- Exact always-on-top window level (NSWindow.Level) for the utility panel
- NSPanel vs NSWindow subclass choice for implementation
- How to center the panel on the active screen (NSScreen.main frame calculation)
- Internal spacing and padding adjustments for the combined view

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above.

Relevant codebase files:
- `BandwidthMonitor/MenuBar/StatusBarController.swift` — Current NSPopover setup, click handling, context menu, PopoverState management
- `BandwidthMonitor/Popover/PopoverContentView.swift` — Current root view with segmented tab picker, 400x550 frame
- `BandwidthMonitor/Popover/PopoverTab.swift` — PopoverTab enum (metrics/history/preferences) and PopoverState observable class
- `BandwidthMonitor/Popover/MetricsView.swift` — Live speeds view (aggregate header + per-interface list) to be composed into combined view
- `BandwidthMonitor/Popover/HistoryView.swift` — History view (time range picker + chart + cumulative stats) to be composed into combined view
- `BandwidthMonitor/AppDelegate.swift` — Application lifecycle, may need updates for panel window management

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MetricsView` — Aggregate header + per-interface list, can be embedded directly in combined view
- `HistoryView` — Time range picker + chart + stats, can be embedded below MetricsView
- `AggregateHeaderView` — Standalone aggregate speed display, composable
- `InterfaceRowView` — Per-interface speed row, composable
- `HistoryChartView` — Bar chart component, composable
- `CumulativeStatsView` — Today/Week/Month stat cards, composable
- `PopoverState` — Observable tab state, needs updating for new tab enum values

### Established Patterns
- `@Observable` / `@MainActor` pattern throughout — StatusBarController, NetworkMonitor, PopoverState
- `withObservationTracking` re-registration in StatusBarController for speed updates
- SwiftUI `Picker(.segmented)` for tab switching
- NSHostingController to bridge SwiftUI content into AppKit containers

### Integration Points
- `StatusBarController.setup()` — Replace NSPopover creation with NSPanel/NSWindow creation
- `StatusBarController.togglePopover()` — Replace popover show/close with panel show/close + centering logic
- `PopoverTab` enum — Rename/replace cases: `.metrics`/`.history` become `.dashboard`
- `PopoverContentView` — Restructure to compose MetricsView + HistoryView into single dashboard view
- Context menu builder — Update menu items to "Dashboard" / "Preferences"

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-panel-tab-restructure*
*Context gathered: 2026-03-24*
