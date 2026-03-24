import Foundation

/// Time range options for the history chart view.
/// Maps each range to its aggregation tier, time interval, and calendar unit.
enum HistoryTimeRange: String, CaseIterable, Sendable {
    case oneHour = "1H"
    case twentyFourHours = "24H"
    case sevenDays = "7D"
    case thirtyDays = "30D"

    /// The aggregation tier to query for this time range.
    var tier: AggregationTier {
        // Stub: returns wrong tier to fail tests
        return .month
    }

    /// The total time span in seconds.
    var timeInterval: TimeInterval {
        // Stub: returns wrong value to fail tests
        return 0
    }

    /// Calendar component for BarMark x-axis unit (avoids Pitfall 1: unit mismatch).
    var calendarUnit: Calendar.Component {
        // Stub: returns wrong unit to fail tests
        return .year
    }

    /// Display label for the segmented control.
    var displayLabel: String {
        return rawValue
    }
}
