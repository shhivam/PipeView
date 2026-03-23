# Phase 3: Data Persistence and Aggregation - Research

**Researched:** 2026-03-24
**Domain:** SQLite persistence with GRDB.swift, time-series aggregation, tiered rollup architecture
**Confidence:** HIGH

## Summary

Phase 3 adds the data persistence layer to the bandwidth monitor: a GRDB.swift-backed SQLite database that records per-interface bandwidth samples every 10 seconds, cascades them through minute/hour/day/week/month aggregation tiers, and prunes raw data after 24 hours while keeping aggregates indefinitely. The architecture uses a `BandwidthRecorder` that observes `NetworkMonitor.latestSnapshot` (the same observation pattern `StatusBarController` already uses), accumulates 5 poll cycles (10 seconds at 2s polling), averages them, and writes one row per interface to the database. A separate background aggregation task periodically rolls up data from each tier into the next. All database writes happen off the main thread via GRDB's `DatabasePool`, which automatically enables WAL mode for concurrent reads and writes.

The core stack is GRDB.swift 7.10.0 (DatabasePool with WAL mode) and GRDBQuery 0.11.0 (for Phase 5 SwiftUI integration). GRDB must be added as an SPM dependency -- it is not yet in the Xcode project (only swift-collections is currently configured). The schema uses 6 tables: one for raw samples and five for aggregation tiers (minute, hour, day, week, month), all with per-interface granularity. Timestamps are stored as Unix epoch doubles (TimeInterval) in UTC to avoid timezone/DST issues in aggregation.

