import XCTest
import GRDB
@testable import BandwidthMonitor

/// Tests for AppDatabase chart and cumulative stats query methods.
/// These are separate from the existing AppDatabaseTests to avoid merge conflicts.
final class AppDatabaseChartTests: XCTestCase {

    // MARK: - fetchChartData

    func testFetchChartData_sumsAcrossInterfaces() throws {
        let db = try AppDatabase.makeEmpty()

        // Insert minute_samples for two interfaces at the same bucket timestamp
        try db.dbWriter.write { dbConn in
            var s1 = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                totalBytesIn: 1000.0, totalBytesOut: 500.0,
                peakBytesInPerSec: 100.0, peakBytesOutPerSec: 50.0, sampleCount: 6
            )
            var s2 = MinuteSample(
                id: nil, interfaceId: "en1", bucketTimestamp: 1700000000.0,
                totalBytesIn: 2000.0, totalBytesOut: 1000.0,
                peakBytesInPerSec: 200.0, peakBytesOutPerSec: 100.0, sampleCount: 6
            )
            try s1.insert(dbConn)
            try s2.insert(dbConn)
        }

        let since = Date(timeIntervalSince1970: 1699999000.0)
        let points = try db.fetchChartData(tier: .minute, since: since)

        XCTAssertEqual(points.count, 1, "Two interfaces at same timestamp should produce one summed point")
        XCTAssertEqual(points[0].totalBytesIn, 3000.0, "Should sum bytesIn across interfaces")
        XCTAssertEqual(points[0].totalBytesOut, 1500.0, "Should sum bytesOut across interfaces")
        XCTAssertEqual(points[0].totalBytes, 4500.0, "totalBytes should be sum of in + out")
    }

    func testFetchChartData_sortsByTimestamp() throws {
        let db = try AppDatabase.makeEmpty()

        // Insert 3 minute_samples at different timestamps (inserted out of order)
        try db.dbWriter.write { dbConn in
            var s3 = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000120.0,
                totalBytesIn: 300.0, totalBytesOut: 150.0,
                peakBytesInPerSec: 30.0, peakBytesOutPerSec: 15.0, sampleCount: 2
            )
            var s1 = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                totalBytesIn: 100.0, totalBytesOut: 50.0,
                peakBytesInPerSec: 10.0, peakBytesOutPerSec: 5.0, sampleCount: 2
            )
            var s2 = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000060.0,
                totalBytesIn: 200.0, totalBytesOut: 100.0,
                peakBytesInPerSec: 20.0, peakBytesOutPerSec: 10.0, sampleCount: 2
            )
            try s3.insert(dbConn)
            try s1.insert(dbConn)
            try s2.insert(dbConn)
        }

        let since = Date(timeIntervalSince1970: 1699999000.0)
        let points = try db.fetchChartData(tier: .minute, since: since)

        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].timestamp.timeIntervalSince1970, 1700000000.0)
        XCTAssertEqual(points[1].timestamp.timeIntervalSince1970, 1700000060.0)
        XCTAssertEqual(points[2].timestamp.timeIntervalSince1970, 1700000120.0)
    }

    func testFetchChartData_filtersByDate() throws {
        let db = try AppDatabase.makeEmpty()

        // Insert samples before and after cutoff
        try db.dbWriter.write { dbConn in
            var before = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                totalBytesIn: 100.0, totalBytesOut: 50.0,
                peakBytesInPerSec: 10.0, peakBytesOutPerSec: 5.0, sampleCount: 1
            )
            var after = MinuteSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700001000.0,
                totalBytesIn: 200.0, totalBytesOut: 100.0,
                peakBytesInPerSec: 20.0, peakBytesOutPerSec: 10.0, sampleCount: 1
            )
            try before.insert(dbConn)
            try after.insert(dbConn)
        }

        let cutoff = Date(timeIntervalSince1970: 1700000500.0)
        let points = try db.fetchChartData(tier: .minute, since: cutoff)

        XCTAssertEqual(points.count, 1, "Should only include samples >= since timestamp")
        XCTAssertEqual(points[0].totalBytesIn, 200.0)
    }

    func testFetchChartData_emptyRange() throws {
        let db = try AppDatabase.makeEmpty()

        let future = Date(timeIntervalSince1970: 9999999999.0)
        let points = try db.fetchChartData(tier: .minute, since: future)

        XCTAssertEqual(points.count, 0, "Should return empty array when no data in range")
    }

    // MARK: - fetchCumulativeStats

    func testFetchCumulativeStats_sumsAcrossInterfaces() throws {
        let db = try AppDatabase.makeEmpty()

        // Insert hour_samples for two interfaces
        try db.dbWriter.write { dbConn in
            var s1 = HourSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                totalBytesIn: 10000.0, totalBytesOut: 5000.0,
                peakBytesInPerSec: 100.0, peakBytesOutPerSec: 50.0, sampleCount: 60
            )
            var s2 = HourSample(
                id: nil, interfaceId: "en1", bucketTimestamp: 1700000000.0,
                totalBytesIn: 20000.0, totalBytesOut: 10000.0,
                peakBytesInPerSec: 200.0, peakBytesOutPerSec: 100.0, sampleCount: 60
            )
            try s1.insert(dbConn)
            try s2.insert(dbConn)
        }

        let since = Date(timeIntervalSince1970: 1699999000.0)
        let stats = try db.fetchCumulativeStats(since: since)

        XCTAssertEqual(stats.totalIn, 30000.0, "Should sum totalBytesIn across interfaces")
        XCTAssertEqual(stats.totalOut, 15000.0, "Should sum totalBytesOut across interfaces")
    }

    func testFetchCumulativeStats_noData() throws {
        let db = try AppDatabase.makeEmpty()

        let since = Date(timeIntervalSince1970: 0.0)
        let stats = try db.fetchCumulativeStats(since: since)

        XCTAssertEqual(stats.totalIn, 0.0, "Should return 0 for totalIn with no data")
        XCTAssertEqual(stats.totalOut, 0.0, "Should return 0 for totalOut with no data")
    }

    func testFetchCumulativeStats_respectsSinceDate() throws {
        let db = try AppDatabase.makeEmpty()

        // Insert hour_samples before and after cutoff
        try db.dbWriter.write { dbConn in
            var before = HourSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700000000.0,
                totalBytesIn: 5000.0, totalBytesOut: 2500.0,
                peakBytesInPerSec: 50.0, peakBytesOutPerSec: 25.0, sampleCount: 60
            )
            var after = HourSample(
                id: nil, interfaceId: "en0", bucketTimestamp: 1700010000.0,
                totalBytesIn: 8000.0, totalBytesOut: 4000.0,
                peakBytesInPerSec: 80.0, peakBytesOutPerSec: 40.0, sampleCount: 60
            )
            try before.insert(dbConn)
            try after.insert(dbConn)
        }

        let cutoff = Date(timeIntervalSince1970: 1700005000.0)
        let stats = try db.fetchCumulativeStats(since: cutoff)

        XCTAssertEqual(stats.totalIn, 8000.0, "Should only include samples >= since")
        XCTAssertEqual(stats.totalOut, 4000.0)
    }
}
