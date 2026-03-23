---
phase: 03-data-persistence-and-aggregation
plan: 03
subsystem: database
tags: [sqlite, grdb, aggregation, pruning, time-series, sql]

# Dependency graph
requires:
  - phase: 03-01
    provides: AppDatabase with WAL mode, v1 migration creating raw_samples + 5 tier tables
  - phase: 03-02
    provides: BandwidthRecorder writing raw samples from NetworkMonitor observations
provides:
  - AggregationEngine cascading raw samples through 5 tiers (minute/hour/day/week/month)
  - PruningManager with configurable retention (24h default) for raw samples
  - Background timer integration in AppDelegate for periodic aggregation and pruning
affects: [05-historical-charts, 04-popover-ui]

# Tech tracking
tech-stack:
  added: []
  patterns: [SQL GROUP BY floor-division bucketing, watermark-based incremental processing, INSERT OR REPLACE idempotency, UTC-only time boundaries, Monday-aligned ISO 8601 weeks, strftime for month bucketing]

key-files:
  created:
    - BandwidthMonitor/Persistence/AggregationEngine.swift
    - BandwidthMonitor/Persistence/PruningManager.swift
    - BandwidthMonitorTests/AggregationEngineTests.swift
    - BandwidthMonitorTests/PruningManagerTests.swift
  modified:
    - BandwidthMonitor/AppDelegate.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "Single full aggregation cycle every 2 minutes rather than staggered tier timers -- cascading is fast (watermark-based) and idempotent"
  - "UTC-only bucketing throughout to avoid DST issues (per Pitfall 3 from research)"
  - "Watermark derived from MAX(bucketTimestamp) -- no separate watermark table needed"

patterns-established:
  - "SQL floor-division bucketing: CAST(CAST(ts / N AS INTEGER) * N AS REAL) for uniform tiers"
  - "strftime-based bucketing for variable-length periods (weeks via %w offset, months via %Y-%m-01)"
  - "Watermark optimization: only process records >= MAX(bucketTimestamp) of target tier"
  - "Background Task.sleep(for:tolerance:) loops for periodic work in macOS menu bar apps"

requirements-completed: [MON-04, MON-05]

# Metrics
duration: 9min
completed: 2026-03-23
---

# Phase 03 Plan 03: Aggregation Engine and Pruning Summary

**Cascading 5-tier aggregation engine (raw->minute->hour->day->week/month) with UTC bucketing, watermark optimization, and 24h raw sample pruning on background timers**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-23T20:55:00Z
- **Completed:** 2026-03-23T21:04:01Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- AggregationEngine cascades raw 10-second samples through 5 tiers using SQL GROUP BY with floor-division bucketing
- All aggregation is idempotent via INSERT OR REPLACE with UNIQUE(interfaceId, bucketTimestamp) constraints
- Week bucketing aligns to Monday (ISO 8601), month bucketing uses strftime for variable-length months
- PruningManager deletes raw samples older than configurable retention period (default 24 hours)
- AppDelegate runs pruning + aggregation on launch, then aggregation every 2 min and pruning every 24h
- 13 new tests (9 aggregation + 4 pruning) all passing, full suite at 86 tests with zero failures

## Task Commits

Each task was committed atomically:

1. **Task 1: AggregationEngine + PruningManager with tests** - `f39ad64` (feat)
2. **Task 2: Wire into AppDelegate with background timers** - `73fee3e` (feat)

## Files Created/Modified
- `BandwidthMonitor/Persistence/AggregationEngine.swift` - Cascading 5-tier rollup engine with SQL GROUP BY bucketing and watermark optimization
- `BandwidthMonitor/Persistence/PruningManager.swift` - Raw sample cleanup with configurable retention period
- `BandwidthMonitorTests/AggregationEngineTests.swift` - 9 tests covering all tier rollups, idempotency, multi-interface, and watermark behavior
- `BandwidthMonitorTests/PruningManagerTests.swift` - 4 tests covering pruning, preservation, aggregated data safety, and deleted count
- `BandwidthMonitor/AppDelegate.swift` - Added aggregation/pruning lifecycle management with background timers
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Registered 4 new files in main and test targets

## Decisions Made
- Single full aggregation cycle every 2 minutes rather than per-tier staggered timers, because cascading is fast (watermark skips already-processed records) and idempotent (INSERT OR REPLACE)
- UTC-only bucketing throughout all tiers to avoid DST boundary issues (per research Pitfall 3)
- Watermark derived from MAX(bucketTimestamp) of each target table -- avoids needing a separate watermark tracking table
- Used async helper functions with `await db.dbWriter.write/read` in Swift Testing tests to satisfy Swift 6 strict concurrency requirements on `any DatabaseWriter`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added async/await to test helper functions for Swift 6 concurrency**
- **Found during:** Task 1 (test compilation)
- **Issue:** `db.dbWriter.write { }` on `any DatabaseWriter` requires `await` in Swift 6 strict concurrency mode. Plan's test code used synchronous helpers.
- **Fix:** Made all test helper functions (`insertRaw`, `insertMinute`, `insertHour`, `insertDay`) async, and added `await` to all inline `dbWriter.read`/`dbWriter.write` calls in test methods.
- **Files modified:** BandwidthMonitorTests/AggregationEngineTests.swift, BandwidthMonitorTests/PruningManagerTests.swift
- **Verification:** All 13 tests compile and pass
- **Committed in:** f39ad64 (Task 1 commit)

**2. [Rule 3 - Blocking] Added Foundation import for TimeInterval type**
- **Found during:** Task 1 (test compilation)
- **Issue:** `TimeInterval` type not in scope in PruningManagerTests -- needs Foundation import
- **Fix:** Added `import Foundation` to PruningManagerTests.swift
- **Files modified:** BandwidthMonitorTests/PruningManagerTests.swift
- **Verification:** Compilation succeeds
- **Committed in:** f39ad64 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both were compilation fixes required for Swift 6 strict concurrency. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 03 (data-persistence-and-aggregation) is fully complete:
  - Plan 01: Database schema with WAL mode, all 6 tables, GRDB records
  - Plan 02: BandwidthRecorder writing raw samples from NetworkMonitor
  - Plan 03: Aggregation engine and pruning wired into AppDelegate
- Data pipeline is operational: monitor -> record -> aggregate -> prune
- Ready for Phase 04 (popover-ui) which can query aggregated tier data for charts
- Ready for Phase 05 (historical-charts) which will display minute/hour/day/week/month data

## Self-Check: PASSED

- All 5 created files verified present on disk
- Both task commits (f39ad64, 73fee3e) verified in git log
- 86 tests passing, 0 failures in full test suite

---
*Phase: 03-data-persistence-and-aggregation*
*Completed: 2026-03-23*
