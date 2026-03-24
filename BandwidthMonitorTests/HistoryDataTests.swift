import XCTest
@testable import BandwidthMonitor

final class HistoryDataTests: XCTestCase {

    // MARK: - HistoryTimeRange tier mapping

    func testOneHourTierIsMinute() {
        XCTAssertEqual(HistoryTimeRange.oneHour.tier, .minute)
    }

    func testTwentyFourHoursTierIsHour() {
        XCTAssertEqual(HistoryTimeRange.twentyFourHours.tier, .hour)
    }

    func testSevenDaysTierIsDay() {
        XCTAssertEqual(HistoryTimeRange.sevenDays.tier, .day)
    }

    func testThirtyDaysTierIsDay() {
        XCTAssertEqual(HistoryTimeRange.thirtyDays.tier, .day)
    }

    // MARK: - HistoryTimeRange timeInterval

    func testOneHourTimeInterval() {
        XCTAssertEqual(HistoryTimeRange.oneHour.timeInterval, 3600)
    }

    func testTwentyFourHoursTimeInterval() {
        XCTAssertEqual(HistoryTimeRange.twentyFourHours.timeInterval, 86400)
    }

    func testSevenDaysTimeInterval() {
        XCTAssertEqual(HistoryTimeRange.sevenDays.timeInterval, 604800)
    }

    func testThirtyDaysTimeInterval() {
        XCTAssertEqual(HistoryTimeRange.thirtyDays.timeInterval, 2_592_000)
    }

    // MARK: - HistoryTimeRange calendarUnit

    func testOneHourCalendarUnit() {
        XCTAssertEqual(HistoryTimeRange.oneHour.calendarUnit, .minute)
    }

    func testTwentyFourHoursCalendarUnit() {
        XCTAssertEqual(HistoryTimeRange.twentyFourHours.calendarUnit, .hour)
    }

    func testSevenDaysCalendarUnit() {
        XCTAssertEqual(HistoryTimeRange.sevenDays.calendarUnit, .day)
    }

    func testThirtyDaysCalendarUnit() {
        XCTAssertEqual(HistoryTimeRange.thirtyDays.calendarUnit, .day)
    }

    // MARK: - HistoryTimeRange displayLabel

    func testDisplayLabels() {
        XCTAssertEqual(HistoryTimeRange.oneHour.displayLabel, "1H")
        XCTAssertEqual(HistoryTimeRange.twentyFourHours.displayLabel, "24H")
        XCTAssertEqual(HistoryTimeRange.sevenDays.displayLabel, "7D")
        XCTAssertEqual(HistoryTimeRange.thirtyDays.displayLabel, "30D")
    }

    // MARK: - ChartDataPoint

    func testChartDataPointTotalBytes() {
        let point = ChartDataPoint(
            timestamp: Date(),
            totalBytesIn: 1000.0,
            totalBytesOut: 500.0
        )
        XCTAssertEqual(point.totalBytes, 1500.0)
    }

    func testChartDataPointConformsToIdentifiable() {
        let point = ChartDataPoint(
            timestamp: Date(),
            totalBytesIn: 100.0,
            totalBytesOut: 50.0
        )
        // Identifiable requires an `id` property -- just verify it exists and is unique
        let point2 = ChartDataPoint(
            timestamp: Date(),
            totalBytesIn: 100.0,
            totalBytesOut: 50.0
        )
        XCTAssertNotEqual(point.id, point2.id, "Each ChartDataPoint should have a unique id")
    }
}
