import XCTest
@testable import BandwidthMonitor

final class SpeedFormatterTests: XCTestCase {
    let formatter = SpeedFormatter()

    // MARK: - D-10: Below 1 KB/s threshold

    func testFormatZero() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 0), "0 KB/s")
    }

    func testFormat500BytesPerSecond() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 500), "0 KB/s")
    }

    func testFormat999BytesPerSecond() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 999), "0 KB/s")
    }

    // MARK: - D-09 + D-02: KB/s range with adaptive precision

    func testFormat1KBBoundary() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_000), "1.0 KB/s")
    }

    func testFormat1Point2KB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_200), "1.2 KB/s")
    }

    func testFormat45Point3KB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 45_300), "45.3 KB/s")
    }

    func testFormat99Point9KB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 99_900), "99.9 KB/s")
    }

    func testFormat100KB_NoDecimal() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 100_000), "100 KB/s")
    }

    func testFormat456KB_NoDecimal() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 456_000), "456 KB/s")
    }

    func testFormat999999_StillKB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 999_999), "1000 KB/s")
    }

    // MARK: - D-09: MB/s range

    func testFormat1MBBoundary() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_000_000), "1.0 MB/s")
    }

    func testFormat1Point2MB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_200_000), "1.2 MB/s")
    }

    func testFormat100MB_NoDecimal() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 100_000_000), "100 MB/s")
    }

    // MARK: - D-09: GB/s range

    func testFormat1GBBoundary() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_000_000_000), "1.0 GB/s")
    }

    func testFormat2Point5GB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 2_500_000_000), "2.5 GB/s")
    }

    // MARK: - D-11: Fixed unit modes (ceiling behavior)

    func testFixedMB_ValueTooSmall_FallsBackToKB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_200, unit: .fixedMB), "1.2 KB/s")
    }

    func testFixedMB_WithinRange() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_500_000, unit: .fixedMB), "1.5 MB/s")
    }

    func testFixedKB_StaysInKB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_500_000, unit: .fixedKB), "1500 KB/s")
    }

    func testFixedMB_CannotPromoteToGB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_000_000_000, unit: .fixedMB), "1000 MB/s")
    }

    func testFixedGB_AllowsGB() {
        XCTAssertEqual(formatter.format(bytesPerSecond: 1_000_000_000, unit: .fixedGB), "1.0 GB/s")
    }
}
