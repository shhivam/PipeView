import XCTest
@testable import BandwidthMonitor

final class SysctlReaderTests: XCTestCase {

    func testInterfaceCountPositive() {
        let reader = SysctlReader()
        let count = reader.interfaceCount()
        XCTAssertNotNil(count)
        XCTAssertGreaterThan(count!, 0)
    }

    func testReadCountersForValidIndex() {
        let reader = SysctlReader()
        let counters = reader.readCounters(forInterfaceIndex: 1)
        XCTAssertNotNil(counters)
    }

    func testReadCountersForInvalidIndex() {
        let reader = SysctlReader()
        let counters = reader.readCounters(forInterfaceIndex: 99999)
        XCTAssertNil(counters)
    }

    func testInterfaceNameForValidIndex() {
        let reader = SysctlReader()
        let name = reader.interfaceName(forIndex: 1)
        XCTAssertNotNil(name)
        XCTAssertFalse(name!.isEmpty)
    }
}
