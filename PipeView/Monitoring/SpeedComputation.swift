import Foundation

/// Compute speed from consecutive byte counter readings.
/// Per D-03: Raw byte delta divided by elapsed time, no smoothing.
/// Per D-04: Counter resets (current < previous) report zero.
func computeSpeed(
    previous: ByteCounters,
    current: ByteCounters,
    elapsed: Double
) -> Speed {
    guard elapsed > 0 else { return .zero }

    let deltaIn: UInt64 = current.bytesIn >= previous.bytesIn
        ? current.bytesIn - previous.bytesIn
        : 0  // D-04: counter reset
    let deltaOut: UInt64 = current.bytesOut >= previous.bytesOut
        ? current.bytesOut - previous.bytesOut
        : 0  // D-04: counter reset

    return Speed(
        bytesInPerSecond: Double(deltaIn) / elapsed,
        bytesOutPerSecond: Double(deltaOut) / elapsed
    )
}
