# Phase 2: Menu Bar Display - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Live upload/download speeds visible in the macOS menu bar with configurable units and launch at login. Uses the hybrid AppKit+SwiftUI architecture: NSStatusItem for the menu bar text display (updated every poll cycle), NSMenu for the context menu. No popover, no charts, no persistent preferences UI — those are Phases 4-5.

</domain>

<decisions>
## Implementation Decisions

### Speed Text Format
- **D-01:** Use ↑ ↓ (Unicode arrows U+2191, U+2193) as upload/download indicators
- **D-02:** Adaptive precision — 1 decimal place below 100 (e.g., 1.2 MB/s, 45.3 KB/s), no decimal at 100+ (e.g., 456 KB/s)
- **D-03:** Unit labels are MB/s, KB/s, GB/s (base-10 SI byte-rate units, not bits)
- **D-04:** Use SF Pro system font with `.monospacedDigit()` (tabular figures) to prevent jitter — digits are equal-width while letters remain proportional
- **D-05:** Text only in menu bar, no app icon. The arrows (↑↓) serve as the visual identifier

### Display Format Modes
- **D-06:** Single speed displayed at a time by default — "Auto" mode shows whichever direction (upload or download) currently has higher traffic. The arrow indicates which
- **D-07:** Four display format modes available: Auto (higher wins, **default**), Upload only, Download only, Both (upload + download side by side with space separator)
- **D-08:** When "Both" mode is active, format is: `↑ 1.2 MB/s ↓ 456 KB/s` (space separator, no divider character)

### Auto-Scale Behavior
- **D-09:** Base-10 SI boundaries: B/s → KB/s at 1,000 B/s, KB/s → MB/s at 1,000,000 B/s, MB/s → GB/s at 1,000,000,000 B/s
- **D-10:** Zero/near-zero traffic (< 1 KB/s) shows "0 KB/s" — no B/s tier, no idle indicator
- **D-11:** When user selects a fixed unit (e.g., always MB/s), the chosen unit is the ceiling — values too small for that unit fall back to KB/s or B/s so precision isn't lost

### Right-Click Menu
- **D-12:** Menu items in order: Metrics (disabled, "Coming soon"), Preferences (disabled, "Coming soon"), separator, About Bandwidth Monitor, Quit Bandwidth Monitor
- **D-13:** Both left-click and right-click open the same NSMenu. No popover on click in Phase 2 — the popover will be delivered in Phase 4 via the "Metrics" menu item

### Preferences
- **D-14:** All user preferences deferred to Phase 5. Phase 2 hardcodes defaults: Auto-scale units + Auto (higher wins) display format
- **D-15:** The formatting/unit infrastructure code supports all modes internally, but no user-facing configuration exists in Phase 2

### Login Item
- **D-16:** Auto-register as login item via SMAppService on first launch, no dialog or prompt. User can disable in System Settings > General > Login Items

### App Lifecycle
- **D-17:** First launch goes straight to menu bar — no onboarding, no welcome screen, no splash
- **D-18:** When no active network interfaces are detected, menu bar shows "—" (em dash) instead of speed text

### Claude's Discretion
- NSMenu construction details and item ordering refinements
- Exact spacing/padding in the status bar text string
- How to bridge NetworkMonitor (@Observable) data to NSStatusItem text updates
- AppDelegate vs SwiftUI App lifecycle integration approach
- SMAppService error handling (if registration fails silently)
- About window content and layout

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Stack
- `CLAUDE.md` — Full technology stack decisions, hybrid AppKit+SwiftUI architecture approach (NSStatusItem for text, SwiftUI for popover content), version requirements, API choices

### Requirements
- `.planning/REQUIREMENTS.md` — BAR-01 (speed text), BAR-02 (display units), BAR-03 (display format), BAR-04 (fixed-width formatting), SYS-01 (login item)

### Phase 1 Foundation
- `.planning/phases/01-core-monitoring-engine/01-CONTEXT.md` — D-07 (BSD→friendly names in engine), D-08 (aggregate speed computed), D-01/D-02 (2s polling, configurable)

### Known Risks
- `.planning/STATE.md` §Blockers/Concerns — sysctl IFMIB_IFDATA stability, App Sandbox compatibility

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkMonitor` (Monitoring/NetworkMonitor.swift): @MainActor @Observable, exposes `aggregateSpeed: Speed`, `interfaceSpeeds: [InterfaceSpeed]`, `latestSnapshot: NetworkSnapshot`, `isRunning: Bool`. Phase 2 observes these to update menu bar text
- `Speed` struct (Monitoring/NetworkSample.swift): `bytesInPerSecond: Double`, `bytesOutPerSecond: Double` with `.zero` static and `+` operator. Phase 2 builds formatting on top of this
- `InterfaceInfo` (Monitoring/NetworkSample.swift): Has `displayName` (human-readable, per D-07) and `type` (NWInterface.InterfaceType) for interface identification
- `InterfaceDetector` (Monitoring/InterfaceDetector.swift): Already detects active interfaces via NWPathMonitor. Phase 2 can check `activeInterfaces.isEmpty` for the disconnected state

### Established Patterns
- @MainActor @Observable for SwiftUI-observable state (NetworkMonitor). New Phase 2 view models should follow same pattern
- Sendable value types for data models (Speed, ByteCounters, InterfaceInfo, InterfaceSpeed, NetworkSnapshot)
- os.Logger for structured logging via Loggers.swift

### Integration Points
- `BandwidthMonitorApp.swift` is currently a stub SwiftUI App — needs to become the hybrid AppKit+SwiftUI entry point with AppDelegate and NSStatusItem
- No AppKit code exists yet — NSStatusItem, NSMenu, NSPopover infrastructure must be created from scratch
- NetworkMonitor.start() must be called during app initialization to begin polling

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

- **Multi-interface pin** — letting the user pick a specific interface (e.g., "Wi-Fi only") to display instead of aggregate total. Could be a preferences option in Phase 5
- **Display format/unit submenus in right-click menu** — user preferred to defer all preferences configuration to Phase 5 rather than inline submenus
- **Mbps (bits) unit option** — BAR-02 could include a bits-per-second option for users familiar with ISP speed conventions. Could be added in Phase 5 preferences

</deferred>

---

*Phase: 02-menu-bar-display*
*Context gathered: 2026-03-23*
