# Phase 4: Popover Shell and Interface Views - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Clickable popover window showing per-interface bandwidth breakdown with dark/light mode support. Left-click on the status item opens an NSPopover with two tabs (Metrics and Preferences). Right-click opens a context menu with Quit, Preferences, About, and Metrics items. No historical charts, no preferences controls, no cumulative statistics — those are Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Click Behavior
- **D-01:** Left-click on the status item opens the popover window directly. Right-click opens the context menu. This replaces the Phase 2 behavior where both clicks opened NSMenu
- **D-02:** Right-click context menu items: Metrics, Preferences, About Bandwidth Monitor, Quit Bandwidth Monitor
- **D-03:** Clicking "Metrics" or "Preferences" in the right-click menu opens the popover and navigates to that specific tab

### Popover Tabs
- **D-04:** Popover has two tabs: Metrics and Preferences, switched via a segmented control (SwiftUI Picker with .segmented style) at the top
- **D-05:** Preferences tab shows placeholder content in Phase 4 ("Coming in a future update" or similar). Phase 5 fills it in with actual preferences controls
- **D-06:** Metrics is the default tab when opening the popover via left-click

### Interface Breakdown Layout
- **D-07:** Simple rows — each interface is a row with SF Symbol icon + display name on the left, upload and download speeds on the right
- **D-08:** SF Symbols for interface type: wifi for Wi-Fi, cable.connector.horizontal for Ethernet, lock.shield for VPN/utun, network for unknown types
- **D-09:** Popover always shows both upload and download speeds per interface, regardless of menu bar display mode. Menu bar is the summary, popover is the detail

### Popover Structure
- **D-10:** Aggregate header section at the top of the Metrics tab showing combined total upload/download speed across all interfaces
- **D-11:** Per-interface list below the aggregate header
- **D-12:** No quit button inside the popover — quit is only available via the right-click context menu. (Deliberate deviation from POP-06 which says "popover includes a visible quit button" — the right-click menu satisfies the quit accessibility requirement)

### Visual Style
- **D-13:** Clean and spacious layout — generous padding, clear visual hierarchy, breathing room between interface rows
- **D-14:** Purely semantic SwiftUI colors (.primary, .secondary, .accentColor, system backgrounds) — zero custom colors, automatic dark/light mode adaptation
- **D-15:** Popover size approximately 400x500 pixels per POP-01

### Claude's Discretion
- NSPopover configuration (behavior, appearance, animation)
- How to manage left-click vs right-click on NSStatusItem (NSEvent mask, button override, or popover+menu coexistence)
- Exact spacing, padding, and font sizes within the popover
- How to bridge NetworkMonitor data to SwiftUI views (GRDBQuery @Query, direct @Observable observation, or EnvironmentObject)
- Tab state management (selected tab stored in view vs shared state for menu item navigation)
- Empty state when no interfaces are active (consistent with Phase 2 D-18 em dash approach)
- ScrollView behavior if many interfaces are listed

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Stack
- `CLAUDE.md` — Hybrid AppKit+SwiftUI architecture (NSStatusItem for status bar, SwiftUI for popover content), NSPopover hosting pattern, Swift Charts / SwiftUI version requirements

### Requirements
- `.planning/REQUIREMENTS.md` — POP-01 (popover ~400x500px), POP-03 (per-interface breakdown), POP-05 (dark/light mode), POP-06 (quit button — satisfied via context menu per D-12)

### Phase 1 Foundation
- `.planning/phases/01-core-monitoring-engine/01-CONTEXT.md` — D-07 (BSD→friendly names in engine), D-08 (aggregate speed computed), D-01/D-02 (2s polling)

### Phase 2 Integration
- `.planning/phases/02-menu-bar-display/02-CONTEXT.md` — D-05 (text only, no icon), D-12/D-13 (NSMenu setup to be replaced), D-14 (preferences deferred to Phase 5)

### Phase 3 Data Layer
- `.planning/phases/03-data-persistence-and-aggregation/03-CONTEXT.md` — D-02 (per-interface data stored), D-13 (per-interface at all tiers), AppDatabase with GRDB

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkMonitor` (Monitoring/NetworkMonitor.swift): @MainActor @Observable, exposes `aggregateSpeed: Speed`, `interfaceSpeeds: [InterfaceSpeed]` — direct data source for popover views
- `SpeedFormatter` / `SpeedTextBuilder` (MenuBar/): Can be reused for formatting speeds in the popover, though popover always shows both directions (D-09)
- `InterfaceInfo` (Monitoring/NetworkSample.swift): Has `displayName` and `type` (NWInterface.InterfaceType) — used for SF Symbol selection and row labels
- `AppDatabase` (Persistence/AppDatabase.swift): GRDB database — available for Phase 5 chart queries, not directly needed for Phase 4 live data
- `Loggers.swift`: Structured os.Logger — add a `.popover` or `.ui` logger category

### Established Patterns
- @MainActor @Observable for SwiftUI-observable state (NetworkMonitor) — popover views observe this directly
- withObservationTracking re-registration for AppKit bridges (StatusBarController) — Phase 4 uses SwiftUI's native @Observable observation instead
- Sendable value types for data models (Speed, InterfaceSpeed, InterfaceInfo)
- NSMenu construction in StatusBarController.buildMenu() — needs to be refactored to support left-click popover + right-click menu

### Integration Points
- `StatusBarController` (MenuBar/StatusBarController.swift): Currently assigns statusItem.menu for both clicks — must be reworked to handle left-click → NSPopover, right-click → NSMenu
- `AppDelegate.swift`: Creates StatusBarController and wires up NetworkMonitor — popover setup integrates here
- `BandwidthMonitorApp.swift`: SwiftUI App with @NSApplicationDelegateAdaptor — popover content views will be SwiftUI hosted inside NSPopover

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-popover-shell-and-interface-views*
*Context gathered: 2026-03-24*
