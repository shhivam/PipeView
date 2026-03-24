---
phase: 03-data-persistence-and-aggregation
verified: 2026-03-24T00:00:00Z
status: passed
score: 11/11 must-haves verified
re_verification: false
gaps: []
human_verification: []
---

# Phase 3: Data Persistence and Aggregation Verification Report

**Phase Goal:** Build the data persistence layer using GRDB.swift — record raw bandwidth samples, aggregate into 5 time tiers (minute/hour/day/week/month), and prune old data automatically.
**Verified:** 2026-03-24
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                         | Status     | Evidence                                                                                   |
|----|---------------------------------------------------------------------------------------------------------------|------------|--------------------------------------------------------------------------------------------|
| 1  | Bandwidth samples are continuously written to SQLite at regular intervals while the app runs                  | VERIFIED   | BandwidthRecorder writes RawSample every 10s (5 x 2s) via withObservationTracking pipeline |
| 2  | Raw samples are automatically aggregated into minute, hour, day, week, and month granularity tiers            | VERIFIED   | AggregationEngine has 5 INSERT OR REPLACE SQL methods; AppDelegate runs every 2 min        |
| 3  | Old raw samples are pruned while aggregated data is preserved, keeping the database bounded                   | VERIFIED   | PruningManager.pruneOldSamples() deletes only raw_samples older than retention cutoff      |
| 4  | Database writes do not block or degrade the monitoring loop or menu bar updates                               | VERIFIED   | writeSamples is `nonisolated static`, runs off main thread; timers use Task.sleep          |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact                                                      | Expected                                               | Status     | Details                                                       |
|---------------------------------------------------------------|--------------------------------------------------------|------------|---------------------------------------------------------------|
| `BandwidthMonitor/Persistence/AppDatabase.swift`              | DatabaseWriter-backed singleton, migrations, shared    | VERIFIED   | 96 lines; `any DatabaseWriter`, `makeDefault()`, `makeEmpty()`, v1 migration creating 6 tables |
| `BandwidthMonitor/Persistence/Models/RawSample.swift`         | GRDB record type for raw 10-second samples             | VERIFIED   | 31 lines; Codable/FetchableRecord/PersistableRecord/Sendable, databaseTableName="raw_samples", Columns enum |
| `BandwidthMonitor/Persistence/Models/AggregatedSample.swift`  | GRDB record types for all 5 aggregation tiers          | VERIFIED   | 131 lines; AggregatedRecord protocol, AggregationTier enum, MinuteSample through MonthSample |
| `BandwidthMonitor/Persistence/BandwidthRecorder.swift`        | Observer that accumulates snapshots and writes records | VERIFIED   | 199 lines (min: 80); withObservationTracking, nonisolated static writeSamples, processAndWrite testable entry |
| `BandwidthMonitor/Persistence/AggregationEngine.swift`        | Cascading tier rollup logic with SQL GROUP BY          | VERIFIED   | 192 lines (min: 100); 5 INSERT OR REPLACE SQL methods, watermark optimization, strftime for week/month |
| `BandwidthMonitor/Persistence/PruningManager.swift`           | Raw sample cleanup with 24-hour retention              | VERIFIED   | 41 lines (min: 40); pruneOldSamples(), RawSample.Columns.timestamp filter, deleteAll       |
| `BandwidthMonitorTests/AppDatabaseTests.swift`                | Tests for database creation, migration, table verification | VERIFIED | 7 XCTest tests covering schema, CRUD, UNIQUE constraint, column filtering                  |
| `BandwidthMonitorTests/BandwidthRecorderTests.swift`          | Tests for accumulation, averaging, and writing logic   | VERIFIED   | 6 XCTest tests covering uniform snapshots, multi-interface, partial flush, batching, varying speeds, empty |
| `BandwidthMonitorTests/AggregationEngineTests.swift`          | Tests for all tier rollups and idempotency             | VERIFIED   | 9 Swift Testing tests covering all tier cascades, idempotency, multi-interface, watermark  |
| `BandwidthMonitorTests/PruningManagerTests.swift`             | Tests for pruning and aggregate preservation           | VERIFIED   | 4 Swift Testing tests covering pruning, preservation, aggregate safety, deleted count      |

### Key Link Verification

| From                              | To                                      | Via                                        | Status  | Details                                                         |
|-----------------------------------|-----------------------------------------|--------------------------------------------|---------|-----------------------------------------------------------------|
| AppDatabase.swift                 | GRDB.swift DatabasePool                 | `import GRDB`, `DatabasePool(path:)`       | WIRED   | Line 1: `import GRDB`; line 41: `DatabasePool(path: dbURL.path)` |
| RawSample.swift                   | raw_samples table                       | `databaseTableName = "raw_samples"`        | WIRED   | Line 9: `static let databaseTableName = "raw_samples"`          |
| BandwidthRecorder.swift           | NetworkMonitor.swift                    | `withObservationTracking` on latestSnapshot | WIRED  | Lines 64-72: re-registration pattern via `startObserving()`     |
| BandwidthRecorder.swift           | AppDatabase.swift                       | `dbWriter.write` for RawSample inserts     | WIRED   | Line 148: `try await database.dbWriter.write { dbConn in ... }` |
| AppDelegate.swift                 | BandwidthRecorder.swift                 | property + start/flush/stop calls          | WIRED   | Lines 16, 45-50, 107, 111: all lifecycle hooks present          |
| AggregationEngine.swift           | raw_samples -> minute_samples           | INSERT OR REPLACE INTO minute_samples      | WIRED   | Line 43: SQL present with GROUP BY floor-division bucketing     |
| AggregationEngine.swift           | minute_samples -> hour_samples          | INSERT OR REPLACE INTO hour_samples        | WIRED   | Line 70: SQL present                                            |
| AggregationEngine.swift           | hour_samples -> day_samples             | INSERT OR REPLACE INTO day_samples         | WIRED   | Line 97: SQL present                                            |
| AggregationEngine.swift           | day_samples -> week_samples             | INSERT OR REPLACE INTO week_samples (strftime ISO Mon) | WIRED | Lines 127-141: strftime('%w') with (day+6)%7 offset           |
| AggregationEngine.swift           | day_samples -> month_samples            | INSERT OR REPLACE INTO month_samples (strftime) | WIRED | Lines 158-172: strftime('%Y-%m-01') first-of-month bucketing   |
| PruningManager.swift              | raw_samples table                       | DELETE WHERE timestamp < cutoff            | WIRED   | Lines 30-32: `RawSample.filter(Columns.timestamp < cutoff).deleteAll(db)` |
| AppDelegate.swift                 | AggregationEngine + PruningManager      | Timer-driven background Tasks              | WIRED   | Lines 53-84: both created, Task.sleep timers running at 120s and 86400s |

