import Network
import SystemConfiguration
import os

/// Detects active network interfaces using NWPathMonitor (event-driven, per D-06)
/// and resolves BSD names to human-readable names via SystemConfiguration (per D-07).
/// Re-enumerates on each poll cycle as safety net (per D-06).
final class InterfaceDetector: @unchecked Sendable {
    /// Current list of active, filtered interfaces. Updated on path changes and poll queries.
    private(set) var activeInterfaces: [InterfaceInfo] = []

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.bandwidth-monitor.interface-detector")
    private let reader = SysctlReader()
    private let logger = Logger.interfaces

    /// Cache of BSD name -> display name from SystemConfiguration.
    /// Rebuilt on path changes since interfaces may appear/disappear.
    private var nameMap: [String: String] = [:]

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
        logger.info("InterfaceDetector started NWPathMonitor")
    }

    func stopMonitoring() {
        monitor.cancel()
        logger.info("InterfaceDetector stopped NWPathMonitor")
    }

    /// Re-enumerate interfaces from current NWPath.
    /// Called by NetworkMonitor on each poll cycle as safety net (per D-06).
    func refreshInterfaces() {
        let path = monitor.currentPath
        handlePathUpdate(path)
    }

    private func handlePathUpdate(_ path: NWPath) {
        nameMap = buildNameMap()

        let detected = path.availableInterfaces
            .filter { InterfaceFilter.shouldInclude(bsdName: $0.name, type: $0.type) }
            .compactMap { nwInterface -> InterfaceInfo? in
                guard let index = interfaceIndex(for: nwInterface.name) else {
                    logger.debug("Could not find kernel index for \(nwInterface.name)")
                    return nil
                }
                let displayName = nameMap[nwInterface.name] ?? nwInterface.name
                return InterfaceInfo(
                    bsdName: nwInterface.name,
                    displayName: displayName,
                    type: nwInterface.type,
                    index: index
                )
            }

        activeInterfaces = detected
        logger.info("Active interfaces: \(detected.map(\.bsdName).joined(separator: ", "))")
    }

    /// Build BSD name -> human-readable display name map via SystemConfiguration (per D-07).
    private func buildNameMap() -> [String: String] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return [:]
        }
        var map: [String: String] = [:]
        for iface in interfaces {
            guard let bsd = SCNetworkInterfaceGetBSDName(iface) as String? else {
                continue
            }
            let display = SCNetworkInterfaceGetLocalizedDisplayName(iface) as String?
            map[bsd] = display ?? bsd
        }
        return map
    }

    /// Look up kernel interface index by iterating IFMIB_IFDATA rows matching ifmd_name.
    /// The kernel interface table is sparse (Pitfall 1) -- ENOENT indices are skipped.
    private func interfaceIndex(for bsdName: String) -> Int32? {
        guard let count = reader.interfaceCount() else { return nil }
        for i: Int32 in 1...count {
            if let name = reader.interfaceName(forIndex: i), name == bsdName {
                return i
            }
        }
        return nil
    }
}
