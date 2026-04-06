import Darwin
import os

/// Encapsulates all unsafe sysctl C interop for reading per-interface byte counters.
/// Uses IFMIB_IFDATA + IFDATA_GENERAL to get ifmibdata with if_data64 (64-bit counters).
/// This avoids 1KiB batching and 4GiB truncation bugs of NET_RT_IFLIST2.
struct SysctlReader {
    private let logger = Logger.monitoring

    /// Get total number of network interfaces known to the kernel.
    func interfaceCount() -> Int32? {
        var mib: [Int32] = [
            CTL_NET,
            PF_LINK,
            NETLINK_GENERIC,
            IFMIB_SYSTEM,
            IFMIB_IFCOUNT
        ]
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size

        guard sysctl(&mib, UInt32(mib.count), &count, &size, nil, 0) == 0 else {
            logger.debug("sysctl IFMIB_IFCOUNT failed: errno=\(errno)")
            return nil
        }
        return count
    }

    /// Read 64-bit byte counters for a specific interface by kernel index.
    /// Returns nil for sparse/missing indices (ENOENT is expected, per Pitfall 1).
    func readCounters(forInterfaceIndex index: Int32) -> ByteCounters? {
        var mib: [Int32] = [
            CTL_NET,
            PF_LINK,
            NETLINK_GENERIC,
            IFMIB_IFDATA,
            index,
            IFDATA_GENERAL
        ]
        var data = ifmibdata()
        var size = MemoryLayout<ifmibdata>.size

        guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 else {
            return nil  // ENOENT for sparse indices is normal
        }

        return ByteCounters(
            bytesIn: data.ifmd_data.ifi_ibytes,
            bytesOut: data.ifmd_data.ifi_obytes
        )
    }

    /// Read the BSD interface name for a given kernel index.
    /// Used to cross-reference sysctl indices with NWPathMonitor interface names.
    func interfaceName(forIndex index: Int32) -> String? {
        var mib: [Int32] = [
            CTL_NET,
            PF_LINK,
            NETLINK_GENERIC,
            IFMIB_IFDATA,
            index,
            IFDATA_GENERAL
        ]
        var data = ifmibdata()
        var size = MemoryLayout<ifmibdata>.size

        guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 else {
            return nil
        }

        // ifmd_name is a C fixed-size array imported as a tuple.
        // Use withUnsafePointer + withMemoryRebound to extract as String.
        return withUnsafePointer(to: data.ifmd_name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(IFNAMSIZ)) {
                String(cString: $0)
            }
        }
    }
}
