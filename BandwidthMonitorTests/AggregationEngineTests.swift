import Testing
import GRDB
@testable import BandwidthMonitor

/// Tests for AggregationEngine cascading tier rollup logic.
struct AggregationEngineTests {

    // MARK: - Helpers

    /// Create an in-memory database and return (database, engine)
    private func makeEngine() throws -> (AppDatabase, AggregationEngine) {
        let db = try AppDatabase.makeEmpty()
        let engine = AggregationEngine(database: db)
        return (db, engine)
    }

    /// Insert a raw sample with explicit values
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

    /// Insert a minute sample with explicit values
    private func insertMinute(
        _ db: AppDatabase,
        interfaceId: String = "en0",
        bucketTimestamp: Double,
        totalBytesIn: Double = 6000,
        totalBytesOut: Double = 3000,
        peakBytesInPerSec: Double = 100,
        peakBytesOutPerSec: Double = 50,
        sampleCount: Int = 6
    ) async throws {
        try await db.dbWriter.write { dbConn in
            var sample = MinuteSample(
                id: nil,
                interfaceId: interfaceId,
                bucketTimestamp: bucketTimestamp,
                totalBytesIn: totalBytesIn,
                totalBytesOut: totalBytesOut,
                peakBytesInPerSec: peakBytesInPerSec,
                peakBytesOutPerSec: peakBytesOutPerSec,
                sampleCount: sampleCount
            )
            try sample.insert(dbConn)
        }
    }

    /// Insert an hour sample with explicit values
    private func insertHour(
        _ db: AppDatabase,
        interfaceId: String = "en0",
        bucketTimestamp: Double,
        totalBytesIn: Double = 360000,
        totalBytesOut: Double = 180000,
        peakBytesInPerSec: Double = 100,
        peakBytesOutPerSec: Double = 50,
        sampleCount: Int = 360
    ) async throws {
        try await db.dbWriter.write { dbConn in
            var sample = HourSample(
                id: nil,
                interfaceId: interfaceId,
                bucketTimestamp: bucketTimestamp,
                totalBytesIn: totalBytesIn,
                totalBytesOut: totalBytesOut,
                peakBytesInPerSec: peakBytesInPerSec,
                peakBytesOutPerSec: peakBytesOutPerSec,
                sampleCount: sampleCount
            )
            try sample.insert(dbConn)
        }
    }

    /// Insert a day sample with explicit values
    private func insertDay(
        _ db: AppDatabase,
        interfaceId: String = "en0",
        bucketTimestamp: Double,
        totalBytesIn: Double = 8640000,
        totalBytesOut: Double = 4320000,
        peakBytesInPerSec: Double = 100,
        peakBytesOutPerSec: Double = 50,
        sampleCount: Int = 8640
    ) async throws {
        try await db.dbWriter.write { dbConn in
            var sample = DaySample(
                id: nil,
                interfaceId: interfaceId,
                bucketTimestamp: bucketTimestamp,
                totalBytesIn: totalBytesIn,
                totalBytesOut: totalBytesOut,
                peakBytesInPerSec: peakBytesInPerSec,
                peakBytesOutPerSec: peakBytesOutPerSec,
                sampleCount: sampleCount
            )
            try sample.insert(dbConn)
        }
    }

    // MARK: - Test 1: Raw -> Minute aggregation (single minute)

    @Test("6 raw samples in minute 0 produce 1 minute row with correct sums/max")
    func rawToMinuteSingleMinute() async throws {
        let (db, engine) = try makeEngine()

        // Insert 6 raw samples at 0,10,20,30,40,50 seconds (all in minute 0)
        for i in 0..<6 {
            try await insertRaw(db, timestamp: Double(i * 10),
                          bytesIn: Double(1000 + i * 100),    // 1000,1100,1200,1300,1400,1500
                          bytesOut: Double(500 + i * 50),     // 500,550,600,650,700,750
                          duration: 10.0)
        }

        try await engine.aggregateRawToMinutes()

        let minutes = try await db.dbWriter.read { dbConn in
            try MinuteSample.fetchAll(dbConn)
        }

        #expect(minutes.count == 1)

        let row = minutes[0]
        #expect(row.interfaceId == "en0")
        #expect(row.bucketTimestamp == 0.0)

        // totalBytesIn = 1000+1100+1200+1300+1400+1500 = 7500
        #expect(row.totalBytesIn == 7500.0)
        // totalBytesOut = 500+550+600+650+700+750 = 3750
        #expect(row.totalBytesOut == 3750.0)
        // peakBytesInPerSec = max(bytesIn/duration) = 1500/10 = 150
        #expect(row.peakBytesInPerSec == 150.0)
        // peakBytesOutPerSec = max(bytesOut/duration) = 750/10 = 75
        #expect(row.peakBytesOutPerSec == 75.0)
        #expect(row.sampleCount == 6)
    }

