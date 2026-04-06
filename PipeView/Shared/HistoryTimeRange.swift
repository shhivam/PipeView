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
        switch self {
        case .oneHour:        return .minute
        case .twentyFourHours: return .hour
        case .sevenDays:      return .day
        case .thirtyDays:     return .day
        }
    }

    /// The total time span in seconds.
    var timeInterval: TimeInterval {
        switch self {
        case .oneHour:        return 3_600
        case .twentyFourHours: return 86_400
        case .sevenDays:      return 604_800
        case .thirtyDays:     return 2_592_000
        }
    }

    /// Calendar component for BarMark x-axis unit (avoids Pitfall 1: unit mismatch).
    var calendarUnit: Calendar.Component {
        switch self {
        case .oneHour:        return .minute
        case .twentyFourHours: return .hour
        case .sevenDays:      return .day
        case .thirtyDays:     return .day
        }
    }

    /// Display label for the segmented control.
    var displayLabel: String {
        return rawValue
    }
}
