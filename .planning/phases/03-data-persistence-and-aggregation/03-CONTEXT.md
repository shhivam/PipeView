# Phase 3: Data Persistence and Aggregation - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

SQLite storage with tiered aggregation and bounded retention for historical bandwidth data. The app silently records and aggregates all bandwidth data so historical views (Phase 5) can query it efficiently. No UI, no charts, no preferences — just the persistence and aggregation engine.

</domain>

<decisions>
## Implementation Decisions

### Recording Strategy
- **D-01:** Record samples every 10 seconds — accumulate 5 poll cycles (2s each), average them, write one row per interface
- **D-02:** Store per-interface data (not just aggregate) — each raw sample is a row with interface identifier, bytesIn, bytesOut, and timestamp
- **D-03:** Use observer pattern — a `BandwidthRecorder` subscribes to `NetworkMonitor.latestSnapshot` changes, accumulates 5 snapshots, averages, and writes to GRDB. The monitor has no knowledge of the database layer
- **D-04:** GRDB.swift is the SQLite toolkit (per CLAUDE.md stack decisions). Must be added as an SPM dependency — not yet in the Xcode project

### Aggregation Timing
- **D-05:** Periodic background timer for aggregation — a background task rolls up raw → minutes, minutes → hours, hours → days, days → weeks, weeks → months on a schedule
- **D-06:** Cascading tier build — each tier aggregates from the tier below it (minutes from raw, hours from minutes, etc.), not directly from raw samples. Efficient and scalable

### Retention & Pruning
- **D-07:** Raw 10-second samples retained for 24 hours, then pruned
- **D-08:** All aggregated tiers (minute, hour, day, week, month) kept forever — row counts are naturally bounded (365 day-rows/year, 52 week-rows/year, 12 month-rows/year per interface)
- **D-09:** Pruning runs on app launch (catches stale data after days off) plus once per 24 hours while running
- **D-10:** No hard database size limit — retention policy keeps size bounded (well under 50 MB even after years)

### Data Granularity
- **D-11:** Raw samples store total bytes transferred (bytesIn, bytesOut) per 10-second window per interface. Speed derived by dividing by interval at query time
- **D-12:** Aggregated tier records store: totalBytesIn, totalBytesOut (sum), peakBytesInPerSec, peakBytesOutPerSec (max). Average speed derived from total/duration at query time
- **D-13:** Per-interface breakdown preserved at ALL aggregation tiers (minute through month). Enables "Wi-Fi vs Ethernet usage this month" charts in Phase 5

### Claude's Discretion
- Exact GRDB schema design (table names, column types, indexes)
- Aggregation timer intervals (e.g., roll up minutes every 2 min, hours every 60 min)
- How to handle DST/timezone boundaries in aggregation (noted as concern in STATE.md)
- GRDB WAL mode configuration and connection pool setup
- Error handling for failed writes (retry, skip, log)
- How the observer bridges @Observable to the recorder (withObservationTracking, async stream, or callback)
- Database migration strategy for future schema changes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Stack
- `CLAUDE.md` — Full technology stack decisions including GRDB.swift 7.10.0, GRDBQuery 0.11.0, swift-collections, WAL mode recommendations, and alternatives considered

### Requirements
- `.planning/REQUIREMENTS.md` — MON-03 (record samples to SQLite), MON-04 (aggregate to minute/hour/day/week/month), MON-05 (prune old samples, keep aggregates, bounded DB)

### Phase 1 Foundation
- `.planning/phases/01-core-monitoring-engine/01-CONTEXT.md` — D-01/D-02 (2s polling, configurable), D-03 (raw byte delta, no smoothing), D-08 (aggregate computed in engine), D-09 (wake discard)

### Phase 2 Integration
- `.planning/phases/02-menu-bar-display/02-CONTEXT.md` — D-14 (preferences deferred to Phase 5), existing observer pattern (StatusBarController observes NetworkMonitor)

### Known Risks
- `.planning/STATE.md` §Blockers/Concerns — DST/timezone boundary correctness in data aggregation needs explicit test cases; sysctl IFMIB_IFDATA stability; App Sandbox + sysctl compatibility

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkMonitor` (Monitoring/NetworkMonitor.swift): @MainActor @Observable, publishes `latestSnapshot: NetworkSnapshot` with per-interface speeds + aggregate + timestamp. Phase 3 recorder subscribes to this
- `NetworkSnapshot` (Monitoring/NetworkSample.swift): Contains `interfaceSpeeds: [InterfaceSpeed]`, `aggregateSpeed: Speed`, `timestamp: Date` — the exact data structure to persist
- `Speed` struct: `bytesInPerSecond: Double`, `bytesOutPerSecond: Double` — convert to total bytes by multiplying by interval duration
- `InterfaceInfo`: Has `bsdName` (unique key for DB), `displayName`, `type` — interface identifier for per-interface storage
- `Loggers.swift`: Structured os.Logger — add a `.persistence` or `.database` logger category

### Established Patterns
- @MainActor @Observable for SwiftUI-observable state — new recorder may need to be @MainActor to observe NetworkMonitor, but DB writes should happen off main thread
- Sendable value types for data models — database record types should also be Sendable
- Observer pattern already in use: StatusBarController observes NetworkMonitor for menu bar updates — BandwidthRecorder follows the same pattern

### Integration Points
- `BandwidthRecorder` subscribes to `NetworkMonitor.latestSnapshot` — same observation mechanism as StatusBarController
- `AppDelegate.swift` or app initialization must create and wire up the recorder alongside the monitor
- GRDB database file location: Application Support/BandwidthMonitor/ (standard macOS app data directory)
- Phase 4 popover and Phase 5 charts will query the database directly via GRDB/GRDBQuery — this phase must expose a query API

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

*Phase: 03-data-persistence-and-aggregation*
*Context gathered: 2026-03-24*