### Data-Flow Trace (Level 4)

Not applicable — this phase produces no UI components. All artifacts are data-layer (records, database writes, aggregation SQL, pruning). The data flows into SQLite and is verified by the test suite.

### Behavioral Spot-Checks

Step 7b SKIPPED — no runnable entry points that can be tested without launching the full macOS app. All behavioral verification is covered by the 26-test suite across AppDatabaseTests, BandwidthRecorderTests, AggregationEngineTests, and PruningManagerTests.

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                | Status    | Evidence                                                                 |
|-------------|-------------|--------------------------------------------------------------------------------------------|-----------|--------------------------------------------------------------------------|
| MON-03      | 03-01, 03-02 | App records bandwidth samples to SQLite at regular intervals                              | SATISFIED | AppDatabase v1 migration creates raw_samples table; BandwidthRecorder writes every 10s via withObservationTracking accumulation |
| MON-04      | 03-03       | App aggregates raw samples into minute, hour, day, week, and month granularity tiers       | SATISFIED | AggregationEngine implements all 5 INSERT OR REPLACE SQL methods; runs every 2 min on background timer |
| MON-05      | 03-03       | App prunes old raw samples while preserving aggregated data to keep database bounded       | SATISFIED | PruningManager deletes only raw_samples with timestamp < cutoff; aggregated tier tables untouched |

**Orphaned requirements:** None — REQUIREMENTS.md maps exactly MON-03, MON-04, MON-05 to Phase 3 and all three are claimed by plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| BandwidthRecorder.swift | 167 | `return []` | Info | Guard-clause empty return in `buildRawSamples` when `snapshots.isEmpty` — correct defensive programming, not a stub |

No blockers or warnings found. The single info-level item is a correct guard-clause.

### Human Verification Required

None identified. All observable truths in this phase are verifiable programmatically:
- Database schema correctness: verified by inspecting AppDatabase.swift migration code
- Aggregation SQL correctness: verified by reading AggregationEngine.swift and confirmed by 9 passing unit tests
- Pruning behavior: verified by PruningManager.swift and 4 tests
- Off-main-thread writes: verified by `nonisolated static` on writeSamples
- AppDelegate wiring: verified by grepping all initialization, timer, and termination patterns

### Gaps Summary

No gaps. All 11 must-have truths and artifacts are verified at all levels (exists, substantive, wired). The phase goal is fully achieved.

---

## Supporting Detail

### SPM Dependencies

GRDB.swift 7.10.0 and GRDBQuery 0.11.0 are registered as `XCRemoteSwiftPackageReference` entries with `upToNextMajorVersion` in `BandwidthMonitor.xcodeproj/project.pbxproj`. GRDB is linked to both the main target and the test target (two `XCSwiftPackageProductDependency` entries). GRDBQuery is linked to the main target.

### Schema Completeness

The v1 migration in AppDatabase.swift creates:
- `raw_samples` with columns: id, interfaceId, timestamp, bytesIn, bytesOut, duration
- Two indexes: `idx_raw_samples_ts` and `idx_raw_samples_iface_ts`
- Five aggregation tier tables (minute/hour/day/week/month_samples) each with: id, interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut, peakBytesInPerSec, peakBytesOutPerSec, sampleCount
- UNIQUE(interfaceId, bucketTimestamp) on all aggregation tables for idempotent INSERT OR REPLACE

### Concurrency Correctness

BandwidthRecorder uses the established project pattern (same as StatusBarController):
- `withObservationTracking` with re-registration via `Task { @MainActor [weak self] in ... }`
- Database writes via `nonisolated static func writeSamples(...)` — runs off main thread
- `processAndWrite()` exposes the write pipeline for direct test injection (no observation loop needed in tests)

### Test Coverage

26 total tests across 4 test files:
- AppDatabaseTests: 7 XCTest (schema, CRUD, UNIQUE, column filtering)
- BandwidthRecorderTests: 6 XCTest (accumulation, multi-interface, partial flush, batching, averaging, empty)
- AggregationEngineTests: 9 Swift Testing (all tier cascades, idempotency, multi-interface, watermark)
- PruningManagerTests: 4 Swift Testing (pruning, preservation, aggregate safety, count return)

---

_Verified: 2026-03-24_
_Verifier: Claude (gsd-verifier)_
