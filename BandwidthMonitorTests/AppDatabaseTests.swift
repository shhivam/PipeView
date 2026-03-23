import XCTest
import GRDB
@testable import BandwidthMonitor

final class AppDatabaseTests: XCTestCase {

    // MARK: - Test 1: Database creation and all 6 tables exist

    func testDatabaseCreatesAllTables() throws {
        let db = try AppDatabase.makeEmpty()
        let tableNames = try db.dbWriter.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'grdb_migrations'
                ORDER BY name
                """)
        }
        XCTAssertEqual(tableNames, [
            "day_samples",
            "hour_samples",
            "minute_samples",
            "month_samples",
            "raw_samples",
            "week_samples",
        ])
    }

    // MARK: - Test 2: RawSample insert and fetch roundtrip

    func testRawSampleInsertAndFetch() throws {
        let db = try AppDatabase.makeEmpty()
        var sample = RawSample(
            id: nil,
            interfaceId: "en0",
            timestamp: 1700000000.0,
            bytesIn: 1024.0,
            bytesOut: 512.0,
            duration: 10.0
        )

        try db.dbWriter.write { dbConn in
            try sample.insert(dbConn)
        }

        let fetched = try db.dbWriter.read { dbConn in
            try RawSample.fetchOne(dbConn)
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.interfaceId, "en0")
        XCTAssertEqual(fetched?.timestamp, 1700000000.0)
        XCTAssertEqual(fetched?.bytesIn, 1024.0)
        XCTAssertEqual(fetched?.bytesOut, 512.0)
        XCTAssertEqual(fetched?.duration, 10.0)
        XCTAssertNotNil(fetched?.id)
    }

    // MARK: - Test 3: Multiple RawSamples with same interfaceId

    func testMultipleRawSamplesWithSameInterface() throws {
        let db = try AppDatabase.makeEmpty()

        try db.dbWriter.write { dbConn in
            var s1 = RawSample(id: nil, interfaceId: "en0", timestamp: 1700000000.0,
                               bytesIn: 100.0, bytesOut: 50.0, duration: 10.0)
            var s2 = RawSample(id: nil, interfaceId: "en0", timestamp: 1700000010.0,
                               bytesIn: 200.0, bytesOut: 75.0, duration: 10.0)
            try s1.insert(dbConn)
            try s2.insert(dbConn)
        }

        let count = try db.dbWriter.read { dbConn in
            try RawSample.fetchCount(dbConn)
        }
        XCTAssertEqual(count, 2)
    }

    // MARK: - Test 4: MinuteSample insert and fetch roundtrip

    func testMinuteSampleInsertAndFetch() throws {
        let db = try AppDatabase.makeEmpty()
        var sample = MinuteSample(
            id: nil,
            interfaceId: "en0",
            bucketTimestamp: 1700000000.0,
            totalBytesIn: 10240.0,
            totalBytesOut: 5120.0,
            peakBytesInPerSec: 1024.0,
            peakBytesOutPerSec: 512.0,
            sampleCount: 6
        )

        try db.dbWriter.write { dbConn in
            try sample.insert(dbConn)
        }

        let fetched = try db.dbWriter.read { dbConn in
            try MinuteSample.fetchOne(dbConn)
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.interfaceId, "en0")
        XCTAssertEqual(fetched?.bucketTimestamp, 1700000000.0)
        XCTAssertEqual(fetched?.totalBytesIn, 10240.0)
        XCTAssertEqual(fetched?.totalBytesOut, 5120.0)
        XCTAssertEqual(fetched?.peakBytesInPerSec, 1024.0)
        XCTAssertEqual(fetched?.peakBytesOutPerSec, 512.0)
        XCTAssertEqual(fetched?.sampleCount, 6)
    }

    // MARK: - Test 5: MinuteSample UNIQUE constraint with INSERT OR REPLACE

    func testMinuteSampleUniqueConstraintReplace() throws {
        let db = try AppDatabase.makeEmpty()

        // Insert initial
        try db.dbWriter.write { dbConn in
            var sample = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                totalBytesIn: 100.0, totalBytesOut: 50.0,
                peakBytesInPerSec: 10.0, peakBytesOutPerSec: 5.0,
                sampleCount: 1
            )
            try sample.insert(dbConn)
        }

        // INSERT OR REPLACE with same (interfaceId, bucketTimestamp)
        try db.dbWriter.write { dbConn in
            try dbConn.execute(sql: """
                INSERT OR REPLACE INTO minute_samples
                (interfaceId, bucketTimestamp, totalBytesIn, totalBytesOut,
                 peakBytesInPerSec, peakBytesOutPerSec, sampleCount)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: ["en0", 1700000000.0, 200.0, 100.0, 20.0, 10.0, 2])
        }

        let count = try db.dbWriter.read { dbConn in
            try MinuteSample.fetchCount(dbConn)
        }
        XCTAssertEqual(count, 1, "UNIQUE constraint should cause replacement, not duplicate")

        let fetched = try db.dbWriter.read { dbConn in
            try MinuteSample.fetchOne(dbConn)
        }
        XCTAssertEqual(fetched?.totalBytesIn, 200.0, "Should have replaced values")
        XCTAssertEqual(fetched?.sampleCount, 2)
    }

    // MARK: - Test 6: All tier types insert/fetch

    func testAllTierTypesInsertAndFetch() throws {
        let db = try AppDatabase.makeEmpty()

        try db.dbWriter.write { dbConn in
            var minute = MinuteSample(id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                                       totalBytesIn: 100.0, totalBytesOut: 50.0,
                                       peakBytesInPerSec: 10.0, peakBytesOutPerSec: 5.0, sampleCount: 1)
            var hour = HourSample(id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                                   totalBytesIn: 1000.0, totalBytesOut: 500.0,
                                   peakBytesInPerSec: 100.0, peakBytesOutPerSec: 50.0, sampleCount: 60)
            var day = DaySample(id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                                 totalBytesIn: 24000.0, totalBytesOut: 12000.0,
                                 peakBytesInPerSec: 200.0, peakBytesOutPerSec: 100.0, sampleCount: 1440)
            var week = WeekSample(id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                                   totalBytesIn: 168000.0, totalBytesOut: 84000.0,
                                   peakBytesInPerSec: 300.0, peakBytesOutPerSec: 150.0, sampleCount: 10080)
            var month = MonthSample(id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                                     totalBytesIn: 720000.0, totalBytesOut: 360000.0,
                                     peakBytesInPerSec: 400.0, peakBytesOutPerSec: 200.0, sampleCount: 43200)
            try minute.insert(dbConn)
            try hour.insert(dbConn)
            try day.insert(dbConn)
            try week.insert(dbConn)
            try month.insert(dbConn)
        }

        try db.dbWriter.read { dbConn in
            XCTAssertEqual(try MinuteSample.fetchCount(dbConn), 1)
            XCTAssertEqual(try HourSample.fetchCount(dbConn), 1)
            XCTAssertEqual(try DaySample.fetchCount(dbConn), 1)
            XCTAssertEqual(try WeekSample.fetchCount(dbConn), 1)
            XCTAssertEqual(try MonthSample.fetchCount(dbConn), 1)

            // Verify a fetched record has correct data
            let hour = try HourSample.fetchOne(dbConn)
            XCTAssertEqual(hour?.totalBytesIn, 1000.0)
            XCTAssertEqual(hour?.sampleCount, 60)
        }
    }

    // MARK: - Test 7: RawSample.Columns filtering by timestamp range

    func testRawSampleColumnFilteringByTimestamp() throws {
        let db = try AppDatabase.makeEmpty()

        try db.dbWriter.write { dbConn in
            for i in 0..<10 {
                var sample = RawSample(
                    id: nil, interfaceId: "en0",
                    timestamp: 1700000000.0 + Double(i * 10),
                    bytesIn: Double(i * 100),
                    bytesOut: Double(i * 50),
                    duration: 10.0
                )
                try sample.insert(dbConn)
            }
        }

        // Filter: timestamps in [1700000030, 1700000060)
        let filtered = try db.dbWriter.read { dbConn in
            try RawSample
                .filter(RawSample.Columns.timestamp >= 1700000030.0)
                .filter(RawSample.Columns.timestamp < 1700000060.0)
                .fetchAll(dbConn)
        }

        XCTAssertEqual(filtered.count, 3, "Should match timestamps at 30, 40, 50")
        XCTAssertTrue(filtered.allSatisfy { $0.timestamp >= 1700000030.0 && $0.timestamp < 1700000060.0 })
    }
}
