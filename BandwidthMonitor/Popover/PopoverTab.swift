import Network

/// Tab state for the popover's segmented control (per D-04, D-06)
enum PopoverTab: String, CaseIterable, Sendable {
    case metrics = "Metrics"
    case preferences = "Preferences"
}

/// Maps an interface's type and BSD name to the appropriate SF Symbol (per D-08).
///
/// - VPN/utun tunnels report as `.other` in `NWInterface.InterfaceType`,
///   so the `utun` prefix check MUST come before the switch on interface type.
func sfSymbolName(for interface: InterfaceInfo) -> String {
    // VPN tunnels (utun0, utun1, ...) report as .other — check BSD name first
    if interface.bsdName.hasPrefix("utun") {
        return "lock.shield"
    }

    switch interface.type {
    case .wifi:
        return "wifi"
    case .wiredEthernet:
        return "cable.connector.horizontal"
    default:
        return "network"
    }
}
