import GRDB
import Foundation

/// A raw network throughput sample captured every ~10 seconds per interface.
///
/// Maps to the `raw_samples` table. Pruned after 24 hours (D-07).
/// The `interfaceId` matches ``InterfaceInfo/bsdName`` (e.g., "en0").
struct RawSample: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "raw_samples"

    var id: Int64?
    var interfaceId: String    // BSD name (e.g., "en0") -- matches InterfaceInfo.bsdName
    var timestamp: Double      // Unix epoch seconds (UTC)
    var bytesIn: Double        // Total bytes received in this 10s window
    var bytesOut: Double       // Total bytes sent in this 10s window
    var duration: Double       // Actual elapsed seconds (close to 10.0)

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // Type-safe column references for queries
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let interfaceId = Column(CodingKeys.interfaceId)
        static let timestamp = Column(CodingKeys.timestamp)
        static let bytesIn = Column(CodingKeys.bytesIn)
        static let bytesOut = Column(CodingKeys.bytesOut)
        static let duration = Column(CodingKeys.duration)
    }
}
