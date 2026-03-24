import Network
import Observation

/// Tab state for the panel's segmented control (per D-07)
/// Order determines segmented control layout: Dashboard | Preferences
enum PopoverTab: String, CaseIterable, Sendable {
    case dashboard = "Dashboard"
    case preferences = "Preferences"
}

/// Observable state shared between StatusBarController and PopoverContentView
/// so that tab changes from both the segmented control and the context menu
/// trigger SwiftUI view updates.
@MainActor @Observable
final class PopoverState {
    var selectedTab: PopoverTab = .dashboard
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
