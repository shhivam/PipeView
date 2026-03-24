import XCTest
import GRDB
@testable import BandwidthMonitor

final class BandwidthRecorderTests: XCTestCase {

    // Helper: create a NetworkSnapshot with given interface speeds
    private func makeSnapshot(
        interfaceSpeeds: [(bsdName: String, bytesInPerSec: Double, bytesOutPerSec: Double)],
        timestamp: Date = .now
    ) -> NetworkSnapshot {
        let speeds = interfaceSpeeds.map { item in
            InterfaceSpeed(
                interface: InterfaceInfo(
                    bsdName: item.bsdName,
                    displayName: item.bsdName,
                    type: .wifi,
                    index: 1
                ),
                speed: Speed(
                    bytesInPerSecond: item.bytesInPerSec,
                    bytesOutPerSecond: item.bytesOutPerSec
                )
            )
        }
        let aggregate = speeds.reduce(Speed.zero) { $0 + $1.speed }
        return NetworkSnapshot(
            interfaceSpeeds: speeds,
            aggregateSpeed: aggregate,
            timestamp: timestamp
        )
    }

    // MARK: - Test 1: 5 uniform snapshots produce correct RawSample

    @MainActor
    func testFiveUniformSnapshotsWriteCorrectRawSample() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        // Create 5 snapshots each with en0 at 1000 B/s in, 500 B/s out
        let snapshots = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }

        // Use the internal write method via processSnapshots
        await recorder.processAndWrite(snapshots: snapshots)

        let samples = try await db.dbWriter.read { dbConn in
            try RawSample.fetchAll(dbConn)
        }

        XCTAssertEqual(samples.count, 1, "Should write one RawSample for one interface")
        let sample = samples[0]
        XCTAssertEqual(sample.interfaceId, "en0")
        // bytesIn = speed * pollingInterval * count = 1000 * 2 * 5 = 10000
        XCTAssertEqual(sample.bytesIn, 10000.0, accuracy: 0.01)
        // bytesOut = speed * pollingInterval * count = 500 * 2 * 5 = 5000
        XCTAssertEqual(sample.bytesOut, 5000.0, accuracy: 0.01)
        // duration = pollingInterval * count = 2 * 5 = 10
        XCTAssertEqual(sample.duration, 10.0, accuracy: 0.01)
    }

    // MARK: - Test 2: 5 snapshots with 2 interfaces produce 2 RawSamples

    @MainActor
    func testTwoInterfacesWriteTwoRawSamples() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        let snapshots = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [
                ("en0", 1000.0, 500.0),
                ("en1", 2000.0, 1000.0),
            ])
        }

        await recorder.processAndWrite(snapshots: snapshots)

        let samples = try await db.dbWriter.read { dbConn in
            try RawSample.order(RawSample.Columns.interfaceId).fetchAll(dbConn)
        }

        XCTAssertEqual(samples.count, 2, "Should write one RawSample per interface")

        let en0 = samples.first { $0.interfaceId == "en0" }!
        XCTAssertEqual(en0.bytesIn, 10000.0, accuracy: 0.01)
        XCTAssertEqual(en0.bytesOut, 5000.0, accuracy: 0.01)

        let en1 = samples.first { $0.interfaceId == "en1" }!
        XCTAssertEqual(en1.bytesIn, 20000.0, accuracy: 0.01)
        XCTAssertEqual(en1.bytesOut, 10000.0, accuracy: 0.01)
    }

    // MARK: - Test 3: Partial flush (3 snapshots) writes proportional values

    @MainActor
    func testPartialFlushWritesProportionalValues() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        let snapshots = (0..<3).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }

        await recorder.processAndWrite(snapshots: snapshots)

        let samples = try await db.dbWriter.read { dbConn in
            try RawSample.fetchAll(dbConn)
        }

        XCTAssertEqual(samples.count, 1)
        let sample = samples[0]
        // bytesIn = 1000 * 2 * 3 = 6000
        XCTAssertEqual(sample.bytesIn, 6000.0, accuracy: 0.01)
        // bytesOut = 500 * 2 * 3 = 3000
        XCTAssertEqual(sample.bytesOut, 3000.0, accuracy: 0.01)
        // duration = 2 * 3 = 6
        XCTAssertEqual(sample.duration, 6.0, accuracy: 0.01)
    }

    // MARK: - Test 4: 10 snapshots produce 2 write batches

    @MainActor
    func testTenSnapshotsProduceTwoBatches() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        // Process two batches of 5
        let batch1 = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }
        let batch2 = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 2000.0, 1000.0)])
        }

        await recorder.processAndWrite(snapshots: batch1)
        await recorder.processAndWrite(snapshots: batch2)

        let count = try await db.dbWriter.read { dbConn in
            try RawSample.fetchCount(dbConn)
        }

        XCTAssertEqual(count, 2, "10 snapshots in batches of 5 should produce 2 writes")
    }

    // MARK: - Test 5: Averaging logic with varying speeds

    @MainActor
    func testAveragingWithVaryingSpeeds() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        // 5 snapshots with bytesIn speeds [100, 200, 300, 400, 500]
        let speeds: [Double] = [100, 200, 300, 400, 500]
        let snapshots = speeds.map { speed in
            makeSnapshot(interfaceSpeeds: [("en0", speed, 0.0)])
        }

        await recorder.processAndWrite(snapshots: snapshots)

        let samples = try await db.dbWriter.read { dbConn in
            try RawSample.fetchAll(dbConn)
        }

        XCTAssertEqual(samples.count, 1)
        // Each snapshot contributes: speed * pollingInterval bytes
        // Total bytesIn = (100+200+300+400+500) * 2 = 1500 * 2 = 3000
        XCTAssertEqual(samples[0].bytesIn, 3000.0, accuracy: 0.01)
        XCTAssertEqual(samples[0].duration, 10.0, accuracy: 0.01)
    }

    // MARK: - Test 6: Empty snapshots produce no writes

    @MainActor
    func testEmptySnapshotsProduceNoWrites() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        // 5 empty snapshots (no interfaces)
        let snapshots = (0..<5).map { _ in
            NetworkSnapshot.empty
        }

        await recorder.processAndWrite(snapshots: snapshots)

        let count = try await db.dbWriter.read { dbConn in
            try RawSample.fetchCount(dbConn)
        }

        XCTAssertEqual(count, 0, "Empty snapshots should not produce any writes")
    }

    // MARK: - Test 7: 1-second polling interval produces correct bytes

    @MainActor
    func testOneSecondPollingIntervalProducesCorrectBytes() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 1.0
        )

        // 5 snapshots with en0 at 1000 B/s in, 500 B/s out
        let snapshots = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }

        await recorder.processAndWrite(snapshots: snapshots)

        let samples = try await db.dbWriter.read { dbConn in
            try RawSample.fetchAll(dbConn)
        }

        XCTAssertEqual(samples.count, 1, "Should write one RawSample for one interface")
        let sample = samples[0]
        XCTAssertEqual(sample.interfaceId, "en0")
        // bytesIn = speed * pollingInterval * count = 1000 * 1.0 * 5 = 5000
        XCTAssertEqual(sample.bytesIn, 5000.0, accuracy: 0.01)
        // bytesOut = speed * pollingInterval * count = 500 * 1.0 * 5 = 2500
        XCTAssertEqual(sample.bytesOut, 2500.0, accuracy: 0.01)
        // duration = pollingInterval * count = 1.0 * 5 = 5.0
        XCTAssertEqual(sample.duration, 5.0, accuracy: 0.01)
    }

    // MARK: - Test 8: 5-second polling interval produces correct bytes

    @MainActor
    func testFiveSecondPollingIntervalProducesCorrectBytes() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 5.0
        )

        // 5 snapshots with en0 at 1000 B/s in, 500 B/s out
        let snapshots = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }

        await recorder.processAndWrite(snapshots: snapshots)

        let samples = try await db.dbWriter.read { dbConn in
            try RawSample.fetchAll(dbConn)
        }

        XCTAssertEqual(samples.count, 1, "Should write one RawSample for one interface")
        let sample = samples[0]
        XCTAssertEqual(sample.interfaceId, "en0")
        // bytesIn = speed * pollingInterval * count = 1000 * 5.0 * 5 = 25000
        XCTAssertEqual(sample.bytesIn, 25000.0, accuracy: 0.01)
        // bytesOut = speed * pollingInterval * count = 500 * 5.0 * 5 = 12500
        XCTAssertEqual(sample.bytesOut, 12500.0, accuracy: 0.01)
        // duration = pollingInterval * count = 5.0 * 5 = 25.0
        XCTAssertEqual(sample.duration, 25.0, accuracy: 0.01)
    }

    // MARK: - Test 9: Changing pollingInterval after init affects subsequent writes

    @MainActor
    func testChangingPollingIntervalAffectsSubsequentWrites() async throws {
        let db = try AppDatabase.makeEmpty()
        let monitor = NetworkMonitor()
        let recorder = BandwidthRecorder(
            networkMonitor: monitor,
            database: db,
            accumulationCount: 5,
            pollingInterval: 2.0
        )

        // First batch: 5 snapshots at 1000 B/s with pollingInterval = 2.0
        let batch1 = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }
        await recorder.processAndWrite(snapshots: batch1)

        // Verify first batch uses pollingInterval 2.0
        let firstSamples = try await db.dbWriter.read { dbConn in
            try RawSample.fetchAll(dbConn)
        }
        XCTAssertEqual(firstSamples.count, 1)
        // bytesIn = 1000 * 2.0 * 5 = 10000
        XCTAssertEqual(firstSamples[0].bytesIn, 10000.0, accuracy: 0.01)

        // Change pollingInterval at runtime
        recorder.pollingInterval = 5.0

        // Second batch: 5 snapshots at 1000 B/s with pollingInterval = 5.0
        let batch2 = (0..<5).map { _ in
            makeSnapshot(interfaceSpeeds: [("en0", 1000.0, 500.0)])
        }
        await recorder.processAndWrite(snapshots: batch2)

        // Verify second batch uses pollingInterval 5.0
        let allSamples = try await db.dbWriter.read { dbConn in
            try RawSample.order(RawSample.Columns.id).fetchAll(dbConn)
        }
        XCTAssertEqual(allSamples.count, 2)
        // Second sample: bytesIn = 1000 * 5.0 * 5 = 25000
        XCTAssertEqual(allSamples[1].bytesIn, 25000.0, accuracy: 0.01)
        // Second sample: duration = 5.0 * 5 = 25.0
        XCTAssertEqual(allSamples[1].duration, 25.0, accuracy: 0.01)
    }
}