    // MARK: - Test 2: Raw samples spanning 2 minutes

    @Test("Raw samples in 2 minutes produce 2 minute rows with correct bucket timestamps")
    func rawToMinuteTwoMinutes() async throws {
        let (db, engine) = try makeEngine()

        // Minute 0: timestamps 0,10,20,30,40,50
        for i in 0..<6 {
            try await insertRaw(db, timestamp: Double(i * 10), bytesIn: 1000, bytesOut: 500)
        }
        // Minute 1: timestamps 60,70,80,90,100,110
        for i in 0..<6 {
            try await insertRaw(db, timestamp: Double(60 + i * 10), bytesIn: 2000, bytesOut: 1000)
        }

        try await engine.aggregateRawToMinutes()

        let minutes = try await db.dbWriter.read { dbConn in
            try MinuteSample.order(Column("bucketTimestamp")).fetchAll(dbConn)
        }

        #expect(minutes.count == 2)
        #expect(minutes[0].bucketTimestamp == 0.0)
        #expect(minutes[1].bucketTimestamp == 60.0)
        #expect(minutes[0].totalBytesIn == 6000.0)   // 6 * 1000
        #expect(minutes[1].totalBytesIn == 12000.0)   // 6 * 2000
    }

    // MARK: - Test 3: Two interfaces in same minute

    @Test("Two interfaces in same minute produce 2 separate minute rows")
    func rawToMinuteTwoInterfaces() async throws {
        let (db, engine) = try makeEngine()

        // en0 at minute 0
        for i in 0..<6 {
            try await insertRaw(db, interfaceId: "en0", timestamp: Double(i * 10),
                          bytesIn: 1000, bytesOut: 500)
        }
        // en1 at same minute 0
        for i in 0..<6 {
            try await insertRaw(db, interfaceId: "en1", timestamp: Double(i * 10),
                          bytesIn: 2000, bytesOut: 1000)
        }

        try await engine.aggregateRawToMinutes()

        let minutes = try await db.dbWriter.read { dbConn in
            try MinuteSample.order(Column("interfaceId")).fetchAll(dbConn)
        }

        #expect(minutes.count == 2)
        let en0Row = minutes.first { $0.interfaceId == "en0" }!
        let en1Row = minutes.first { $0.interfaceId == "en1" }!
        #expect(en0Row.totalBytesIn == 6000.0)
        #expect(en1Row.totalBytesIn == 12000.0)
    }

    // MARK: - Test 4: Idempotency (INSERT OR REPLACE)

    @Test("Running aggregateRawToMinutes twice produces same row count and values")
    func rawToMinuteIdempotent() async throws {
        let (db, engine) = try makeEngine()

        for i in 0..<6 {
            try await insertRaw(db, timestamp: Double(i * 10), bytesIn: 1000, bytesOut: 500)
        }

        try await engine.aggregateRawToMinutes()
        try await engine.aggregateRawToMinutes()

        let minutes = try await db.dbWriter.read { dbConn in
            try MinuteSample.fetchAll(dbConn)
        }

        #expect(minutes.count == 1)
        #expect(minutes[0].totalBytesIn == 6000.0)
        #expect(minutes[0].sampleCount == 6)
    }

    // MARK: - Test 5: Minutes -> Hours cascading

    @Test("60 minute samples produce 1 hour row with correct sum of totalBytesIn")
    func minutesToHoursCascading() async throws {
        let (db, engine) = try makeEngine()

        // Insert 60 minute samples: bucketTimestamps 0, 60, 120, ..., 3540
        for i in 0..<60 {
            try await insertMinute(db, bucketTimestamp: Double(i * 60),
                             totalBytesIn: 1000, totalBytesOut: 500,
                             peakBytesInPerSec: Double(90 + i % 10),
                             peakBytesOutPerSec: Double(40 + i % 5),
                             sampleCount: 6)
        }

        try await engine.aggregateMinutesToHours()

        let hours = try await db.dbWriter.read { dbConn in
            try HourSample.fetchAll(dbConn)
        }

        #expect(hours.count == 1)
        #expect(hours[0].bucketTimestamp == 0.0)
        #expect(hours[0].totalBytesIn == 60000.0)  // 60 * 1000
        #expect(hours[0].totalBytesOut == 30000.0)  // 60 * 500
        #expect(hours[0].sampleCount == 360)         // 60 * 6
        // peakBytesInPerSec = max of 90..99 repeating = 99
        #expect(hours[0].peakBytesInPerSec == 99.0)
    }

    // MARK: - Test 6: Hours -> Days cascading

