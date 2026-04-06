import XCTest
@testable import BandwidthMonitor

@MainActor
final class NetworkMonitorTests: XCTestCase {
    func testStartStop() async {
        let monitor = NetworkMonitor()
        XCTAssertFalse(monitor.isRunning)

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testDoubleStartDoesNotCrash() async {
        let monitor = NetworkMonitor()
        monitor.start()
        monitor.start()  // Should cleanly restart, not crash or leak
        XCTAssertTrue(monitor.isRunning)
        monitor.stop()
    }

    func testStopClearsState() async {
        let monitor = NetworkMonitor()
        monitor.start()

        // Wait for at least one poll cycle
        try? await Task.sleep(for: .seconds(3))

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
        // After stop, speeds should remain from last poll but isRunning should be false
    }

    func testProducesSpeedDataAfterPolling() async {
        let monitor = NetworkMonitor()
        monitor.pollingInterval = .seconds(1)  // Faster for testing (per D-02: configurable)
        monitor.start()

        // Wait for 2+ poll cycles so we have previous + current for delta calculation
        try? await Task.sleep(for: .seconds(3))

        // On a real Mac with network activity, aggregateSpeed may be non-zero
        // At minimum, we should have interface data if any interfaces are active
        // The key assertion is that the monitor is producing snapshots
        XCTAssertNotEqual(monitor.latestSnapshot.timestamp, NetworkSnapshot.empty.timestamp,
            "Monitor should have produced at least one snapshot")

        monitor.stop()
    }

    func testPollingIntervalIsConfigurable() async {
        let monitor = NetworkMonitor()
        monitor.pollingInterval = .seconds(5)  // Per D-02: configurable
        XCTAssertEqual(monitor.pollingInterval, .seconds(5))

        monitor.pollingInterval = .seconds(1)
        XCTAssertEqual(monitor.pollingInterval, .seconds(1))
    }

    func testDefaultPollingIntervalIsTwoSeconds() async {
        let monitor = NetworkMonitor()
        XCTAssertEqual(monitor.pollingInterval, .seconds(2),
            "Default polling interval should be 2 seconds per D-01")
    }
}
