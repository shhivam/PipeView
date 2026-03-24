import GRDB
import Foundation
import os

/// Central database manager for the Bandwidth Monitor app.
///
/// Owns the database connection, runs migrations, and provides the shared
/// ``DatabaseWriter`` to all consumers. Production uses ``DatabasePool``
/// (WAL mode for concurrent reads/writes); tests use in-memory ``DatabaseQueue``.
final class AppDatabase: Sendable {
    /// The database connection. Production uses DatabasePool (WAL mode);
    /// tests use DatabaseQueue(path: ":memory:") for speed and isolation.
    let dbWriter: any DatabaseWriter

    init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try Self.migrator.migrate(dbWriter)
    }

    // MARK: - Factory Methods

    /// Production: ~/Library/Application Support/BandwidthMonitor/bandwidth.sqlite
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
        Logger.persistence.info("Opening database at \(dbURL.path)")
        let pool = try DatabasePool(path: dbURL.path)
        return try AppDatabase(pool)
    }

    /// In-memory for tests -- fast, no filesystem cleanup needed.
    /// Uses DatabaseQueue because DatabasePool does not support in-memory databases.
    /// Tests only verify schema and CRUD, which do not require concurrent access.
    static func makeEmpty() throws -> AppDatabase {
        let queue = try DatabaseQueue(path: ":memory:")
        return try AppDatabase(queue)
    }

    // MARK: - Migrations

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1-createSchema") { db in
            // Raw 10-second samples (pruned after 24 hours per D-07)
            try db.create(table: "raw_samples") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("interfaceId", .text).notNull()
                t.column("timestamp", .double).notNull()    // Unix epoch UTC
                t.column("bytesIn", .double).notNull()      // Total bytes received in window
                t.column("bytesOut", .double).notNull()     // Total bytes sent in window
                t.column("duration", .double).notNull()     // Actual elapsed seconds (~10.0)
            }
            try db.create(index: "idx_raw_samples_ts", on: "raw_samples", columns: ["timestamp"])
            try db.create(index: "idx_raw_samples_iface_ts", on: "raw_samples", columns: ["interfaceId", "timestamp"])

            // Aggregation tier tables (kept forever per D-08, identical schema)
            let tierTables = [
                "minute_samples", "hour_samples", "day_samples",
                "week_samples", "month_samples"
            ]
            for tableName in tierTables {
                try db.create(table: tableName) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("interfaceId", .text).notNull()
                    t.column("bucketTimestamp", .double).notNull()  // Start of bucket (UTC epoch)
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

// MARK: - Chart & Statistics Queries

extension AppDatabase {

    /// Fetches chart data points for a given aggregation tier, summed across all interfaces.
    /// Returns points sorted by timestamp ASC.
    func fetchChartData(tier: AggregationTier, since: Date) throws -> [ChartDataPoint] {
        // Stub: returns empty to fail tests
        return []
    }

    /// Fetches cumulative bytes (in + out) from hour_samples since the given date.
    /// Uses hour_samples for partial-day accuracy (more current than day_samples).
    func fetchCumulativeStats(since: Date) throws -> (totalIn: Double, totalOut: Double) {
        // Stub: returns zeroes to fail tests
        return (0, 0)
    }
}