**Primary recommendation:** Use `DatabasePool` (not `DatabaseQueue`) for concurrent read/write access. Store all timestamps as UTC Unix epoch `Double` values. Use GRDB's `DatabaseMigrator` for schema setup. Bridge `NetworkMonitor` observation to the recorder via the `withObservationTracking` + `AsyncStream` pattern (the `Observations` type requires macOS 26 which is not available). Batch all writes within single transactions.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Record samples every 10 seconds -- accumulate 5 poll cycles (2s each), average them, write one row per interface
- **D-02:** Store per-interface data (not just aggregate) -- each raw sample is a row with interface identifier, bytesIn, bytesOut, and timestamp
- **D-03:** Use observer pattern -- a `BandwidthRecorder` subscribes to `NetworkMonitor.latestSnapshot` changes, accumulates 5 snapshots, averages, and writes to GRDB. The monitor has no knowledge of the database layer
- **D-04:** GRDB.swift is the SQLite toolkit (per CLAUDE.md stack decisions). Must be added as an SPM dependency -- not yet in the Xcode project
- **D-05:** Periodic background timer for aggregation -- a background task rolls up raw -> minutes, minutes -> hours, hours -> days, days -> weeks, weeks -> months on a schedule
- **D-06:** Cascading tier build -- each tier aggregates from the tier below it (minutes from raw, hours from minutes, etc.), not directly from raw samples
- **D-07:** Raw 10-second samples retained for 24 hours, then pruned
- **D-08:** All aggregated tiers (minute, hour, day, week, month) kept forever -- row counts are naturally bounded
- **D-09:** Pruning runs on app launch (catches stale data after days off) plus once per 24 hours while running
- **D-10:** No hard database size limit -- retention policy keeps size bounded (well under 50 MB even after years)
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

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MON-03 | App records bandwidth samples to SQLite at regular intervals | BandwidthRecorder observes NetworkMonitor every poll cycle, accumulates 5 samples (10s), writes via DatabasePool. Schema design, GRDB record types, and write patterns documented below. |
| MON-04 | App aggregates raw samples into minute, hour, day, week, month granularity tiers | Cascading aggregation with 5 tier tables. SQL GROUP BY with floor-based epoch bucketing. Timer-driven background rollup. Patterns and SQL examples documented below. |
| MON-05 | App prunes old raw samples while preserving aggregated data to keep database bounded | DELETE with timestamp filter on raw_samples table. Runs on launch + every 24h. GRDB deleteAll with filter pattern documented. Aggregated tiers kept forever (naturally bounded). |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** macOS only, native Swift, no cross-platform frameworks
- **Data storage:** SQLite, simple, local, no server
- **Architecture:** Modular and debuggable -- clear separation between monitoring, storage, and UI layers
- **GRDB.swift 7.10.0** is the mandated SQLite toolkit (not SwiftData, not SQLite.swift, not Core Data)
- **GRDBQuery 0.11.0** for SwiftUI database observation (Phase 5 will use this)
- **Swift 6 strict concurrency** -- all model types must be Sendable
- **Structured concurrency** -- use Task.sleep, not DispatchSourceTimer
- **DatabasePool** preferred for WAL concurrent reads/writes (CLAUDE.md recommends WAL mode)
- **Application Support/BandwidthMonitor/** for database file location
- Do NOT use SwiftData, Core Data, or SQLite.swift
- Do NOT use DispatchSourceTimer -- use structured concurrency throughout
- Do NOT use CocoaPods/Carthage -- SPM only

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GRDB.swift | 7.10.0 | SQLite database access, migrations, WAL pool, record types | CLAUDE.md mandated. Type-safe queries, schema migrations, WAL mode for concurrent reads/writes. Confirmed current on GitHub releases (Feb 2026). |
| GRDBQuery | 0.11.0 | SwiftUI @Query property wrapper for GRDB | CLAUDE.md mandated. Not directly used in Phase 3 but must be added now so Phase 5 can use it. Companion to GRDB. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-collections | 1.4.1 (already installed) | Deque for in-memory sample accumulation buffer | Use Deque in BandwidthRecorder to buffer 5 poll-cycle snapshots before averaging and writing |
| Foundation (FileManager) | System | Application Support directory resolution | Database file path creation at ~/Library/Application Support/BandwidthMonitor/bandwidth.sqlite |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DatabasePool | DatabaseQueue | DatabaseQueue is simpler but single-threaded. DatabasePool enables concurrent reads during writes -- critical since Phase 5 charts will query while Phase 3 writes. Use DatabasePool. |
| Unix epoch Double | ISO-8601 TEXT | TEXT is human-readable in DB browsers but slower for range queries and aggregation math. Unix epoch enables direct arithmetic (floor division for bucketing). Use Double. |
| Separate tier tables | Single table with tier column | Single table gets large and requires compound indexes. Separate tables have natural partitioning, simpler queries, and independent vacuum behavior. Use separate tables. |

**Installation (add to Xcode project via SPM):**
```
Package URL: https://github.com/groue/GRDB.swift
  Version: 7.10.0 (Up to Next Major)
Package URL: https://github.com/groue/GRDBQuery
  Version: 0.11.0 (Up to Next Major)
```

**Version verification:**
- GRDB.swift 7.10.0: Released Feb 15, 2026. Requires Swift 6.1+, Xcode 16.3+, macOS 10.15+. Compatible with current environment (Xcode 16.4, Swift 6.1.2).
- GRDBQuery 0.11.0: Released Mar 15, 2025. Requires Swift 6+, Xcode 16+, macOS 11+. Compatible.
- swift-collections 1.4.1: Already resolved in project.

## Architecture Patterns

### Recommended Project Structure
```
BandwidthMonitor/
├── Persistence/
│   ├── AppDatabase.swift          # DatabasePool setup, migrations, shared instance
│   ├── Models/
│   │   ├── RawSample.swift        # GRDB record for raw 10-second samples
│   │   └── AggregatedSample.swift # GRDB record for all aggregation tiers
│   ├── BandwidthRecorder.swift    # Observes NetworkMonitor, accumulates, writes
│   ├── AggregationEngine.swift    # Cascading tier rollup logic
│   └── PruningManager.swift       # Raw sample cleanup
├── Monitoring/                     # (existing Phase 1 code)
├── MenuBar/                        # (existing Phase 2 code)
└── Logging/
    └── Loggers.swift               # Add .persistence logger category
```

### Pattern 1: AppDatabase Singleton
**What:** A single `AppDatabase` class that owns the `DatabasePool`, runs migrations, and provides the shared database writer/reader to all consumers.
**When to use:** Always -- single point of database lifecycle management.
**Example:**
```swift
// Source: GRDB.swift README + official patterns
import GRDB

final class AppDatabase: Sendable {
    /// The DatabasePool grants concurrent reads/writes via WAL mode
    let pool: DatabasePool

    init(_ pool: DatabasePool) throws {
        self.pool = pool
        try migrator.migrate(pool)
    }

    /// Standard location: ~/Library/Application Support/BandwidthMonitor/
    static func makeDefault() throws -> AppDatabase {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent(
            "BandwidthMonitor",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let dbURL = directoryURL.appendingPathComponent("bandwidth.sqlite")
        let pool = try DatabasePool(path: dbURL.path)
        return try AppDatabase(pool)
    }

    /// In-memory database for testing
    static func makeEmpty() throws -> AppDatabase {
        let pool = try DatabasePool(path: ":memory:")
        return try AppDatabase(pool)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("v1-createSchema") { db in
            // ... table creation (see Schema section below)
        }
        return migrator
    }
}
```

### Pattern 2: Observer -> Accumulator -> Writer Pipeline
**What:** `BandwidthRecorder` observes `NetworkMonitor.latestSnapshot` via `withObservationTracking` wrapped in an `AsyncStream`, accumulates 5 snapshots in a `Deque`, averages them, and writes to the database off the main thread.
**When to use:** This is the core data ingestion pipeline.
**Why withObservationTracking + AsyncStream:** The `Observations` type from Swift 6.2 requires macOS 26 (not available). `withObservationTracking` works on macOS 14+ with Swift 5.9+. The `StatusBarController` already uses `withObservationTracking` directly -- `BandwidthRecorder` wraps it in an AsyncStream so it can await changes in a structured concurrency loop.
**Example:**
```swift
@MainActor
final class BandwidthRecorder {
    private let networkMonitor: NetworkMonitor
    private let database: AppDatabase
    private var recordingTask: Task<Void, Never>?
    private let logger = Logger.persistence

    func start() {
        recordingTask = Task { [weak self] in
            guard let self else { return }
            var buffer: [NetworkSnapshot] = []

            // Create async stream of snapshot changes
            let snapshots = AsyncStream<NetworkSnapshot> { continuation in
                @Sendable func observe() {
                    let snapshot = withObservationTracking {
                        self.networkMonitor.latestSnapshot
                    } onChange: {
                        Task { @MainActor in
                            observe()
                        }
                    }
                    continuation.yield(snapshot)
                }
                observe()
            }

            for await snapshot in snapshots {
                guard !Task.isCancelled else { break }
                buffer.append(snapshot)

                if buffer.count >= 5 {
                    let samples = buffer
                    buffer.removeAll()
                    // Write off main thread
                    await self.writeSamples(from: samples)
                }
            }
        }
    }

    private nonisolated func writeSamples(from snapshots: [NetworkSnapshot]) async {
        // Average the 5 snapshots, write one RawSample per interface
        // Use database.pool.write { db in ... }
    }
}
```

### Pattern 3: Cascading Tier Aggregation via SQL
**What:** Each aggregation tier is built from the tier directly below it using SQL GROUP BY with floor-based epoch bucketing. Minutes from raw samples, hours from minutes, etc.
**When to use:** On a periodic timer (aggregation schedule).
**Example SQL pattern:**
```sql
-- Roll up raw samples into minute buckets
INSERT OR REPLACE INTO minute_samples
    (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
     peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
SELECT
    interfaceId,
    CAST(CAST(timestamp / 60 AS INTEGER) * 60 AS REAL) AS bucketTimestamp,
    SUM(bytesIn) AS totalBytesIn,
    SUM(bytesOut) AS totalBytesOut,
    MAX(bytesIn / duration) AS peakBytesInPerSec,
    MAX(bytesOut / duration) AS peakBytesOutPerSec,
    COUNT(*) AS sampleCount
FROM raw_samples
WHERE timestamp >= ?  -- only unprocessed samples
GROUP BY interfaceId, CAST(timestamp / 60 AS INTEGER)
```

### Pattern 4: GRDB Record Types with Codable
**What:** Database record types conforming to `Codable`, `FetchableRecord`, `PersistableRecord` for type-safe CRUD.
**When to use:** All database models.
**Example:**
```swift
struct RawSample: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "raw_samples"

    var id: Int64?
    var interfaceId: String    // BSD name (e.g., "en0")
    var timestamp: Double      // Unix epoch (UTC)
    var bytesIn: Double        // Total bytes received in this 10s window
    var bytesOut: Double       // Total bytes sent in this 10s window
    var duration: Double       // Actual elapsed seconds (close to 10.0)

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // Column enum for type-safe queries
    enum Columns {
        static let interfaceId = Column(CodingKeys.interfaceId)
        static let timestamp = Column(CodingKeys.timestamp)
        static let bytesIn = Column(CodingKeys.bytesIn)
        static let bytesOut = Column(CodingKeys.bytesOut)
    }
}

struct AggregatedSample: Codable, FetchableRecord, PersistableRecord, Sendable {
    static var databaseTableName: String { _tableName }
    let _tableName: String  // Set per-tier: "minute_samples", "hour_samples", etc.

    var id: Int64?
    var interfaceId: String
    var bucketTimestamp: Double  // Start of the time bucket (UTC epoch)
    var totalBytesIn: Double
    var totalBytesOut: Double
    var peakBytesInPerSec: Double
    var peakBytesOutPerSec: Double
    var sampleCount: Int
}
```

**Note on AggregatedSample:** GRDB's `databaseTableName` is a static property. For multiple tier tables with the same structure, use separate concrete types (`MinuteSample`, `HourSample`, etc.) each with their own `databaseTableName`, or use raw SQL for cross-tier operations. Separate types are cleaner and avoid the dynamic table name issue.

### Recommended Schema Design

```sql
-- Raw 10-second samples (pruned after 24 hours)
CREATE TABLE raw_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    interfaceId TEXT NOT NULL,       -- BSD name (en0, en1, utun3)
    timestamp REAL NOT NULL,         -- Unix epoch seconds (UTC)
    bytesIn REAL NOT NULL,           -- Total bytes received in window
    bytesOut REAL NOT NULL,          -- Total bytes sent in window
    duration REAL NOT NULL           -- Actual elapsed seconds (~10.0)
);
CREATE INDEX idx_raw_samples_ts ON raw_samples(timestamp);
CREATE INDEX idx_raw_samples_iface_ts ON raw_samples(interfaceId, timestamp);

-- Minute aggregation (kept forever, ~525,600 rows/year/interface)
CREATE TABLE minute_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    interfaceId TEXT NOT NULL,
    bucketTimestamp REAL NOT NULL,    -- Start of minute (UTC epoch)
    totalBytesIn REAL NOT NULL,
    totalBytesOut REAL NOT NULL,
    peakBytesInPerSec REAL NOT NULL,
    peakBytesOutPerSec REAL NOT NULL,
    sampleCount INTEGER NOT NULL,
    UNIQUE(interfaceId, bucketTimestamp)
);

-- Hour aggregation (kept forever, ~8,760 rows/year/interface)
CREATE TABLE hour_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    interfaceId TEXT NOT NULL,
    bucketTimestamp REAL NOT NULL,
    totalBytesIn REAL NOT NULL,
    totalBytesOut REAL NOT NULL,
    peakBytesInPerSec REAL NOT NULL,
    peakBytesOutPerSec REAL NOT NULL,
    sampleCount INTEGER NOT NULL,
    UNIQUE(interfaceId, bucketTimestamp)
);

-- Day aggregation (kept forever, ~365 rows/year/interface)
CREATE TABLE day_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    interfaceId TEXT NOT NULL,
    bucketTimestamp REAL NOT NULL,
    totalBytesIn REAL NOT NULL,
    totalBytesOut REAL NOT NULL,
    peakBytesInPerSec REAL NOT NULL,
    peakBytesOutPerSec REAL NOT NULL,
    sampleCount INTEGER NOT NULL,
    UNIQUE(interfaceId, bucketTimestamp)
);

-- Week aggregation (kept forever, ~52 rows/year/interface)
CREATE TABLE week_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    interfaceId TEXT NOT NULL,
    bucketTimestamp REAL NOT NULL,
    totalBytesIn REAL NOT NULL,
    totalBytesOut REAL NOT NULL,
    peakBytesInPerSec REAL NOT NULL,
    peakBytesOutPerSec REAL NOT NULL,
    sampleCount INTEGER NOT NULL,
    UNIQUE(interfaceId, bucketTimestamp)
);

-- Month aggregation (kept forever, 12 rows/year/interface)
CREATE TABLE month_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    interfaceId TEXT NOT NULL,
    bucketTimestamp REAL NOT NULL,
    totalBytesIn REAL NOT NULL,
    totalBytesOut REAL NOT NULL,
    peakBytesInPerSec REAL NOT NULL,
    peakBytesOutPerSec REAL NOT NULL,
    sampleCount INTEGER NOT NULL,
    UNIQUE(interfaceId, bucketTimestamp)
);
```

**Key schema decisions:**
- `UNIQUE(interfaceId, bucketTimestamp)` on each aggregation table enables `INSERT OR REPLACE` for idempotent re-aggregation
- `timestamp REAL` stores Unix epoch as Double for efficient range queries and arithmetic bucketing
- `duration` column on raw_samples preserves actual measurement interval (may drift slightly from 10.0s)
- All aggregation tables share the same column structure -- use one Swift protocol/base type
- No foreign keys between tables (aggregation is a batch process, not a relational join)

### Anti-Patterns to Avoid
- **Storing timestamps as ISO-8601 TEXT:** Prevents efficient arithmetic bucketing. Use Unix epoch Double instead.
- **Writing to database on every 2s poll cycle:** Excessive I/O. Accumulate 5 cycles (10s) per D-01.
- **Aggregating all tiers from raw data:** Does not scale. Use cascading aggregation per D-06.
- **Using DatabaseQueue instead of DatabasePool:** Single-threaded access will block Phase 5 chart reads during writes.
- **Dynamic table names in GRDB record types:** `databaseTableName` is static. Use separate record types per tier.
- **Blocking the main thread with database writes:** Use `nonisolated func` or detached tasks for DB operations.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite connection management | Custom SQLite3 C API wrapper | GRDB.swift DatabasePool | Thread safety, WAL mode, connection pooling, memory management all handled |
| Schema versioning | Manual CREATE TABLE IF NOT EXISTS | GRDB DatabaseMigrator | Guarantees migrations run in order, once only, with transaction safety |
| Record serialization | Manual column-to-property mapping | GRDB Codable + FetchableRecord | Automatic mapping, type safety, compile-time checks |
| Concurrent read/write safety | Manual dispatch queues + locks | GRDB DatabasePool (WAL) | Proven concurrent access pattern, handles SQLite BUSY retries |
| Reactive database observation | Manual polling or NotificationCenter | GRDB ValueObservation / GRDBQuery | Automatic change detection, coalesced notifications, SwiftUI integration |

**Key insight:** GRDB provides a complete database lifecycle from creation through migration through concurrent access through reactive observation. Every piece of custom database plumbing you write is a bug waiting to happen.

## Common Pitfalls

### Pitfall 1: Main Thread Database Writes
**What goes wrong:** Writing to the database from `@MainActor` context blocks UI updates and causes hitches in the menu bar speed display.
**Why it happens:** `BandwidthRecorder` is `@MainActor` (to observe `NetworkMonitor`), and a naive implementation calls `pool.write` directly from there.
**How to avoid:** Collect data on the main actor, then hand off to a `nonisolated` function or `Task.detached` for the actual `pool.write` call. GRDB's `DatabasePool.write` is synchronous and blocking -- always call it off the main thread.
**Warning signs:** Menu bar text freezes momentarily every 10 seconds.

### Pitfall 2: Missing Aggregation Idempotency
**What goes wrong:** Running aggregation twice for the same time period doubles the byte counts.
**Why it happens:** Using `INSERT` instead of `INSERT OR REPLACE` (or GRDB's `save()` with UNIQUE constraint).
**How to avoid:** The `UNIQUE(interfaceId, bucketTimestamp)` constraint on aggregation tables plus `INSERT OR REPLACE` semantics ensures re-running aggregation is safe. Track a "last aggregated timestamp" watermark per tier to avoid unnecessary re-processing.
**Warning signs:** Aggregated totals grow faster than raw sample totals.

### Pitfall 3: Timezone/DST Boundary Errors in Aggregation
**What goes wrong:** A "day" bucket starting at midnight local time shifts by 1 hour during DST transitions, causing samples to fall into the wrong bucket or creating 23/25-hour days.
**Why it happens:** Using local time for bucket boundaries.
**How to avoid:** Store ALL timestamps as UTC Unix epoch. Perform all aggregation bucketing in UTC (floor division by bucket size in seconds). Convert to local time ONLY at display time in Phase 5. Day boundaries are midnight UTC, not midnight local. This is simpler and correct -- users care about "usage in the last 24 hours," not "usage since midnight in my timezone."
**Warning signs:** Gaps or overlaps in aggregated data around DST transition dates.

### Pitfall 4: Database File Not Created (Missing Directory)
**What goes wrong:** `DatabasePool(path:)` throws because the parent directory does not exist.
**Why it happens:** Application Support/BandwidthMonitor/ directory is not created before opening the database.
**How to avoid:** Call `FileManager.createDirectory(withIntermediateDirectories: true)` before opening the pool.
**Warning signs:** Crash on first launch with a file-not-found error.

### Pitfall 5: Accumulation Buffer Losing Data on App Quit
**What goes wrong:** The app terminates with 1-4 accumulated snapshots in the buffer that never get written.
**Why it happens:** Buffer requires 5 snapshots before writing, and `applicationWillTerminate` does not flush the buffer.
**How to avoid:** In `applicationWillTerminate`, call `recorder.flush()` to write whatever is in the buffer (even if < 5 snapshots). Adjust `duration` field accordingly.
**Warning signs:** Last few seconds of data before quit are always missing.

### Pitfall 6: WAL Checkpoint Starvation
**What goes wrong:** The WAL file grows unboundedly because no checkpoints occur.
**Why it happens:** SQLite auto-checkpoints after 1000 WAL pages by default, but if the app only writes small amounts, this threshold may never be reached during normal operation, or the auto-checkpoint might be inhibited by concurrent readers.
**How to avoid:** GRDB's `DatabasePool` handles checkpointing automatically. Do not override the default behavior. If concerned, you can call `pool.writeWithoutTransaction { db in try db.checkpoint(.truncate) }` during pruning (which is already a quiet period).
**Warning signs:** WAL file grows to several MB over days of operation.

### Pitfall 7: Counter Overflow in Long-Running Aggregation
**What goes wrong:** Summing `totalBytesIn` across months exceeds `Int64` range (9.2 exabytes -- unlikely but possible with `Double` precision loss).
**Why it happens:** Using integer types for cumulative byte counts.
**How to avoid:** Use `REAL` (Double) for all byte count columns. Double can represent values up to 2^53 with integer precision (9 petabytes), which is sufficient for any realistic bandwidth scenario. Already specified in schema design above.
**Warning signs:** N/A (theoretical concern, mitigated by schema choice).

## Code Examples

### Database Setup with Migrations
```swift
// Source: GRDB.swift README + DatabaseMigrator docs
import GRDB

final class AppDatabase: Sendable {
    let pool: DatabasePool

    init(_ pool: DatabasePool) throws {
        self.pool = pool
        try Self.migrator.migrate(pool)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1-createSchema") { db in
            // Raw samples table
            try db.create(table: "raw_samples") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("interfaceId", .text).notNull()
                t.column("timestamp", .double).notNull()
                t.column("bytesIn", .double).notNull()
                t.column("bytesOut", .double).notNull()
                t.column("duration", .double).notNull()
            }
            try db.create(
                index: "idx_raw_samples_ts",
                on: "raw_samples",
                columns: ["timestamp"]
            )
            try db.create(
                index: "idx_raw_samples_iface_ts",
                on: "raw_samples",
                columns: ["interfaceId", "timestamp"]
            )

            // Helper to create aggregation tier tables (identical schema)
            let tierTables = [
                "minute_samples", "hour_samples", "day_samples",
                "week_samples", "month_samples"
            ]
            for tableName in tierTables {
                try db.create(table: tableName) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("interfaceId", .text).notNull()
                    t.column("bucketTimestamp", .double).notNull()
                    t.column("totalBytesIn", .double).notNull()
                    t.column("totalBytesOut", .double).notNull()
                    t.column("peakBytesInPerSec", .double).notNull()
                    t.column("peakBytesOutPerSec", .double).notNull()
                    t.column("sampleCount", .integer).notNull()
                    t.uniqueKey(["interfaceId", "bucketTimestamp"])
                }
            }
        }

        return migrator
    }
}
```

### Pruning Old Raw Samples
```swift
// Source: GRDB.swift filter + deleteAll pattern
extension AppDatabase {
    func pruneOldSamples() async throws {
        let cutoff = Date().timeIntervalSince1970 - (24 * 60 * 60) // 24 hours ago
        try await pool.write { db in
            let count = try RawSample
                .filter(RawSample.Columns.timestamp < cutoff)
                .deleteAll(db)
            Logger.persistence.info("Pruned \(count) raw samples older than 24h")
        }
    }
}
```

### Batch Insert in Transaction
```swift
// Source: GRDB.swift batch insert best practices
func writeRawSamples(_ samples: [RawSample]) async throws {
    try await database.pool.write { db in
        for var sample in samples {
            try sample.insert(db)
        }
    }
    // pool.write wraps everything in a single transaction automatically
}
```

### Aggregation Query (Raw -> Minutes)
```swift
// Source: SQLite GROUP BY + GRDB raw SQL execution
func aggregateRawToMinutes(since watermark: Double) async throws {
    try await database.pool.write { db in
        try db.execute(sql: """
            INSERT OR REPLACE INTO minute_samples
                (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
                 peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
            SELECT
                interfaceId,
                CAST(CAST(timestamp / 60.0 AS INTEGER) * 60 AS REAL),
                SUM(bytesIn),
                SUM(bytesOut),
                MAX(bytesIn / duration),
                MAX(bytesOut / duration),
                COUNT(*)
            FROM raw_samples
            WHERE timestamp >= ?
            GROUP BY interfaceId, CAST(timestamp / 60.0 AS INTEGER)
            """,
            arguments: [watermark]
        )
    }
}
```

### withObservationTracking AsyncStream Bridge
```swift
// Source: nilcoalescing.com/blog/AsyncStreamFromWithObservationTrackingFunc
@MainActor
func snapshotStream(from monitor: NetworkMonitor) -> AsyncStream<NetworkSnapshot> {
    AsyncStream { continuation in
        @Sendable func observe() {
            let snapshot = withObservationTracking {
                monitor.latestSnapshot
            } onChange: {
                DispatchQueue.main.async {
                    observe()
                }
            }
            continuation.yield(snapshot)
        }
        observe()
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DatabaseQueue (serial) | DatabasePool (WAL concurrent) | GRDB 2.0+ | Concurrent reads during writes -- essential for responsive chart queries |
| ObservableObject + @Published | @Observable (Observation framework) | Swift 5.9 / macOS 14 | Simpler state management, less boilerplate; used by NetworkMonitor already |
| withObservationTracking (manual re-register) | Observations AsyncSequence | Swift 6.2 / macOS 26 | Cleaner async observation -- BUT requires macOS 26 which is not available. Use withObservationTracking for now. |
| GCD DispatchSourceTimer | Task.sleep(for:tolerance:) | Swift 5.7+ | Structured concurrency; already used in NetworkMonitor polling loop |
| Manual SQL string building | GRDB query interface + Codable records | GRDB 2.0+ | Type-safe queries, compile-time checked column names |

**Deprecated/outdated:**
- `Observations` type: Available in Swift 6.2 but requires macOS 26 (not yet shipping). Do NOT use -- stick with `withObservationTracking` + AsyncStream.
- `setupMemoryManagement(in:)` on DatabaseQueue: This is an iOS-specific API for handling memory warnings. Not needed on macOS.

## Open Questions

1. **Week boundary definition**
   - What we know: UTC-based aggregation means weeks start on a fixed day. ISO 8601 defines weeks starting on Monday.
   - What's unclear: Should weeks align to ISO 8601 Monday starts, or to the calendar week of the user's locale?
   - Recommendation: Use ISO 8601 (Monday-start) for consistency. The week start day is a display concern for Phase 5, not a storage concern. Store bucketTimestamp as the UTC epoch of the Monday 00:00:00 of that week.

2. **Month boundary precision**
   - What we know: Months have variable lengths (28-31 days). Floor-division bucketing (used for seconds/minutes/hours/days) does not work for months.
   - What's unclear: Exact SQL for month bucketing with variable-length months.
   - Recommendation: Use `strftime('%Y-%m-01', timestamp, 'unixepoch')` to get the first day of the month, then convert back to epoch. This handles variable month lengths correctly.

3. **Aggregation watermark persistence**
   - What we know: Need to track "last aggregated timestamp" per tier to avoid re-processing all data.
   - What's unclear: Where to store the watermark -- in a separate table or derived from the last bucketTimestamp in each tier table?
   - Recommendation: Derive from `MAX(bucketTimestamp)` in each tier table. No separate tracking table needed. The `UNIQUE + INSERT OR REPLACE` makes re-processing idempotent anyway -- the watermark is just an optimization.

4. **Exact aggregation timer intervals**
   - What we know: Must be periodic (D-05), cascading (D-06).
   - What's unclear: Optimal frequency for each tier rollup.
   - Recommendation: Minutes every 2 minutes, hours every 15 minutes, days every 60 minutes, weeks/months every 6 hours. More frequent for lower tiers (data arrives faster), less frequent for higher tiers (fewer rows, less urgency).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build system | Yes | 16.4 | -- |
| Swift | Language | Yes | 6.1.2 | -- |
| macOS SDK | Target platform | Yes | 15.0 | -- |
| GRDB.swift | Database layer | No (not yet added) | -- | Must be added via SPM (7.10.0) |
| GRDBQuery | Phase 5 SwiftUI queries | No (not yet added) | -- | Must be added via SPM (0.11.0) |
| swift-collections | Deque buffer | Yes | 1.4.1 | -- |
| SQLite | Underlying DB engine | Yes (system) | 3.x (bundled with macOS) | -- |

**Missing dependencies with no fallback:**
- GRDB.swift 7.10.0 -- must be added as SPM dependency before any Phase 3 code can compile
- GRDBQuery 0.11.0 -- should be added alongside GRDB to avoid a second SPM change in Phase 5

**Missing dependencies with fallback:**
- None

**Environment note:** CLAUDE.md references Xcode 26.3 and Swift 6.2, but the actual environment has Xcode 16.4 and Swift 6.1.2. GRDB 7.10.0 is compatible with Swift 6.1+ and Xcode 16.3+, so this is fine. The `Observations` type (Swift 6.2, macOS 26) is NOT available -- use `withObservationTracking` + AsyncStream instead.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode 16.4) |
| Config file | BandwidthMonitor.xcodeproj (test target: BandwidthMonitorTests) |
| Quick run command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -quiet` |
| Full suite command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MON-03 | Raw samples written to SQLite every 10s | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/BandwidthRecorderTests -quiet` | No -- Wave 0 |
| MON-03 | Database setup, migrations, table creation | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AppDatabaseTests -quiet` | No -- Wave 0 |
| MON-04 | Raw -> minute aggregation produces correct sums/peaks | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AggregationEngineTests -quiet` | No -- Wave 0 |
| MON-04 | Cascading aggregation (minute->hour->day->week->month) | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AggregationEngineTests -quiet` | No -- Wave 0 |
| MON-04 | Aggregation idempotency (re-running does not duplicate) | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AggregationEngineTests -quiet` | No -- Wave 0 |
| MON-05 | Pruning deletes raw samples older than 24h | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/PruningManagerTests -quiet` | No -- Wave 0 |
| MON-05 | Pruning preserves aggregated data | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/PruningManagerTests -quiet` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -quiet`
- **Per wave merge:** Full suite including existing Phase 1+2 tests
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `BandwidthMonitorTests/AppDatabaseTests.swift` -- covers MON-03 (database creation, migration, table verification)
- [ ] `BandwidthMonitorTests/BandwidthRecorderTests.swift` -- covers MON-03 (sample accumulation and writing)
- [ ] `BandwidthMonitorTests/AggregationEngineTests.swift` -- covers MON-04 (all tier rollups, idempotency)
- [ ] `BandwidthMonitorTests/PruningManagerTests.swift` -- covers MON-05 (raw pruning, aggregate preservation)
- [ ] GRDB.swift SPM dependency added to test target (BandwidthMonitorTests must link GRDB)
- [ ] Use in-memory `DatabaseQueue` for tests (faster than file-based, no cleanup needed)

**Testing strategy note:** All persistence tests should use an in-memory database via `DatabaseQueue(path: ":memory:")` for speed and isolation. DatabaseQueue (not DatabasePool) is recommended for in-memory test databases because DatabasePool does not support in-memory databases. Tests can insert known data, run aggregation/pruning, and verify results without touching the filesystem.

## Sources

### Primary (HIGH confidence)
- [GRDB.swift GitHub](https://github.com/groue/GRDB.swift) -- v7.10.0, DatabasePool, WAL mode, record types, migrations, query interface. Version confirmed Feb 2026.
- [GRDB.swift README](https://github.com/groue/GRDB.swift/blob/master/README.md) -- DatabaseQueue vs DatabasePool, Codable records, ValueObservation, Configuration
- [GRDBQuery GitHub](https://github.com/groue/GRDBQuery) -- v0.11.0, @Query property wrapper for SwiftUI
- [GRDB DatabaseMigrator source](https://github.com/groue/GRDB.swift/blob/master/GRDB/Migration/DatabaseMigrator.swift) -- Migration registration API
- [Apple: FileManager.applicationSupportDirectory](https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory/applicationsupportdirectory) -- Standard macOS database location
- [SQLite Date Functions](https://sqlite.org/lang_datefunc.html) -- strftime for month/week bucketing
- Existing codebase: NetworkMonitor.swift, NetworkSample.swift, StatusBarController.swift, AppDelegate.swift, Loggers.swift

### Secondary (MEDIUM confidence)
- [AsyncStream from withObservationTracking](https://nilcoalescing.com/blog/AsyncStreamFromWithObservationTrackingFunc/) -- Verified pattern for @Observable async observation
- [GRDB batch insert performance](https://github.com/groue/GRDB.swift/issues/1004) -- Transaction wrapping for bulk inserts
- [GRDB index creation](https://github.com/groue/GRDB.swift/issues/1623) -- db.create(index:) API, .indexed(), .uniqueKey()
- [SQLite time series best practices](https://moldstud.com/articles/p-handling-time-series-data-in-sqlite-best-practices) -- UTC storage, epoch timestamps, indexing strategies
- [SQLite timestamps and timezones](https://www.tinybird.co/blog/database-timestamps-timezones) -- UTC-first approach validation
- [GRDB.swift getting started](https://dev.to/elliotekj/sqlite-and-ios-getting-started-with-grdb-5bd2) -- Migration patterns, record types, query examples

### Tertiary (LOW confidence)
- [Swift 6.2 Observations type](https://www.donnywals.com/using-observations-to-observe-observable-model-properties/) -- Confirmed requires macOS 26, not usable in current environment. Validated against multiple sources.
- [GRDB WAL checkpoint behavior](https://github.com/groue/GRDB.swift/discussions/1516) -- DatabasePool auto-checkpoint behavior

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- GRDB.swift 7.10.0 and GRDBQuery 0.11.0 are mandated by CLAUDE.md, versions verified against GitHub releases, compatibility with Xcode 16.4/Swift 6.1.2 confirmed
- Architecture: HIGH -- Observer pattern matches existing StatusBarController pattern; DatabasePool WAL is the documented GRDB recommendation for concurrent access; cascading aggregation is standard time-series practice
- Schema design: HIGH -- Standard time-series bucketing with UTC epoch timestamps; UNIQUE constraints for idempotent aggregation; separate tables per tier for clean partitioning
- Pitfalls: HIGH -- Main thread blocking, DST boundaries, and idempotency issues are well-documented in SQLite/GRDB community
- Observation bridge: MEDIUM -- withObservationTracking + AsyncStream pattern is verified from multiple sources but the exact integration with @MainActor BandwidthRecorder may need adjustment during implementation

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (30 days -- stable libraries, no breaking changes expected)