    @Test("24 hour samples produce 1 day row")
    func hoursToDaysCascading() async throws {
        let (db, engine) = try makeEngine()

        // 24 hour samples: bucketTimestamps 0, 3600, 7200, ..., 82800
        for i in 0..<24 {
            try await insertHour(db, bucketTimestamp: Double(i * 3600),
                           totalBytesIn: 10000, totalBytesOut: 5000,
                           peakBytesInPerSec: Double(200 + i),
                           peakBytesOutPerSec: Double(100 + i),
                           sampleCount: 360)
        }

        try await engine.aggregateHoursToDays()

        let days = try await db.dbWriter.read { dbConn in
            try DaySample.fetchAll(dbConn)
        }

        #expect(days.count == 1)
        #expect(days[0].bucketTimestamp == 0.0)
        #expect(days[0].totalBytesIn == 240000.0)  // 24 * 10000
        #expect(days[0].sampleCount == 8640)         // 24 * 360
        #expect(days[0].peakBytesInPerSec == 223.0)  // max(200+0..200+23) = 223
    }

    // MARK: - Test 7: Days -> Weeks (Monday-aligned)

    @Test("7 day samples produce 1 week row with Monday-aligned bucket timestamp")
    func daysToWeeksMondayAligned() async throws {
        let (db, engine) = try makeEngine()

        // Monday Jan 6 2025 00:00 UTC = epoch 1736121600
        // This is a Monday (verified: Jan 6 2025 is a Monday)
        let mondayEpoch: Double = 1736121600
        for i in 0..<7 {
            try await insertDay(db, bucketTimestamp: mondayEpoch + Double(i * 86400),
                          totalBytesIn: 100000, totalBytesOut: 50000,
                          peakBytesInPerSec: Double(300 + i),
                          peakBytesOutPerSec: Double(150 + i),
                          sampleCount: 8640)
        }

        try await engine.aggregateDaysToWeeks()

        let weeks = try await db.dbWriter.read { dbConn in
            try WeekSample.fetchAll(dbConn)
        }

        #expect(weeks.count == 1)
        // bucketTimestamp should be Monday midnight UTC
        #expect(weeks[0].bucketTimestamp == mondayEpoch)
        #expect(weeks[0].totalBytesIn == 700000.0)  // 7 * 100000
        #expect(weeks[0].sampleCount == 60480)        // 7 * 8640
        #expect(weeks[0].peakBytesInPerSec == 306.0)  // max(300+0..300+6) = 306
    }

    // MARK: - Test 8: Days -> Months (first-of-month aligned)

    @Test("Day samples within same month produce 1 month row with first-of-month timestamp")
    func daysToMonthsFirstOfMonth() async throws {
        let (db, engine) = try makeEngine()

        // Jan 1 2025 00:00 UTC = epoch 1735689600
        let jan1Epoch: Double = 1735689600
        // Insert 31 day samples for January 2025
        for i in 0..<31 {
            try await insertDay(db, bucketTimestamp: jan1Epoch + Double(i * 86400),
                          totalBytesIn: 50000, totalBytesOut: 25000,
                          peakBytesInPerSec: Double(200 + i),
                          peakBytesOutPerSec: Double(100 + i),
                          sampleCount: 8640)
        }

        try await engine.aggregateDaysToMonths()

        let months = try await db.dbWriter.read { dbConn in
            try MonthSample.fetchAll(dbConn)
        }

        #expect(months.count == 1)
        // bucketTimestamp should be Jan 1 00:00 UTC
        #expect(months[0].bucketTimestamp == jan1Epoch)
        #expect(months[0].totalBytesIn == 1550000.0)  // 31 * 50000
        #expect(months[0].sampleCount == 267840)        // 31 * 8640
        #expect(months[0].peakBytesInPerSec == 230.0)  // max(200+0..200+30) = 230
    }

    // MARK: - Test 9: Watermark optimization

    @Test("Aggregation only processes records newer than last bucket timestamp in target tier")
    func watermarkOptimization() async throws {
        let (db, engine) = try makeEngine()

        // Insert samples in minute 0 and aggregate
        for i in 0..<6 {
            try await insertRaw(db, timestamp: Double(i * 10), bytesIn: 1000, bytesOut: 500)
        }
        try await engine.aggregateRawToMinutes()

        // Now insert samples in minute 1
        for i in 0..<6 {
            try await insertRaw(db, timestamp: Double(60 + i * 10), bytesIn: 2000, bytesOut: 1000)
        }
        try await engine.aggregateRawToMinutes()

        let minutes = try await db.dbWriter.read { dbConn in
            try MinuteSample.order(Column("bucketTimestamp")).fetchAll(dbConn)
        }

        // Both minutes should exist
        #expect(minutes.count == 2)
        #expect(minutes[0].bucketTimestamp == 0.0)
        #expect(minutes[0].totalBytesIn == 6000.0)   // Original minute 0 data preserved
        #expect(minutes[1].bucketTimestamp == 60.0)
        #expect(minutes[1].totalBytesIn == 12000.0)   // New minute 1 data
    }
}
