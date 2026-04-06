import Foundation
import Network

/// Upload/download speed in bytes per second
struct Speed: Equatable, Sendable {
    let bytesInPerSecond: Double   // download
    let bytesOutPerSecond: Double  // upload

    static let zero = Speed(bytesInPerSecond: 0, bytesOutPerSecond: 0)

    static func + (lhs: Speed, rhs: Speed) -> Speed {
        Speed(
            bytesInPerSecond: lhs.bytesInPerSecond + rhs.bytesInPerSecond,
            bytesOutPerSecond: lhs.bytesOutPerSecond + rhs.bytesOutPerSecond
        )
    }
}

/// Raw byte counters from a single sysctl read
struct ByteCounters: Equatable, Sendable {
    let bytesIn: UInt64   // ifi_ibytes
    let bytesOut: UInt64  // ifi_obytes
}

/// Metadata about a detected network interface
struct InterfaceInfo: Equatable, Sendable, Identifiable {
    let bsdName: String        // e.g. "en0"
    let displayName: String    // e.g. "Wi-Fi" (resolved via SystemConfiguration, per D-07)
    let type: NWInterface.InterfaceType
    let index: Int32           // kernel interface index for sysctl

    var id: String { bsdName }
}

/// Speed data for a single interface at a point in time
struct InterfaceSpeed: Equatable, Sendable, Identifiable {
    let interface: InterfaceInfo
    let speed: Speed

    var id: String { interface.id }
}

/// Complete snapshot of all interface speeds + aggregate (per D-08)
struct NetworkSnapshot: Equatable, Sendable {
    let interfaceSpeeds: [InterfaceSpeed]
    let aggregateSpeed: Speed
    let timestamp: Date

    static let empty = NetworkSnapshot(
        interfaceSpeeds: [],
        aggregateSpeed: .zero,
        timestamp: .now
    )
}
