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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~6 | 7 | Initial GSD workflow — established verification, artifact, and aggregation patterns |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | ~100 | Partial (unit + integration) | 2 (swift-collections, swift-algorithms) |

### Top Lessons (Verified Across Milestones)

1. Verification artifacts should be created at phase completion, never retroactively
2. Single-character bugs (let vs var) are caught by multi-configuration tests — always test with multiple settings
