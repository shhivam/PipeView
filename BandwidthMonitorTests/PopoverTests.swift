import XCTest
import Network
@testable import BandwidthMonitor

final class PopoverTests: XCTestCase {

    // MARK: - SF Symbol Mapping Tests (D-08)

    func testSfSymbolName_wifi() {
        let info = InterfaceInfo(bsdName: "en0", displayName: "Wi-Fi", type: .wifi, index: 1)
        XCTAssertEqual(sfSymbolName(for: info), "wifi")
    }

    func testSfSymbolName_wiredEthernet() {
        let info = InterfaceInfo(bsdName: "en1", displayName: "Ethernet", type: .wiredEthernet, index: 2)
        XCTAssertEqual(sfSymbolName(for: info), "cable.connector.horizontal")
    }

    func testSfSymbolName_vpnUtun0() {
        let info = InterfaceInfo(bsdName: "utun0", displayName: "VPN", type: .other, index: 3)
        XCTAssertEqual(sfSymbolName(for: info), "lock.shield")
    }

    func testSfSymbolName_vpnUtun3() {
        let info = InterfaceInfo(bsdName: "utun3", displayName: "VPN Tunnel", type: .other, index: 4)
        XCTAssertEqual(sfSymbolName(for: info), "lock.shield")
    }

    func testSfSymbolName_otherNonVpn() {
        let info = InterfaceInfo(bsdName: "bridge0", displayName: "Bridge", type: .other, index: 5)
        XCTAssertEqual(sfSymbolName(for: info), "network")
    }

    func testSfSymbolName_loopback() {
        let info = InterfaceInfo(bsdName: "lo0", displayName: "Loopback", type: .loopback, index: 6)
        XCTAssertEqual(sfSymbolName(for: info), "network")
    }

    // MARK: - PopoverTab Tests (D-04)

    func testPopoverTab_metricsRawValue() {
        XCTAssertEqual(PopoverTab.metrics.rawValue, "Metrics")
    }

    func testPopoverTab_preferencesRawValue() {
        XCTAssertEqual(PopoverTab.preferences.rawValue, "Preferences")
    }

    func testPopoverTab_allCasesCount() {
        XCTAssertEqual(PopoverTab.allCases.count, 2)
    }
}
