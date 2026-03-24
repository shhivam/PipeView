import Foundation

/// A single data point for chart consumption.
/// Aggregates bytes across all interfaces for a given time bucket.
struct ChartDataPoint: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let totalBytesIn: Double
    let totalBytesOut: Double

    var totalBytes: Double {
        return totalBytesIn + totalBytesOut
    }
}
