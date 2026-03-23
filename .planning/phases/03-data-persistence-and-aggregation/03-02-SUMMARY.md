---
phase: 03-data-persistence-and-aggregation
plan: 02
subsystem: database
tags: [grdb, sqlite, observation, bandwidth-recorder, raw-samples, swift-concurrency]

# Dependency graph
requires:
  - phase: 03-01
    provides: "AppDatabase singleton, RawSample GRDB record, database schema with raw_samples table"
  - phase: 01
    provides: "NetworkMonitor with @Observable latestSnapshot, NetworkSnapshot/InterfaceSpeed/Speed types"
provides:
  - "BandwidthRecorder: observer that accumulates snapshots and writes RawSample records to database"
  - "AppDelegate database + recorder lifecycle wiring"
  - "processAndWrite() testable entry point for recorder logic"
affects: [03-03-aggregation-engine, 04-popover-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "withObservationTracking re-registration pattern for non-UI observation"
    - "nonisolated static method for off-main-thread database writes"
    - "Static pure function for building RawSample records from snapshots"
    - "DispatchSemaphore for synchronous async bridging in applicationWillTerminate"

key-files:
  created:
    - BandwidthMonitor/Persistence/BandwidthRecorder.swift
    - BandwidthMonitorTests/BandwidthRecorderTests.swift
  modified:
    - BandwidthMonitor/AppDelegate.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "withObservationTracking re-registration pattern instead of AsyncStream: simpler, matches StatusBarController pattern, avoids @Sendable closure issues with MainActor-isolated properties"
  - "Static nonisolated writeSamples with callback: passes pollingInterval and database as parameters to avoid actor hop for immutable values"
  - "processAndWrite() as testable entry point: tests call this directly instead of requiring a running observation loop"

patterns-established:
  - "Observer pattern: withObservationTracking -> handleSnapshot() -> writeSamples() pipeline"
  - "Off-main-thread DB writes: nonisolated static method with Sendable callback for actor state updates"
  - "Termination flush: DispatchSemaphore(value: 0) + Task + await flush() + 2s timeout"

requirements-completed: [MON-03]

# Metrics
duration: 14min
completed: 2026-03-23
---

# Phase 03 Plan 02: BandwidthRecorder Summary

**BandwidthRecorder observes NetworkMonitor via withObservationTracking, accumulates 5 snapshots (10s window), and writes per-interface RawSample records to SQLite off the main thread**

## Performance

- **Duration:** 14 min
- **Started:** 2026-03-23T20:37:12Z
- **Completed:** 2026-03-23T20:51:59Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- BandwidthRecorder accumulates configurable number of poll-cycle snapshots, computes per-interface total bytes (speed * pollingInterval per snapshot), and writes RawSample records to the database
- Database writes happen off the main thread via nonisolated static method, preventing UI blocking
- AppDelegate creates AppDatabase and BandwidthRecorder on launch, flushes buffered data on termination with 2-second timeout
- 6 comprehensive tests covering uniform snapshots, multi-interface, partial flush, batch writes, varying speed averaging, and empty snapshot handling

## Task Commits

Each task was committed atomically:

1. **Task 1: BandwidthRecorder (TDD RED)** - `839928c` (test) - Failing tests for accumulation and writing
2. **Task 1: BandwidthRecorder (TDD GREEN)** - `d70b0a3` (feat) - Full implementation passing all 6 tests
3. **Task 2: AppDelegate wiring** - `06b2ca7` (feat) - Database and recorder lifecycle integration

## Files Created/Modified

- `BandwidthMonitor/Persistence/BandwidthRecorder.swift` - Observer that accumulates snapshots and writes RawSample records (199 lines)
- `BandwidthMonitorTests/BandwidthRecorderTests.swift` - 6 tests covering accumulation, averaging, flushing, and edge cases
- `BandwidthMonitor/AppDelegate.swift` - Added appDatabase and bandwidthRecorder properties, launch/terminate lifecycle
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Registered new source and test files

## Decisions Made

- **withObservationTracking re-registration vs AsyncStream:** Used direct re-registration pattern (matching StatusBarController) instead of wrapping in AsyncStream. Avoids @Sendable closure complications when accessing MainActor-isolated NetworkMonitor.latestSnapshot. Simpler and consistent with existing codebase patterns.
- **Static nonisolated writeSamples:** Made the database write method `nonisolated static` with explicit parameters (pollingInterval, database) passed from the MainActor caller. This cleanly separates the actor-isolated state from the database write that should happen off-main-thread, avoiding `await self.property` hops for immutable values.
- **processAndWrite() for testability:** Exposed a method that directly invokes the write pipeline with provided snapshots. Tests don't need to simulate the observation loop -- they provide snapshots directly and verify database contents.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Swift 6 strict concurrency: @Sendable closure captures**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** Plan's code used AsyncStream with `@Sendable func observe()` capturing `self.networkMonitor.latestSnapshot` -- rejected by Swift 6 strict concurrency as MainActor-isolated property in nonisolated context
- **Fix:** Replaced AsyncStream pattern with direct withObservationTracking re-registration (matching StatusBarController). Also refactored writeSamples to static method with explicit parameters to avoid `var rawSamples` capture in @Sendable dbWriter.write closure
- **Files modified:** BandwidthMonitor/Persistence/BandwidthRecorder.swift
- **Verification:** Clean compile with Swift 6.0 strict concurrency, all 6 tests pass
- **Committed in:** d70b0a3

**2. [Rule 1 - Bug] Async read calls in tests**
- **Found during:** Task 1 (RED phase)
- **Issue:** Test code used `try db.dbWriter.read { ... }` without `await` in async test methods, failing to compile under Swift 6 strict concurrency
- **Fix:** Added `await` to all `db.dbWriter.read` calls in tests
- **Files modified:** BandwidthMonitorTests/BandwidthRecorderTests.swift
- **Verification:** Tests compile and run correctly
- **Committed in:** 839928c (part of RED phase)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes necessary for Swift 6 strict concurrency compliance. Core logic and architecture unchanged from plan. No scope creep.

## Issues Encountered

None beyond the Swift 6 concurrency issues documented as deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BandwidthRecorder is writing RawSample records to the database every 10 seconds (5 poll cycles at 2s)
- AppDatabase is accessible via `appDatabase` property on AppDelegate for Plan 03 (AggregationEngine, PruningManager) wiring
- Database schema (raw_samples + tier tables) from Plan 01 is populated with live data
- Ready for Plan 03: aggregation engine to roll up raw_samples into minute/hour/day/week/month tiers

## Self-Check: PASSED

- All 4 key files exist on disk
- All 3 task commits found in git history (839928c, d70b0a3, 06b2ca7)
- Build succeeds, 6/6 tests pass

---
*Phase: 03-data-persistence-and-aggregation*
*Completed: 2026-03-23*
