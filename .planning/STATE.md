---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Ready to execute
stopped_at: Completed 05-02-PLAN.md
last_updated: "2026-03-24T05:54:43.510Z"
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 12
  completed_plans: 11
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-23)

**Core value:** Reliable, always-visible network throughput monitoring -- glance at the menu bar for current speeds, open the popover for usage patterns over time
**Current focus:** Phase 05 — historical-charts-statistics-and-settings

## Current Position

Phase: 05 (historical-charts-statistics-and-settings) — EXECUTING
Plan: 3 of 3

## Performance Metrics

**Velocity:**

*Updated after each plan completion*
| Phase 01 P01 | 7min | 2 tasks | 11 files |
| Phase 01 P02 | 4min | 2 tasks | 6 files |
| Phase 03 P01 | 7min | 2 tasks | 6 files |
| Phase 03 P02 | 14min | 2 tasks | 4 files |
| Phase 03 P03 | 9min | 2 tasks | 6 files |
| Phase 04 P01 | 4min | 2 tasks | 8 files |
| Phase 05 P01 | 9min | 2 tasks | 10 files |
| Phase 05 P02 | 6min | 2 tasks | 11 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: 5 phases derived from 18 requirements; monitoring core first, then menu bar, persistence, popover, and finally historical charts + settings
- [Roadmap]: macOS 14 minimum target for @Observable; sysctl IFMIB_IFDATA as primary network API
- [Phase 01]: Used IFMIB_IFDATA sysctl for 64-bit byte counters, avoiding NET_RT_IFLIST2 batching/truncation bugs
- [Phase 01]: Counter reset detection reports zero speed (not wrapped delta) per D-04
- [Phase 01]: Swift 6.0 language version with strict concurrency; all model types are Sendable
- [Phase 01]: @MainActor @Observable for NetworkMonitor engine; ContinuousClock for elapsed time; poll-cycle re-enumeration as safety net (D-06)
- [Phase 03]: DatabaseWriter protocol (not DatabasePool) for AppDatabase.dbWriter, enabling in-memory DatabaseQueue for tests
- [Phase 03]: Separate concrete types per aggregation tier (MinuteSample, HourSample, etc.) per GRDB databaseTableName requirement
- [Phase 03]: withObservationTracking re-registration pattern for BandwidthRecorder (matches StatusBarController), avoiding AsyncStream @Sendable issues with Swift 6 strict concurrency
- [Phase 03]: Static nonisolated writeSamples with explicit parameters for off-main-thread DB writes; processAndWrite() as testable entry point
- [Phase 03]: Single full aggregation cycle every 2 minutes rather than staggered tier timers; watermark-based incremental processing; UTC-only bucketing
- [Phase 04]: Used Color.accentColor instead of .accent for foregroundStyle compatibility with current SwiftUI/Xcode version
- [Phase 04]: sfSymbolName(for:) as free function (not method on InterfaceInfo) to keep model types clean
- [Phase 05]: Three tabs (Metrics, History, Preferences); expand popover to ~400x550
- [Phase 05]: Bar chart with grouped download/upload bars; aggregate data only; interactive hover tooltip
- [Phase 05]: 3 cumulative stats cards (Today, This Week, This Month) with combined total + per-direction breakdown
- [Phase 05]: Preferences: display mode, unit, interval, launch-at-login; @AppStorage with immediate effect
- [Phase 05 P01]: fetchCumulativeStats queries hour_samples (not day_samples) for partial-day accuracy
- [Phase 05 P01]: Raw SQL with GRDB Row.fetchAll for GROUP BY aggregation queries
- [Phase 05 P01]: Shared/ directory for cross-cutting types used by multiple layers
- [Phase 05]: [Phase 05 P02]: StatusBarController created after DB do-catch for nil-safe appDatabase passing
- [Phase 05]: [Phase 05 P02]: Interactive Swift Charts with chartXSelection + RuleMark tooltip pattern for bar chart

### Pending Todos

None yet.

### Blockers/Concerns

- [Research]: sysctl IFMIB_IFDATA stability -- Apple could patch the no-batching behavior; implement IFMIB_IFDATA primary with NET_RT_IFLIST2 fallback
- [Research]: App Sandbox + sysctl compatibility unconfirmed for IFMIB_IFDATA; may need notarized direct distribution if sandboxed sysctl is restricted
- [Research]: DST/timezone boundary correctness in data aggregation (Phase 3) needs explicit test cases

## Session Continuity

Last session: 2026-03-24T05:54:43.507Z
Stopped at: Completed 05-02-PLAN.md
Resume file: None
