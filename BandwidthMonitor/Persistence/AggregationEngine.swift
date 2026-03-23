import Foundation
import GRDB
import os

/// Cascading tier aggregation engine for bandwidth data.
///
/// Rolls up raw 10-second samples into progressively coarser time buckets:
/// raw -> minutes -> hours -> days -> weeks + months.
///
/// All timestamps use UTC Unix epoch. Bucketing is UTC-based to avoid DST issues.
/// Aggregation is idempotent via INSERT OR REPLACE with UNIQUE(interfaceId, bucketTimestamp).
/// A watermark optimization skips already-processed records.
final class AggregationEngine: Sendable {
    private let database: AppDatabase
    private let logger = Logger.persistence

    init(database: AppDatabase) {
        self.database = database
    }

    /// Run all aggregation tiers in cascade order.
    func runFullAggregation() async {
        do {
            try await aggregateRawToMinutes()
            try await aggregateMinutesToHours()
            try await aggregateHoursToDays()
            try await aggregateDaysToWeeks()
            try await aggregateDaysToMonths()
            logger.info("Full aggregation cycle complete")
        } catch {
            logger.error("Aggregation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Raw -> Minutes

    /// Aggregate raw 10-second samples into 1-minute buckets.
    /// Uses floor-division bucketing: CAST(timestamp / 60.0 AS INTEGER) * 60.
    func aggregateRawToMinutes() async throws {
        let watermark = try await getWatermark(table: "minute_samples")
        try await database.dbWriter.write { db in
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

    // MARK: - Minutes -> Hours

    /// Aggregate 1-minute buckets into 1-hour buckets.
    func aggregateMinutesToHours() async throws {
        let watermark = try await getWatermark(table: "hour_samples")
        try await database.dbWriter.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO hour_samples
                    (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
                     peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
                SELECT
                    interfaceId,
                    CAST(CAST(bucketTimestamp / 3600.0 AS INTEGER) * 3600 AS REAL),
                    SUM(totalBytesIn),
                    SUM(totalBytesOut),
                    MAX(peakBytesInPerSec),
                    MAX(peakBytesOutPerSec),
                    SUM(sampleCount)
                FROM minute_samples
                WHERE bucketTimestamp >= ?
                GROUP BY interfaceId, CAST(bucketTimestamp / 3600.0 AS INTEGER)
                """,
                arguments: [watermark]
            )
        }
    }

    // MARK: - Hours -> Days

    /// Aggregate 1-hour buckets into 1-day buckets (midnight UTC boundaries).
    func aggregateHoursToDays() async throws {
        let watermark = try await getWatermark(table: "day_samples")
        try await database.dbWriter.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO day_samples
                    (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
                     peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
                SELECT
                    interfaceId,
                    CAST(CAST(bucketTimestamp / 86400.0 AS INTEGER) * 86400 AS REAL),
                    SUM(totalBytesIn),
                    SUM(totalBytesOut),
                    MAX(peakBytesInPerSec),
                    MAX(peakBytesOutPerSec),
                    SUM(sampleCount)
                FROM hour_samples
                WHERE bucketTimestamp >= ?
                GROUP BY interfaceId, CAST(bucketTimestamp / 86400.0 AS INTEGER)
                """,
                arguments: [watermark]
            )
        }
    }

    // MARK: - Days -> Weeks

    /// Aggregate 1-day buckets into ISO 8601 week buckets (Monday-aligned).
    ///
    /// SQLite strftime('%w') returns 0=Sunday..6=Saturday.
    /// Monday offset: subtract ((day_of_week + 6) % 7) * 86400 from the day's epoch.
    func aggregateDaysToWeeks() async throws {
        let watermark = try await getWatermark(table: "week_samples")
        try await database.dbWriter.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO week_samples
                    (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
                     peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
                SELECT
                    interfaceId,
                    CAST(bucketTimestamp - ((CAST(strftime('%w', bucketTimestamp, 'unixepoch') AS INTEGER) + 6) % 7) * 86400 AS REAL),
                    SUM(totalBytesIn),
                    SUM(totalBytesOut),
                    MAX(peakBytesInPerSec),
                    MAX(peakBytesOutPerSec),
                    SUM(sampleCount)
                FROM day_samples
                WHERE bucketTimestamp >= ?
                GROUP BY interfaceId,
                    CAST(bucketTimestamp - ((CAST(strftime('%w', bucketTimestamp, 'unixepoch') AS INTEGER) + 6) % 7) * 86400 AS REAL)
                """,
                arguments: [watermark]
            )
        }
    }

    // MARK: - Days -> Months

    /// Aggregate 1-day buckets into calendar month buckets (first-of-month UTC).
    ///
    /// Uses strftime('%Y-%m-01') to find the first of the month,
    /// then strftime('%s', ...) to convert back to epoch.
    func aggregateDaysToMonths() async throws {
        let watermark = try await getWatermark(table: "month_samples")
        try await database.dbWriter.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO month_samples
                    (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
                     peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
                SELECT
                    interfaceId,
                    CAST(strftime('%s', strftime('%Y-%m-01', bucketTimestamp, 'unixepoch')) AS REAL),
                    SUM(totalBytesIn),
                    SUM(totalBytesOut),
                    MAX(peakBytesInPerSec),
                    MAX(peakBytesOutPerSec),
                    SUM(sampleCount)
                FROM day_samples
                WHERE bucketTimestamp >= ?
                GROUP BY interfaceId,
                    strftime('%Y-%m', bucketTimestamp, 'unixepoch')
                """,
                arguments: [watermark]
            )
        }
    }

    // MARK: - Watermark

    /// Get the last aggregated bucketTimestamp from a tier table.
    /// Returns 0 if no records exist (process all available data).
    ///
    /// Per research open question #3: derive from MAX(bucketTimestamp),
    /// no separate watermark table needed.
    private func getWatermark(table: String) async throws -> Double {
        try await database.dbWriter.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT MAX(bucketTimestamp) FROM \(table)")
            return row?[0] as? Double ?? 0
        }
    }
}
