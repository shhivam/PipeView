import XCTest
import Network
@testable import BandwidthMonitor

final class InterfaceFilterTests: XCTestCase {

    func testLoopbackFiltered() {
        XCTAssertFalse(InterfaceFilter.shouldInclude(bsdName: "lo0", type: .loopback))
    }

    func testBridgeFiltered() {
        XCTAssertFalse(InterfaceFilter.shouldInclude(bsdName: "bridge0", type: .other))
    }

    func testVnicFiltered() {
        XCTAssertFalse(InterfaceFilter.shouldInclude(bsdName: "vnic0", type: .other))
    }

    func testVmnetFiltered() {
        XCTAssertFalse(InterfaceFilter.shouldInclude(bsdName: "vmnet1", type: .other))
    }

    func testWifiIncluded() {
        XCTAssertTrue(InterfaceFilter.shouldInclude(bsdName: "en0", type: .wifi))
    }

    func testEthernetIncluded() {
        XCTAssertTrue(InterfaceFilter.shouldInclude(bsdName: "en1", type: .wiredEthernet))
    }

    func testCellularIncluded() {
        XCTAssertTrue(InterfaceFilter.shouldInclude(bsdName: "pdp_ip0", type: .cellular))
    }

    func testUtunVpnIncluded() {
        XCTAssertTrue(InterfaceFilter.shouldInclude(bsdName: "utun0", type: .other))
    }

    func testAwdlFiltered() {
        XCTAssertFalse(InterfaceFilter.shouldInclude(bsdName: "awdl0", type: .other))
    }

    func testLlwFiltered() {
        XCTAssertFalse(InterfaceFilter.shouldInclude(bsdName: "llw0", type: .other))
    }
}
