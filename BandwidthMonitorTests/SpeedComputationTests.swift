import XCTest
@testable import BandwidthMonitor

final class SpeedComputationTests: XCTestCase {

    func testNormalSpeedComputation() {
        let previous = ByteCounters(bytesIn: 1000, bytesOut: 500)
        let current = ByteCounters(bytesIn: 2000, bytesOut: 1000)
        let speed = computeSpeed(previous: previous, current: current, elapsed: 2.0)
        XCTAssertEqual(speed.bytesInPerSecond, 500.0, accuracy: 0.001)
        XCTAssertEqual(speed.bytesOutPerSecond, 250.0, accuracy: 0.001)
    }

    func testZeroElapsedReturnsZero() {
        let previous = ByteCounters(bytesIn: 1000, bytesOut: 500)
        let current = ByteCounters(bytesIn: 2000, bytesOut: 1000)
        let speed = computeSpeed(previous: previous, current: current, elapsed: 0.0)
        XCTAssertEqual(speed, Speed.zero)
    }

    func testCounterResetReturnsZero() {
        let previous = ByteCounters(bytesIn: 5000, bytesOut: 3000)
        let current = ByteCounters(bytesIn: 100, bytesOut: 50)
        let speed = computeSpeed(previous: previous, current: current, elapsed: 1.0)
        XCTAssertEqual(speed.bytesInPerSecond, 0.0, accuracy: 0.001)
        XCTAssertEqual(speed.bytesOutPerSecond, 0.0, accuracy: 0.001)
    }

    func testZeroDeltaReturnsZero() {
        let counters = ByteCounters(bytesIn: 1000, bytesOut: 500)
        let speed = computeSpeed(previous: counters, current: counters, elapsed: 1.0)
        XCTAssertEqual(speed, Speed.zero)
    }

    func testPartialCounterReset() {
        let previous = ByteCounters(bytesIn: 5000, bytesOut: 100)
        let current = ByteCounters(bytesIn: 100, bytesOut: 600)
        let speed = computeSpeed(previous: previous, current: current, elapsed: 1.0)
        XCTAssertEqual(speed.bytesInPerSecond, 0.0, accuracy: 0.001)  // reset direction
        XCTAssertEqual(speed.bytesOutPerSecond, 500.0, accuracy: 0.001)  // normal direction
    }
}
