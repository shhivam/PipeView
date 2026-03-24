import XCTest
@testable import BandwidthMonitor

final class PreferencesTests: XCTestCase {

    // MARK: - DisplayModePref

    func testDisplayModePrefAutoRoundtrip() {
        let pref = DisplayModePref.auto
        XCTAssertEqual(pref.rawValue, "auto")
        XCTAssertEqual(DisplayModePref(rawValue: "auto"), .auto)
    }

    func testDisplayModePrefAllCasesUniqueRawValues() {
        let rawValues = DisplayModePref.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "All DisplayModePref cases must have unique rawValues")
    }

    func testDisplayModePrefBothConvertsToDisplayMode() {
        let result = DisplayModePref.both.toDisplayMode()
        XCTAssertEqual(result, DisplayMode.both)
    }

    func testDisplayModePrefAutoConvertsToDisplayMode() {
        XCTAssertEqual(DisplayModePref.auto.toDisplayMode(), DisplayMode.auto)
    }

    func testDisplayModePrefUploadOnlyConvertsToDisplayMode() {
        XCTAssertEqual(DisplayModePref.uploadOnly.toDisplayMode(), DisplayMode.uploadOnly)
    }

    func testDisplayModePrefDownloadOnlyConvertsToDisplayMode() {
        XCTAssertEqual(DisplayModePref.downloadOnly.toDisplayMode(), DisplayMode.downloadOnly)
    }

    // MARK: - UnitModePref

    func testUnitModePrefAllCasesUniqueRawValues() {
        let rawValues = UnitModePref.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "All UnitModePref cases must have unique rawValues")
    }

    func testUnitModePrefFixedMBConvertsToUnitMode() {
        let result = UnitModePref.fixedMB.toUnitMode()
        XCTAssertEqual(result, SpeedFormatter.UnitMode.fixedMB)
    }

    func testUnitModePrefAutoConvertsToUnitMode() {
        XCTAssertEqual(UnitModePref.auto.toUnitMode(), SpeedFormatter.UnitMode.auto)
    }

    func testUnitModePrefFixedKBConvertsToUnitMode() {
        XCTAssertEqual(UnitModePref.fixedKB.toUnitMode(), SpeedFormatter.UnitMode.fixedKB)
    }

    func testUnitModePrefFixedGBConvertsToUnitMode() {
        XCTAssertEqual(UnitModePref.fixedGB.toUnitMode(), SpeedFormatter.UnitMode.fixedGB)
    }

    // MARK: - UpdateIntervalPref

    func testUpdateIntervalPrefTwoSecondsRawValue() {
        XCTAssertEqual(UpdateIntervalPref.twoSeconds.rawValue, 2)
    }

    func testUpdateIntervalPrefOneSecondRawValue() {
        XCTAssertEqual(UpdateIntervalPref.oneSecond.rawValue, 1)
    }

    func testUpdateIntervalPrefFiveSecondsRawValue() {
        XCTAssertEqual(UpdateIntervalPref.fiveSeconds.rawValue, 5)
    }

    func testUpdateIntervalPrefDuration() {
        XCTAssertEqual(UpdateIntervalPref.twoSeconds.duration, .seconds(2))
        XCTAssertEqual(UpdateIntervalPref.oneSecond.duration, .seconds(1))
        XCTAssertEqual(UpdateIntervalPref.fiveSeconds.duration, .seconds(5))
    }
}
