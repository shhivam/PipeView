import XCTest
@testable import BandwidthMonitor

final class ByteFormatterTests: XCTestCase {
    private let formatter = ByteFormatter()

    // MARK: - Zero and below-threshold

    func testFormatZeroBytes() {
        XCTAssertEqual(formatter.format(bytes: 0), "0 KB")
    }

    func testFormatBelowThreshold() {
        XCTAssertEqual(formatter.format(bytes: 500), "0 KB")
    }

    // MARK: - KB range

    func testFormatKilobytesWithDecimal() {
        XCTAssertEqual(formatter.format(bytes: 1500), "1.5 KB")
    }

    func testFormatKilobytesNoDecimalAbove100() {
        XCTAssertEqual(formatter.format(bytes: 150_000), "150 KB")
    }

    // MARK: - MB range

    func testFormatMegabytesWithDecimal() {
        XCTAssertEqual(formatter.format(bytes: 1_200_000), "1.2 MB")
    }

    // MARK: - GB range

    func testFormatGigabytesWithDecimal() {
        XCTAssertEqual(formatter.format(bytes: 45_300_000_000), "45.3 GB")
    }

    func testFormatGigabytesNoDecimalAbove100() {
        XCTAssertEqual(formatter.format(bytes: 150_000_000_000), "150 GB")
    }
}
