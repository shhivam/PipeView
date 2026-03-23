import Foundation
import GRDB
import os

/// Manages raw sample retention by deleting old records.
///
/// Per D-07: Raw 10-second samples are retained for 24 hours then pruned.
/// Per D-08: All aggregated tier data (minute/hour/day/week/month) is kept forever.
/// Per D-09: Pruning runs on app launch plus once per 24 hours while running.
///
/// Only raw_samples are pruned. Aggregated tier tables are never touched.
final class PruningManager: Sendable {
    private let database: AppDatabase
    private let logger = Logger.persistence

    /// Retention period for raw samples (per D-07: 24 hours).
    let retentionInterval: TimeInterval

    init(database: AppDatabase, retentionInterval: TimeInterval = 24 * 60 * 60) {
        self.database = database
        self.retentionInterval = retentionInterval
    }

    /// Delete raw samples older than the retention period.
    /// Returns the number of deleted rows.
    @discardableResult
    func pruneOldSamples() async throws -> Int {
        let cutoff = Date().timeIntervalSince1970 - retentionInterval
        let count = try await database.dbWriter.write { db in
            try RawSample
                .filter(RawSample.Columns.timestamp < cutoff)
                .deleteAll(db)
        }
        if count > 0 {
            logger.info("Pruned \(count) raw samples older than \(self.retentionInterval / 3600)h")
        } else {
            logger.debug("No raw samples to prune")
        }
        return count
    }
}
