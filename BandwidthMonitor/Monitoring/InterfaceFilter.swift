import Network

/// Determines which network interfaces to monitor.
/// Per D-05: Track physical (Wi-Fi, Ethernet, Cellular) + VPN (utun).
/// Filter out loopback (lo0), bridge, vnic, vmnet.
enum InterfaceFilter {
    /// Prefixes of BSD interface names to always exclude
    private static let blockedPrefixes = ["lo", "bridge", "vnic", "vmnet", "awdl", "llw", "anpi", "ap"]

    /// Prefixes of BSD interface names that are allowed when type is .other (VPN tunnels)
    private static let allowedOtherPrefixes = ["utun", "ipsec"]

    /// NWInterface types that are always allowed (before name filtering)
    private static let allowedTypes: Set<NWInterface.InterfaceType> = [
        .wifi, .wiredEthernet, .cellular
    ]

    /// Returns true if the interface should be monitored.
    static func shouldInclude(bsdName: String, type: NWInterface.InterfaceType) -> Bool {
        // Always block loopback type
        if type == .loopback { return false }

        // Block by name prefix
        for prefix in blockedPrefixes {
            if bsdName.hasPrefix(prefix) { return false }
        }

        // Allow standard physical types
        if allowedTypes.contains(type) { return true }

        // For .other type, only allow VPN tunnel prefixes
        if type == .other {
            return allowedOtherPrefixes.contains(where: { bsdName.hasPrefix($0) })
        }

        return false
    }
}
