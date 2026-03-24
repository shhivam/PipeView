---
phase: 03-data-persistence-and-aggregation
plan: 01
subsystem: database
tags: [grdb, sqlite, persistence, migrations, record-types]

# Dependency graph
requires:
  - phase: 01-core-monitoring-engine
    provides: "NetworkSample types (InterfaceInfo.bsdName used as interfaceId in DB)"
provides:
  - "AppDatabase singleton with DatabaseWriter protocol and v1 migration"
  - "raw_samples table and 5 aggregation tier tables (minute/hour/day/week/month)"
  - "RawSample GRDB record type for raw 10-second samples"
  - "MinuteSample, HourSample, DaySample, WeekSample, MonthSample record types"
  - "AggregatedRecord protocol and AggregationTier enum"
  - "AppDatabase.makeEmpty() for in-memory test databases"
  - "Logger.persistence category for database operations"
affects: [03-02-PLAN, 03-03-PLAN, 04-popover-window-and-charts, 05-historical-charts-and-settings]

# Tech tracking
tech-stack:
  added: [GRDB.swift 7.10.0, GRDBQuery 0.11.0]
  patterns: [DatabaseWriter protocol abstraction, in-memory DatabaseQueue for tests, Codable GRDB records, cascading tier schema]

key-files:
  created:
    - BandwidthMonitor/Persistence/AppDatabase.swift
    - BandwidthMonitor/Persistence/Models/RawSample.swift
    - BandwidthMonitor/Persistence/Models/AggregatedSample.swift
    - BandwidthMonitorTests/AppDatabaseTests.swift
  modified:
    - BandwidthMonitor.xcodeproj/project.pbxproj
    - BandwidthMonitor/Logging/Loggers.swift

key-decisions:
  - "DatabaseWriter protocol (not DatabasePool directly) allows in-memory DatabaseQueue for tests"
  - "Separate concrete types per aggregation tier (not dynamic table name) per GRDB best practices"
  - "All timestamps as UTC Unix epoch Double for efficient arithmetic bucketing"
  - "UNIQUE(interfaceId, bucketTimestamp) on aggregation tables for idempotent INSERT OR REPLACE"

patterns-established:
  - "AppDatabase.makeEmpty() pattern: in-memory DatabaseQueue for fast, cleanup-free unit tests"
  - "AggregatedRecord protocol: shared interface for all 5 aggregation tier types"
  - "RawSample.Columns enum: type-safe column references for GRDB queries"

requirements-completed: [MON-03]

# Metrics
duration: 7min
completed: 2026-03-24
---

# Phase 03 Plan 01: GRDB Database Foundation Summary

**GRDB.swift database layer with DatabaseWriter protocol, v1 migration creating 6 tables, RawSample and 5 aggregation tier record types, and 7 passing database tests**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-23T20:26:28Z
- **Completed:** 2026-03-23T20:34:06Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- GRDB.swift 7.10.0 and GRDBQuery 0.11.0 integrated as SPM dependencies, resolving and building cleanly
- AppDatabase singleton with DatabaseWriter protocol abstraction -- DatabasePool for production (WAL mode), in-memory DatabaseQueue for tests
- v1 migration creates raw_samples table (with timestamp and interface+timestamp indexes) plus 5 aggregation tier tables with UNIQUE(interfaceId, bucketTimestamp) constraints
- RawSample and 5 tier-specific record types (MinuteSample through MonthSample) all conform to Codable, FetchableRecord, PersistableRecord, Sendable
- AggregatedRecord protocol provides shared interface; AggregationTier enum maps tier names to table names and bucket durations
- 7 database tests verify schema creation, CRUD roundtrips, UNIQUE constraint idempotency, and type-safe column filtering
- Logger.persistence category added for database operation logging

## Task Commits

Each task was committed atomically:

1. **Task 1: Add GRDB/GRDBQuery SPM deps, AppDatabase with migrations, persistence logger** - `11a9d0c` (feat)
2. **Task 2 (TDD RED): Failing tests for record types** - `a6a9308` (test)
3. **Task 2 (TDD GREEN): Implement RawSample and aggregation tier record types** - `f226731` (feat)

## Files Created/Modified
- `BandwidthMonitor/Persistence/AppDatabase.swift` - Database singleton with migrations, factory methods
- `BandwidthMonitor/Persistence/Models/RawSample.swift` - GRDB record for raw 10-second network samples
- `BandwidthMonitor/Persistence/Models/AggregatedSample.swift` - AggregatedRecord protocol, AggregationTier enum, 5 tier record types
- `BandwidthMonitorTests/AppDatabaseTests.swift` - 7 tests for schema, CRUD, constraints, filtering
- `BandwidthMonitor.xcodeproj/project.pbxproj` - SPM dependencies, file references, build phases
- `BandwidthMonitor/Logging/Loggers.swift` - Added Logger.persistence category

## Decisions Made
- Used `any DatabaseWriter` protocol type (not `DatabasePool` directly) so that `makeEmpty()` can use in-memory `DatabaseQueue` for tests -- avoids temp-file cleanup and is faster
- Separate concrete types per tier (MinuteSample, HourSample, etc.) rather than dynamic table name -- GRDB's `databaseTableName` is static, per RESEARCH.md recommendation
- All timestamps stored as UTC Unix epoch Double for efficient range queries and arithmetic bucketing
- UNIQUE(interfaceId, bucketTimestamp) constraint on all aggregation tables enables idempotent re-aggregation via INSERT OR REPLACE

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all record types are fully wired with complete field sets matching the database schema.

## Next Phase Readiness
- Database foundation complete with all 6 tables and record types
- AppDatabase.makeEmpty() available for all future test files
- Ready for Plan 03-02 (BandwidthRecorder) which will write RawSample records
- Ready for Plan 03-03 (aggregation engine) which will read raw samples and write aggregated tier records

## Self-Check: PASSED

All 5 created files verified on disk. All 3 task commits verified in git log.

---
*Phase: 03-data-persistence-and-aggregation*
*Completed: 2026-03-24*
