import Testing
import Foundation
import GRDB
@testable import BandwidthMonitor

/// Tests for PruningManager raw sample cleanup.
struct PruningManagerTests {

    // MARK: - Helpers

    private func makeManager(retentionInterval: TimeInterval = 24 * 60 * 60)
        throws -> (AppDatabase, PruningManager)
    {
        let db = try AppDatabase.makeEmpty()
        let manager = PruningManager(database: db, retentionInterval: retentionInterval)
        return (db, manager)
    }

    private func insertRaw(
        _ db: AppDatabase,
        interfaceId: String = "en0",
        timestamp: Double,
        bytesIn: Double = 1000,
        bytesOut: Double = 500,
        duration: Double = 10.0
    ) async throws {
        try await db.dbWriter.write { dbConn in
            var sample = RawSample(
                id: nil,
                interfaceId: interfaceId,
                timestamp: timestamp,
                bytesIn: bytesIn,
                bytesOut: bytesOut,
                duration: duration
            )
            try sample.insert(dbConn)
        }
    }

    // MARK: - Test 10: Old raw samples are deleted

    @Test("Raw samples older than 24 hours are deleted")
    func pruneOldSamples() async throws {
        // Use 1-hour retention for testability
        let (db, manager) = try makeManager(retentionInterval: 3600)

        let now = Date().timeIntervalSince1970
        // Insert sample 2 hours old (should be pruned with 1h retention)
        try await insertRaw(db, timestamp: now - 7200)
        // Insert sample 30 min old (should be kept)
        try await insertRaw(db, timestamp: now - 1800)

        let deleted = try await manager.pruneOldSamples()

        #expect(deleted == 1)

        let remaining = try await db.dbWriter.read { dbConn in
            try RawSample.fetchCount(dbConn)
        }
        #expect(remaining == 1)
    }

    // MARK: - Test 11: Recent raw samples are preserved

    @Test("Raw samples younger than 24 hours are preserved")
    func preserveRecentSamples() async throws {
        let (db, manager) = try makeManager(retentionInterval: 3600)

        let now = Date().timeIntervalSince1970
        // Insert 3 recent samples
        try await insertRaw(db, timestamp: now - 60)
        try await insertRaw(db, timestamp: now - 120)
        try await insertRaw(db, timestamp: now - 180)

        let deleted = try await manager.pruneOldSamples()

        #expect(deleted == 0)

        let remaining = try await db.dbWriter.read { dbConn in
            try RawSample.fetchCount(dbConn)
        }
        #expect(remaining == 3)
    }

    // MARK: - Test 12: Aggregated tier data is never deleted by pruning

    @Test("Minute/hour/day/week/month samples are never deleted by pruning")
    func aggregatedDataPreserved() async throws {
        let (db, manager) = try makeManager(retentionInterval: 3600)

        let now = Date().timeIntervalSince1970
        let oldTimestamp = now - 7200 // 2 hours ago (older than retention)

        // Insert old raw sample (should be pruned)
        try await insertRaw(db, timestamp: oldTimestamp)

        // Insert old aggregated samples (should NOT be pruned)
        try await db.dbWriter.write { dbConn in
            var minute = MinuteSample(
                id: nil, interfaceId: "en0",
                bucketTimestamp: oldTimestamp,
                totalBytesIn: 6000, totalBytesOut: 3000,
                peakBytesInPerSec: 100, peakBytesOutPerSec: 50,
                sampleCount: 6
            )
            try minute.insert(dbConn)

            var hour = HourSample(
                id: nil, interfaceId: "en0",
                bucketTimestamp: oldTimestamp,
                totalBytesIn: 360000, totalBytesOut: 180000,
                peakBytesInPerSec: 100, peakBytesOutPerSec: 50,
                sampleCount: 360
            )
            try hour.insert(dbConn)

            var day = DaySample(
                id: nil, interfaceId: "en0",
                bucketTimestamp: oldTimestamp,
                totalBytesIn: 8640000, totalBytesOut: 4320000,
                peakBytesInPerSec: 100, peakBytesOutPerSec: 50,
                sampleCount: 8640
            )
            try day.insert(dbConn)

            var week = WeekSample(
                id: nil, interfaceId: "en0",
                bucketTimestamp: oldTimestamp,
                totalBytesIn: 60480000, totalBytesOut: 30240000,
                peakBytesInPerSec: 100, peakBytesOutPerSec: 50,
                sampleCount: 60480
            )
            try week.insert(dbConn)

            var month = MonthSample(
                id: nil, interfaceId: "en0",
                bucketTimestamp: oldTimestamp,
                totalBytesIn: 259200000, totalBytesOut: 129600000,
                peakBytesInPerSec: 100, peakBytesOutPerSec: 50,
                sampleCount: 259200
            )
            try month.insert(dbConn)
        }

        let deleted = try await manager.pruneOldSamples()

        // Only raw sample should be deleted
        #expect(deleted == 1)

        // All aggregated data should remain
        let minuteCount = try await db.dbWriter.read { dbConn in
            try MinuteSample.fetchCount(dbConn)
        }
        let hourCount = try await db.dbWriter.read { dbConn in
            try HourSample.fetchCount(dbConn)
        }
        let dayCount = try await db.dbWriter.read { dbConn in
            try DaySample.fetchCount(dbConn)
        }
        let weekCount = try await db.dbWriter.read { dbConn in
            try WeekSample.fetchCount(dbConn)
        }
        let monthCount = try await db.dbWriter.read { dbConn in
            try MonthSample.fetchCount(dbConn)
        }
        #expect(minuteCount == 1)
        #expect(hourCount == 1)
        #expect(dayCount == 1)
        #expect(weekCount == 1)
        #expect(monthCount == 1)
    }

    // MARK: - Test 13: Pruning returns count of deleted rows

    @Test("Pruning returns count of deleted rows")
    func pruneReturnsDeletedCount() async throws {
        let (db, manager) = try makeManager(retentionInterval: 3600)

        let now = Date().timeIntervalSince1970
        // Insert 5 old samples
        for i in 0..<5 {
            try await insertRaw(db, timestamp: now - 7200 - Double(i * 10))
        }
        // Insert 2 recent samples
        try await insertRaw(db, timestamp: now - 60)
        try await insertRaw(db, timestamp: now - 120)

        let deleted = try await manager.pruneOldSamples()
        #expect(deleted == 5)

        let remaining = try await db.dbWriter.read { dbConn in
            try RawSample.fetchCount(dbConn)
        }
        #expect(remaining == 2)
    }
}
