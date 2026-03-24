# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-24
**Phases:** 7 | **Plans:** 14 | **Tasks:** 29

### What Was Built
- Real-time network throughput monitoring engine using sysctl IFMIB_IFDATA with NWPathMonitor interface detection
- Menu bar display with configurable speed text, monospaced digits, and auto-login via SMAppService
- GRDB SQLite database with 5-tier cascading aggregation (raw → minute → hour → day → week/month)
- SwiftUI popover with per-interface breakdown, SF Symbol icons, left-click/right-click dual behavior
- Historical bar charts via Swift Charts with interactive tooltips and 4 time ranges
- Full preferences UI with immediate-effect @AppStorage bindings

### What Worked
- TDD approach for SpeedFormatter/SpeedTextBuilder (31 tests) caught edge cases early and made the code rock-solid
- Hybrid AppKit+SwiftUI architecture gave best of both worlds: performant menu bar text updates + declarative popover content
- GRDB with DatabaseWriter protocol enabled fast unit tests via in-memory DatabaseQueue
- Wave-based parallel execution kept phases moving efficiently
- sysctl IFMIB_IFDATA choice avoided the NET_RT_IFLIST2 batching/truncation bugs entirely

### What Was Inefficient
- Phase 4 VERIFICATION.md was missed initially, requiring Phase 7 as cleanup
- 9 requirement checkboxes went stale across Phases 1-4, also requiring Phase 7 to fix
- Phase 6 was needed because BandwidthRecorder had a hardcoded pollingInterval (let instead of var) — could have been caught with a multi-interval test in Phase 3

### Patterns Established
- withObservationTracking re-registration pattern for bridging @Observable to imperative code (StatusBarController, BandwidthRecorder)
- Shared/ directory for cross-cutting types used by multiple layers
- Raw SQL with GRDB Row.fetchAll for GROUP BY aggregation queries
- sfSymbolName(for:) as free function to keep model types clean
- Color.accentColor (not .accent) for foregroundStyle compatibility

### Key Lessons
1. Always create VERIFICATION.md at phase completion — retroactive verification is wasteful
2. Keep requirement checkboxes updated atomically with phase completion — stale checkboxes compound
3. Use `var` for any property that could plausibly change at runtime — `let pollingInterval` was a single-character bug

### Cost Observations
- Model mix: ~70% opus, ~25% sonnet, ~5% haiku
- Sessions: ~6 sessions across 2 days
- Notable: 14 plans executed across 7 phases in 2 days — high throughput for a greenfield native macOS app

---

## Milestone: v1.1 — UI Polish & Chart Fixes

**Shipped:** 2026-03-25
**Phases:** 2 | **Plans:** 4 | **Tasks:** 8

### What Was Built
- Merged Metrics + History tabs into a single Dashboard view with unified ScrollView layout (480x650)
- Replaced NSPopover with floating NSPanel utility window (stays on top, dismisses on focus loss)
- TDD ChartAxisFormatter with KB/MB/GB unit selection, nice-number tick calculation (21 tests)
- Locked y-axis domain and per-time-range x-axis labels (1H/24H/7D/30D)
- Stat card truncation safety net with lineLimit + minimumScaleFactor

### What Worked
- TDD for ChartAxisFormatter (Plan 09-01) produced a clean, well-tested formatter that wired in seamlessly in Plan 09-02
- Phase ordering (structural UI changes in Phase 8, then fixes in Phase 9) prevented rework — chart fixes built on the new 480x650 canvas
- resignKey() override for NSPanel dismiss was simpler and more reliable than NSEvent global monitors
- Zero deviations from plan in 3 of 4 plans — clear discuss/research phases led to precise execution

### What Was Inefficient
- Nothing significant — v1.1 was a focused 2-phase milestone with clear requirements
- MetricsView and HistoryView are still dead code from v1.0 (should clean up in future)

### Patterns Established
- FloatingPanel pattern: NSPanel subclass with resignKey() dismiss, no animation, reusable instance
- Chart axis restructure: chartBase computed property + switch for per-range axis modifiers
- Static DateFormatter pattern for chart labels (avoid per-render allocation)
- Verify-only safety net approach: lineLimit + minimumScaleFactor as zero-cost guards

### Key Lessons
1. Structural UI changes (tab merge, window type) should come before visual fixes — provides the correct canvas for subsequent work
2. Pure-function formatters (ChartAxisFormatter) are ideal TDD targets — no dependencies, fast tests, clean integration
3. NSPanel with .nonactivatingPanel is the standard pattern for macOS floating utility windows

### Cost Observations
- Model mix: ~60% opus, ~30% sonnet, ~10% haiku
- Sessions: ~2 sessions across 1 day
- Notable: 4 plans executed across 2 phases in 1 day — efficient for a UI polish milestone

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~6 | 7 | Initial GSD workflow — established verification, artifact, and aggregation patterns |
| v1.1 | ~2 | 2 | Focused UI polish — zero deviations in 3/4 plans, TDD formatter pattern |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | ~100 | Partial (unit + integration) | 2 (swift-collections, swift-algorithms) |
| v1.1 | ~121 | Partial (unit + integration + UAT) | 0 |

### Top Lessons (Verified Across Milestones)

1. Verification artifacts should be created at phase completion, never retroactively
2. Single-character bugs (let vs var) are caught by multi-configuration tests — always test with multiple settings
3. Pure-function formatters are ideal TDD targets — validated in both v1.0 (SpeedFormatter) and v1.1 (ChartAxisFormatter)
4. Structural UI changes before visual fixes prevents rework — validated in v1.1 (Phase 8 before Phase 9)
