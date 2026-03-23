import XCTest
@testable import BandwidthMonitor

final class SpeedTextBuilderTests: XCTestCase {
    let builder = SpeedTextBuilder()

    // MARK: - D-06: Auto mode (higher traffic wins, upload wins ties)

    func testAutoMode_DownloadHigher() {
        let speed = Speed(bytesInPerSecond: 1_200_000, bytesOutPerSecond: 500)
        let result = builder.build(speed: speed, mode: .auto, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2193} 1.2 MB/s")
    }

    func testAutoMode_UploadHigher() {
        let speed = Speed(bytesInPerSecond: 500, bytesOutPerSecond: 1_200_000)
        let result = builder.build(speed: speed, mode: .auto, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2191} 1.2 MB/s")
    }

    func testAutoMode_EqualBothZero_UploadWinsTie() {
        let result = builder.build(speed: .zero, mode: .auto, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2191} 0 KB/s")
    }

    func testAutoMode_EqualBothNonZero_UploadWinsTie() {
        let speed = Speed(bytesInPerSecond: 1_000, bytesOutPerSecond: 1_000)
        let result = builder.build(speed: speed, mode: .auto, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2191} 1.0 KB/s")
    }

    // MARK: - D-07: Upload only / Download only modes

    func testUploadOnlyMode() {
        let speed = Speed(bytesInPerSecond: 5_000_000, bytesOutPerSecond: 1_200_000)
        let result = builder.build(speed: speed, mode: .uploadOnly, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2191} 1.2 MB/s")
    }

    func testDownloadOnlyMode() {
        let speed = Speed(bytesInPerSecond: 5_000_000, bytesOutPerSecond: 1_200_000)
        let result = builder.build(speed: speed, mode: .downloadOnly, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2193} 5.0 MB/s")
    }

    // MARK: - D-08: Both mode (space separator)

    func testBothMode() {
        let speed = Speed(bytesInPerSecond: 45_300, bytesOutPerSecond: 1_200_000)
        let result = builder.build(speed: speed, mode: .both, hasInterfaces: true)
        XCTAssertEqual(result, "\u{2191} 1.2 MB/s \u{2193} 45.3 KB/s")
    }

    // MARK: - D-18: No interfaces (em dash)

    func testNoInterfaces_AutoMode() {
        let speed = Speed(bytesInPerSecond: 1_200_000, bytesOutPerSecond: 500)
        let result = builder.build(speed: speed, mode: .auto, hasInterfaces: false)
        XCTAssertEqual(result, "\u{2014}")
    }

    func testNoInterfaces_UploadOnlyMode() {
        let speed = Speed(bytesInPerSecond: 1_200_000, bytesOutPerSecond: 500)
        let result = builder.build(speed: speed, mode: .uploadOnly, hasInterfaces: false)
        XCTAssertEqual(result, "\u{2014}")
    }

    func testNoInterfaces_DownloadOnlyMode() {
        let speed = Speed(bytesInPerSecond: 1_200_000, bytesOutPerSecond: 500)
        let result = builder.build(speed: speed, mode: .downloadOnly, hasInterfaces: false)
        XCTAssertEqual(result, "\u{2014}")
    }

    func testNoInterfaces_BothMode() {
        let speed = Speed(bytesInPerSecond: 1_200_000, bytesOutPerSecond: 500)
        let result = builder.build(speed: speed, mode: .both, hasInterfaces: false)
        XCTAssertEqual(result, "\u{2014}")
    }
}
