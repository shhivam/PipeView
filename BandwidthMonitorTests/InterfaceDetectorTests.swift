import XCTest
import Network
@testable import BandwidthMonitor

final class InterfaceDetectorTests: XCTestCase {
    func testActiveInterfacesDetected() {
        // Integration test: on a real Mac, at least one interface should be detected
        let detector = InterfaceDetector()
        detector.startMonitoring()

        // Give NWPathMonitor a moment to fire initial path update
        let expectation = XCTestExpectation(description: "Interfaces detected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !detector.activeInterfaces.isEmpty {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5.0)

        XCTAssertFalse(detector.activeInterfaces.isEmpty, "Should detect at least one active interface")
        detector.stopMonitoring()
    }

    func testLoopbackNotInResults() {
        let detector = InterfaceDetector()
        detector.startMonitoring()

        let expectation = XCTestExpectation(description: "Path update received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        let loopback = detector.activeInterfaces.first(where: { $0.bsdName == "lo0" })
        XCTAssertNil(loopback, "Loopback lo0 should be filtered out")
        detector.stopMonitoring()
    }

    func testInterfacesHaveDisplayNames() {
        let detector = InterfaceDetector()
        detector.startMonitoring()

        let expectation = XCTestExpectation(description: "Path update received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        for iface in detector.activeInterfaces {
            XCTAssertFalse(iface.displayName.isEmpty, "\(iface.bsdName) should have a display name")
        }
        detector.stopMonitoring()
    }

    func testInterfacesHaveValidKernelIndex() {
        let detector = InterfaceDetector()
        detector.startMonitoring()

        let expectation = XCTestExpectation(description: "Path update received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        for iface in detector.activeInterfaces {
            XCTAssertGreaterThan(iface.index, 0, "\(iface.bsdName) should have a positive kernel index")
        }
        detector.stopMonitoring()
    }
}
