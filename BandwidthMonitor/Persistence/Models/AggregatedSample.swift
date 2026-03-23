import GRDB
import Foundation

/// Protocol shared by all aggregation tier record types (per D-12).
///
/// Each tier stores the same set of fields: sum of bytes, peak speeds,
/// and sample count. Separate concrete types are used because GRDB's
/// `databaseTableName` is a static property.
protocol AggregatedRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64? { get set }
    var interfaceId: String { get }
    var bucketTimestamp: Double { get }     // Start of time bucket (UTC epoch)
    var totalBytesIn: Double { get }       // Sum of bytes received
    var totalBytesOut: Double { get }      // Sum of bytes sent
    var peakBytesInPerSec: Double { get }  // Max download speed in window
    var peakBytesOutPerSec: Double { get } // Max upload speed in window
    var sampleCount: Int { get }           // Number of source records aggregated
}

/// Enum identifying aggregation tiers for programmatic use.
enum AggregationTier: String, CaseIterable, Sendable {
    case minute, hour, day, week, month

    var tableName: String {
        switch self {
        case .minute: return "minute_samples"
        case .hour:   return "hour_samples"
        case .day:    return "day_samples"
        case .week:   return "week_samples"
        case .month:  return "month_samples"
        }
    }

    /// Bucket size in seconds (for floor-division bucketing).
    /// Week and month use sentinel values -- actual bucketing needs special SQL.
    var bucketSeconds: Double {
        switch self {
        case .minute: return 60
        case .hour:   return 3600
        case .day:    return 86400
        case .week:   return 604800       // 7 * 86400
        case .month:  return 2_592_000    // ~30 days, not used for bucketing (use strftime)
        }
    }
}

// MARK: - Per-Tier Record Types

/// Aggregated network throughput for 1-minute buckets.
struct MinuteSample: AggregatedRecord {
    static let databaseTableName = "minute_samples"
    var id: Int64?
    var interfaceId: String
    var bucketTimestamp: Double
    var totalBytesIn: Double
    var totalBytesOut: Double
    var peakBytesInPerSec: Double
    var peakBytesOutPerSec: Double
    var sampleCount: Int

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }

    enum Columns {
        static let interfaceId = Column(CodingKeys.interfaceId)
        static let bucketTimestamp = Column(CodingKeys.bucketTimestamp)
        static let totalBytesIn = Column(CodingKeys.totalBytesIn)
        static let totalBytesOut = Column(CodingKeys.totalBytesOut)
        static let sampleCount = Column(CodingKeys.sampleCount)
    }
}

/// Aggregated network throughput for 1-hour buckets.
struct HourSample: AggregatedRecord {
    static let databaseTableName = "hour_samples"
    var id: Int64?
    var interfaceId: String
    var bucketTimestamp: Double
    var totalBytesIn: Double
    var totalBytesOut: Double
    var peakBytesInPerSec: Double
    var peakBytesOutPerSec: Double
    var sampleCount: Int

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

/// Aggregated network throughput for 1-day buckets.
struct DaySample: AggregatedRecord {
    static let databaseTableName = "day_samples"
    var id: Int64?
    var interfaceId: String
    var bucketTimestamp: Double
    var totalBytesIn: Double
    var totalBytesOut: Double
    var peakBytesInPerSec: Double
    var peakBytesOutPerSec: Double
    var sampleCount: Int

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

/// Aggregated network throughput for 1-week buckets.
struct WeekSample: AggregatedRecord {
    static let databaseTableName = "week_samples"
    var id: Int64?
    var interfaceId: String
    var bucketTimestamp: Double
    var totalBytesIn: Double
    var totalBytesOut: Double
    var peakBytesInPerSec: Double
    var peakBytesOutPerSec: Double
    var sampleCount: Int

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

/// Aggregated network throughput for 1-month buckets.
struct MonthSample: AggregatedRecord {
    static let databaseTableName = "month_samples"
    var id: Int64?
    var interfaceId: String
    var bucketTimestamp: Double
    var totalBytesIn: Double
    var totalBytesOut: Double
    var peakBytesInPerSec: Double
    var peakBytesOutPerSec: Double
    var sampleCount: Int

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
