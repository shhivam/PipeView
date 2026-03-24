import XCTest
@testable import BandwidthMonitor

final class ChartAxisFormatterTests: XCTestCase {

    // MARK: - selectUnit

    func test_selectUnit_zeroReturnsKB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 0), .KB)
    }

    func test_selectUnit_smallValueReturnsKB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 500), .KB)
    }

    func test_selectUnit_belowMillionReturnsKB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 999_999), .KB)
    }

    func test_selectUnit_exactMillionReturnsMB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 1_000_000), .MB)
    }

    func test_selectUnit_midRangeReturnsMB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 500_000_000), .MB)
    }

    func test_selectUnit_exactBillionReturnsGB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 1_000_000_000), .GB)
    }

    func test_selectUnit_largeValueReturnsGB() {
        XCTAssertEqual(ChartAxisFormatter.selectUnit(forMax: 5_000_000_000), .GB)
    }

    // MARK: - ByteUnit.divisor

    func test_byteUnit_divisors() {
        XCTAssertEqual(ChartAxisFormatter.ByteUnit.KB.divisor, 1_000)
        XCTAssertEqual(ChartAxisFormatter.ByteUnit.MB.divisor, 1_000_000)
        XCTAssertEqual(ChartAxisFormatter.ByteUnit.GB.divisor, 1_000_000_000)
    }

    // MARK: - niceTickValues

    func test_niceTickValues_typicalMBRange() {
        let ticks = ChartAxisFormatter.niceTickValues(maxBytes: 110_000_000, unit: .MB)
        XCTAssertEqual(ticks.count, 5, "Should return exactly 5 tick values")
        XCTAssertEqual(ticks.first, 0, "First tick should be 0")
        XCTAssertGreaterThanOrEqual(ticks.last!, 110_000_000, "Last tick should cover maxBytes")
    }

    func test_niceTickValues_allValuesAreRawBytes() {
        let ticks = ChartAxisFormatter.niceTickValues(maxBytes: 110_000_000, unit: .MB)
        // All values should be in raw bytes (multiples of the unit divisor)
        for tick in ticks {
            XCTAssertEqual(tick.truncatingRemainder(dividingBy: 1), 0,
                           "Tick \(tick) should be a whole number of bytes")
        }
    }

    func test_niceTickValues_zeroMaxDoesNotCrash() {
        let ticks = ChartAxisFormatter.niceTickValues(maxBytes: 0, unit: .KB)
        XCTAssertFalse(ticks.isEmpty, "Should return values even for zero max")
        XCTAssertEqual(ticks.first, 0, "First tick should be 0")
    }

    func test_niceTickValues_niceMaxFor73MB() {
        // 73 MB should produce a nice max of 75 or 80
        let ticks = ChartAxisFormatter.niceTickValues(maxBytes: 73_000_000, unit: .MB)
        let niceMax = ticks.last! / ChartAxisFormatter.ByteUnit.MB.divisor
        XCTAssertTrue(niceMax == 75 || niceMax == 80 || niceMax == 100,
                      "Nice max for 73 should be 75, 80, or 100 but got \(niceMax)")
    }

    func test_niceTickValues_niceMaxFor4_5MB() {
        // 4.5 MB should produce a nice max of 5
        let ticks = ChartAxisFormatter.niceTickValues(maxBytes: 4_500_000, unit: .MB)
        let niceMax = ticks.last! / ChartAxisFormatter.ByteUnit.MB.divisor
        XCTAssertEqual(niceMax, 5, "Nice max for 4.5 should be 5")
    }

    // MARK: - formatTick

    func test_formatTick_integerMB() {
        XCTAssertEqual(ChartAxisFormatter.formatTick(50_000_000, unit: .MB), "50")
    }

    func test_formatTick_decimalMB() {
        XCTAssertEqual(ChartAxisFormatter.formatTick(2_500_000, unit: .MB), "2.5")
    }

    func test_formatTick_zero() {
        XCTAssertEqual(ChartAxisFormatter.formatTick(0, unit: .MB), "0")
    }

    func test_formatTick_largeValueNoDecimal() {
        XCTAssertEqual(ChartAxisFormatter.formatTick(150_000_000, unit: .MB), "150")
    }

    func test_formatTick_GB() {
        XCTAssertEqual(ChartAxisFormatter.formatTick(1_000_000_000, unit: .GB), "1")
    }

    // MARK: - yAxisMaxValue

    func test_yAxisMaxValue_emptyDataReturnsFloor() {
        let result = ChartAxisFormatter.yAxisMaxValue(dataPoints: [])
        XCTAssertEqual(result, 1024, "Empty data should return 1024 floor")
    }

    func test_yAxisMaxValue_appliesTenPercentHeadroom() {
        let point = ChartDataPoint(
            timestamp: Date(),
            totalBytesIn: 100_000_000,
            totalBytesOut: 50_000_000
        )
        let result = ChartAxisFormatter.yAxisMaxValue(dataPoints: [point])
        // max(totalBytesIn, totalBytesOut) = 100_000_000, * 1.1 = 110_000_000
        XCTAssertEqual(result, 110_000_000, accuracy: 1,
                       "Should apply 10% headroom to max value")
    }

    func test_yAxisMaxValue_floorWinsOverSmallValue() {
        let point = ChartDataPoint(
            timestamp: Date(),
            totalBytesIn: 500,
            totalBytesOut: 100
        )
        let result = ChartAxisFormatter.yAxisMaxValue(dataPoints: [point])
        // max(500, 100) * 1.1 = 550, but floor is 1024
        XCTAssertEqual(result, 1024, "Floor should win over small headroom value")
    }
}
