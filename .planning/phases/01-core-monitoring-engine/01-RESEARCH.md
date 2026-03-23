# Phase 1: Core Monitoring Engine - Research

**Researched:** 2026-03-23
**Domain:** macOS kernel-level network statistics via sysctl, Swift concurrency polling, interface enumeration
**Confidence:** HIGH

## Summary

Phase 1 builds the foundational network monitoring engine -- no UI, no persistence, just accurate per-interface byte counting and speed computation. The technical core is the `sysctl` system call with `IFMIB_IFDATA` + `IFDATA_GENERAL`, which returns an `ifmibdata` struct containing `if_data64` with 64-bit byte counters (`ifi_ibytes`, `ifi_obytes`). This avoids the 1KiB batching and 4GiB truncation bugs that plague the alternative `NET_RT_IFLIST2` API.

Interface detection uses `NWPathMonitor` for event-driven change notifications and `SystemConfiguration` (`SCNetworkInterfaceCopyAll` + `SCNetworkInterfaceGetLocalizedDisplayName`) for mapping BSD names (en0) to human-readable names (Wi-Fi). The polling loop uses Swift structured concurrency (`Task.sleep(for:tolerance:)`) with a 2-second default interval.

The engine must be designed as a clean, testable module with no UI dependencies. It publishes per-interface speed samples and aggregate totals that downstream phases (Menu Bar Display, Data Persistence) will consume. Sleep/wake handling via `NSWorkspace.didWakeNotification` prevents false spikes from accumulated byte deltas during system sleep.

**Primary recommendation:** Build the engine as a `@MainActor @Observable` class with a structured concurrency polling loop, using `sysctl` IFMIB_IFDATA for byte counters and `NWPathMonitor` for interface change detection.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Default polling interval is 2 seconds -- balances responsiveness with energy efficiency
- **D-02:** Interval is configurable internally (parameter, not hardcoded constant) so Phase 5 preferences can expose 1s/2s/5s options later
- **D-03:** Raw byte delta per interval -- exact bytes transferred since last sample, divided by elapsed time. No smoothing or averaging at the engine level
- **D-04:** Counter resets (new counter value < previous) report zero for that sample -- skip and move on, avoids false spikes
- **D-05:** Track physical interfaces (Wi-Fi, Ethernet, Cellular) plus VPN tunnels (utun). Filter out loopback (lo0), bridge interfaces, and virtual adapters (vnic, vmnet for Docker/Parallels)
- **D-06:** NWPathMonitor as primary interface change detection (event-driven, immediate) plus re-enumerate the interface list on each poll cycle as a safety net -- never misses a change
- **D-07:** Resolve BSD names to human-readable names in the engine using SystemConfiguration (en0 -> "Wi-Fi", en1 -> "Ethernet"). Downstream phases display friendly names directly
- **D-08:** Engine computes both per-interface speeds AND a summed total across all active interfaces. Phase 2 menu bar can show the total without re-computing
- **D-09:** Detect wake via NSWorkspace notifications. Discard the first post-wake byte delta (it spans the entire sleep period and would show a false spike). Resume normal 2s polling after
- **D-10:** Skip failed sysctl samples silently, log at debug level (os_log). After 5+ consecutive failures, log a warning. Do not surface errors to UI -- a single missed 2s sample is invisible to the user

### Claude's Discretion
- Internal data model / struct design for speed samples
- Actor vs class vs protocol architecture for the monitoring engine
- Memory management for the polling loop
- Exact os_log categories and levels
- Task.sleep tolerance value for energy efficiency
- Debounce duration for NWPathMonitor rapid events

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MON-01 | App measures real-time upload and download throughput per network interface using sysctl | sysctl IFMIB_IFDATA + IFDATA_GENERAL returns ifmibdata with if_data64 containing 64-bit ifi_ibytes/ifi_obytes counters per interface index. Enumerate via IFMIB_IFCOUNT. Delta between samples divided by elapsed time gives throughput. |
| MON-02 | App identifies and enumerates active network interfaces (Wi-Fi, Ethernet, VPN tunnels) filtering loopback and inactive | NWPathMonitor.currentPath.availableInterfaces provides event-driven detection. SCNetworkInterfaceCopyAll + SCNetworkInterfaceGetBSDName/GetLocalizedDisplayName maps BSD names to friendly names. Filter by interface type and name prefix (exclude lo0, bridge*, vnic*, vmnet*). |
| MON-06 | App uses less than 1% CPU and minimal RAM during normal operation | Task.sleep(for:tolerance:) with generous tolerance allows CPU wake-up coalescing. sysctl is a single kernel syscall per interface -- negligible cost. 2-second polling interval means ~0.5 polls/second. Deque ring buffer bounds memory. |
</phase_requirements>

## Standard Stack

### Core (Phase 1 only -- no UI or persistence dependencies)

| Library/API | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| sysctl (IFMIB_IFDATA) | Kernel API (macOS 10.0+) | Read 64-bit per-interface byte counters | Returns `ifmibdata` with `if_data64` struct. Avoids 1KiB batching (unsigned apps) and 4GiB truncation bugs of NET_RT_IFLIST2. Verified in XNU kernel source: `if_data_internal_to_if_data64()` conversion. |
| Network framework (NWPathMonitor) | macOS 10.14+ | Detect interface changes event-driven | Apple's modern networking framework. `currentPath.availableInterfaces` gives ordered NWInterface list with type info. Replaces deprecated SCNetworkReachability. |
| SystemConfiguration | macOS 10.1+ | Map BSD names to human-readable names | `SCNetworkInterfaceCopyAll()` enumerates all configured interfaces. `SCNetworkInterfaceGetLocalizedDisplayName()` returns user-visible names. `SCNetworkInterfaceGetBSDName()` returns BSD names. |
| os.Logger | macOS 11+ | Structured logging with subsystem/category | Apple's recommended logging. Subsystem: bundle identifier. Categories: "monitoring", "interfaces", "lifecycle". Negligible performance cost -- can stay in release builds. |
| Swift Concurrency | Swift 5.5+ | Polling loop, cancellation, MainActor | `Task.sleep(for:tolerance:)` for energy-efficient polling. Structured concurrency for clean lifecycle management. `@MainActor` for SwiftUI integration. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-collections | 1.4.1 | Deque for in-memory sample ring buffer | Use `Deque<NetworkSample>` for bounded FIFO of recent samples. O(1) append and removeFirst vs Array's O(n) removeFirst. |

**Installation (for swift-collections only -- all others are system frameworks):**
```
// Package.swift or Xcode SPM
.package(url: "https://github.com/apple/swift-collections", from: "1.1.0")
// Product dependency: "DequeModule"
```

**Version verification:**
- swift-collections: 1.4.1 is latest (released March 2026, supports Swift 6.0/6.1/6.2)
- All other dependencies are system frameworks, no version management needed

## Project Constraints (from CLAUDE.md)

- **Platform**: macOS only -- native Swift
- **Architecture**: Hybrid AppKit + SwiftUI (~20% AppKit, ~80% SwiftUI)
- **Minimum target**: macOS 14+ (for @Observable macro)
- **Primary network API**: sysctl IFMIB_IFDATA (NOT NET_RT_IFLIST2, NOT getifaddrs)
- **Concurrency**: Use `Task.sleep(for:tolerance:)` in async loops, NOT DispatchSourceTimer
- **Package manager**: Swift Package Manager only (no CocoaPods, no Carthage)
- **Logging**: os_log / Logger framework
- **Avoid**: getifaddrs() (32-bit counters), NET_RT_IFLIST2 (batching + truncation), DispatchSourceTimer, per-app monitoring

## Architecture Patterns

### Recommended Module Structure
```
Sources/BandwidthMonitor/
  Monitoring/
    NetworkMonitor.swift        # Main @Observable engine class
    SysctlReader.swift          # Low-level sysctl wrapper (IFMIB_IFDATA)
    InterfaceDetector.swift     # NWPathMonitor + SCNetworkInterface mapping
    InterfaceFilter.swift       # Allowed/blocked interface logic
    NetworkSample.swift         # Data model structs
    SleepWakeHandler.swift      # NSWorkspace wake detection
  Logging/
    Loggers.swift               # Logger instances per subsystem/category
```

### Pattern 1: @Observable Engine with Structured Concurrency Polling

**What:** A `@MainActor @Observable` class that owns the polling lifecycle and publishes speed data that SwiftUI views can observe directly.

**When to use:** When the engine's output drives SwiftUI views (Phase 2+). The `@Observable` macro (macOS 14+) eliminates the need for `@Published` / `ObservableObject` boilerplate.

**Example:**
```swift
// Source: Apple documentation + CLAUDE.md stack decisions
import Observation
import os

@MainActor
@Observable
final class NetworkMonitor {
    // Published state -- SwiftUI views observe these automatically
    var interfaceSpeeds: [InterfaceSpeed] = []
    var aggregateSpeed: Speed = .zero

    // Configuration
    var pollingInterval: Duration = .seconds(2)

    // Internal state
    private var pollingTask: Task<Void, Never>?
    private var previousCounters: [String: ByteCounters] = [:]
    private var previousTimestamp: ContinuousClock.Instant?
    private var consecutiveFailures: Int = 0
    private var discardNextSample: Bool = false

    private let reader = SysctlReader()
    private let interfaceDetector = InterfaceDetector()
    private let sleepWakeHandler = SleepWakeHandler()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bandwidth-monitor",
        category: "monitoring"
    )

    func start() {
        pollingTask?.cancel()
        interfaceDetector.startMonitoring()
        sleepWakeHandler.onWake = { [weak self] in
            self?.discardNextSample = true
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.pollOnce()
                try? await Task.sleep(
                    for: self?.pollingInterval ?? .seconds(2),
                    tolerance: .milliseconds(500)
                )
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        interfaceDetector.stopMonitoring()
    }

    private func pollOnce() {
        let now = ContinuousClock.Instant.now
        let activeInterfaces = interfaceDetector.activeInterfaces

        var newSpeeds: [InterfaceSpeed] = []

        for iface in activeInterfaces {
            guard let counters = reader.readCounters(
                forInterfaceIndex: iface.index
            ) else {
                consecutiveFailures += 1
                if consecutiveFailures >= 5 {
                    logger.warning("sysctl failed \(self.consecutiveFailures) consecutive times for \(iface.bsdName)")
                }
                continue
            }
            consecutiveFailures = 0

            if discardNextSample {
                // Post-wake: record counters but don't compute speed
                previousCounters[iface.bsdName] = counters
                continue
            }

            if let prev = previousCounters[iface.bsdName],
               let prevTime = previousTimestamp {
                let elapsed = now - prevTime
                let elapsedSeconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18

                let speed = computeSpeed(
                    previous: prev, current: counters, elapsed: elapsedSeconds
                )
                newSpeeds.append(InterfaceSpeed(
                    interface: iface, speed: speed
                ))
            }

            previousCounters[iface.bsdName] = counters
        }

        discardNextSample = false
        previousTimestamp = now
        interfaceSpeeds = newSpeeds
        aggregateSpeed = newSpeeds.reduce(.zero) { $0 + $1.speed }
    }
}
```

### Pattern 2: Isolated sysctl Reader (Pure C Interop)

**What:** A dedicated struct/class that encapsulates all unsafe C pointer manipulation for sysctl calls.

**When to use:** Always -- keeps unsafe code contained and testable.

**Example:**
```swift
// Source: macOS SDK headers (net/if_mib.h, net/if_var.h) + XNU kernel source
import Darwin

struct SysctlReader {
    /// Byte counters for a single interface snapshot
    struct ByteCounters {
        let bytesIn: UInt64    // ifi_ibytes
        let bytesOut: UInt64   // ifi_obytes
    }

    /// Get total number of network interfaces known to the kernel
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
            return nil
        }
        return count
    }

    /// Read byte counters for a specific interface by kernel index
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
            return nil
        }

        return ByteCounters(
            bytesIn: data.ifmd_data.ifi_ibytes,
            bytesOut: data.ifmd_data.ifi_obytes
        )
    }

    /// Read interface name from ifmibdata (for cross-referencing)
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

        return withUnsafePointer(to: data.ifmd_name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(IFNAMSIZ)) {
                String(cString: $0)
            }
        }
    }
}
```

### Pattern 3: Interface Detection with NWPathMonitor + SystemConfiguration

**What:** Combine NWPathMonitor for event-driven change detection with SCNetworkInterface for name resolution.

**Example:**
```swift
// Source: Apple NWPathMonitor docs + SystemConfiguration framework
import Network
import SystemConfiguration

final class InterfaceDetector {
    struct DetectedInterface {
        let bsdName: String       // e.g. "en0"
        let displayName: String   // e.g. "Wi-Fi"
        let type: NWInterface.InterfaceType
        let index: Int32          // kernel interface index
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.bandwidth-monitor.interface-detector")
    private(set) var activeInterfaces: [DetectedInterface] = []

    // Filter configuration (D-05)
    private let blockedPrefixes = ["lo", "bridge", "vnic", "vmnet"]
    private let allowedTypes: Set<NWInterface.InterfaceType> = [
        .wifi, .wiredEthernet, .cellular, .other  // .other catches utun VPN tunnels
    ]

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let interfaces = path.availableInterfaces
            .filter { iface in
                // Allow only known physical types + VPN
                allowedTypes.contains(iface.type)
            }
            .filter { iface in
                // Reject blocked prefixes
                !blockedPrefixes.contains(where: { iface.name.hasPrefix($0) })
            }

        let nameMap = buildNameMap()
        let detected = interfaces.compactMap { iface -> DetectedInterface? in
            guard let index = interfaceIndex(for: iface.name) else { return nil }
            return DetectedInterface(
                bsdName: iface.name,
                displayName: nameMap[iface.name] ?? iface.name,
                type: iface.type,
                index: index
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.activeInterfaces = detected
        }
    }

    /// Build BSD name -> display name map via SystemConfiguration
    private func buildNameMap() -> [String: String] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return [:]
        }
        var map: [String: String] = [:]
        for iface in interfaces {
            if let bsd = SCNetworkInterfaceGetBSDName(iface) as String?,
               let display = SCNetworkInterfaceGetLocalizedDisplayName(iface) as String? {
                map[bsd] = display
            }
        }
        return map
    }

    /// Look up kernel interface index by BSD name
    /// Iterate IFMIB_IFDATA rows 1..ifcount matching ifmd_name
    private func interfaceIndex(for bsdName: String) -> Int32? {
        let reader = SysctlReader()
        guard let count = reader.interfaceCount() else { return nil }
        for i: Int32 in 1...count {
            if let name = reader.interfaceName(forIndex: i), name == bsdName {
                return i
            }
        }
        return nil
    }
}
```

### Pattern 4: Speed Computation with Counter Reset Handling

**What:** Compute bytes/second from cumulative counter deltas, handling counter resets gracefully.

**Example:**
```swift
// Source: D-03, D-04 decisions
struct Speed: Equatable {
    let bytesInPerSecond: Double
    let bytesOutPerSecond: Double

    static let zero = Speed(bytesInPerSecond: 0, bytesOutPerSecond: 0)

    static func + (lhs: Speed, rhs: Speed) -> Speed {
        Speed(
            bytesInPerSecond: lhs.bytesInPerSecond + rhs.bytesInPerSecond,
            bytesOutPerSecond: lhs.bytesOutPerSecond + rhs.bytesOutPerSecond
        )
    }
}

func computeSpeed(
    previous: SysctlReader.ByteCounters,
    current: SysctlReader.ByteCounters,
    elapsed: Double
) -> Speed {
    guard elapsed > 0 else { return .zero }

    // D-04: Counter reset detection -- if new < old, report zero
    let deltaIn: UInt64 = current.bytesIn >= previous.bytesIn
        ? current.bytesIn - previous.bytesIn
        : 0
    let deltaOut: UInt64 = current.bytesOut >= previous.bytesOut
        ? current.bytesOut - previous.bytesOut
        : 0

    return Speed(
        bytesInPerSecond: Double(deltaIn) / elapsed,
        bytesOutPerSecond: Double(deltaOut) / elapsed
    )
}
```

### Anti-Patterns to Avoid

- **Using getifaddrs() for byte counting:** Returns 32-bit counters only (`if_data.ifi_ibytes` is `u_int32_t`). Overflows at 4 GB. The Stats app (exelban/stats) uses this approach -- it is wrong for modern high-bandwidth connections.
- **Using NET_RT_IFLIST2:** Subject to 1KiB batching for unsigned/adhoc-signed binaries and a 4GiB truncation kernel bug (rdar://106029568). Only works correctly for Apple-signed binaries.
- **Using DispatchSourceTimer for the polling loop:** Mixes GCD and structured concurrency. Use `Task.sleep(for:tolerance:)` in an async loop instead, which integrates cleanly with task cancellation and `@MainActor`.
- **Making NetworkMonitor a custom actor:** SwiftUI data models should NOT use custom actors. Use `@MainActor` annotation instead so SwiftUI views can observe properties without actor-hopping. This is explicitly recommended by Apple and Swift community.
- **Polling without tolerance:** Omitting the `tolerance` parameter from `Task.sleep` prevents the system from coalescing CPU wake-ups, wasting energy on a menu bar app that runs 24/7.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interface enumeration | Custom interface discovery via sysctl iteration | NWPathMonitor + SCNetworkInterfaceCopyAll | NWPathMonitor gives event-driven updates; SCNetworkInterface gives localized names. Both handle edge cases (Thunderbolt bridges, USB tethering) that manual filtering misses. |
| Ring buffer for samples | Custom Array-based circular buffer | `Deque` from swift-collections | Deque is O(1) append + removeFirst, backed by a ring buffer. Custom implementations are error-prone with capacity management. |
| Elapsed time measurement | `Date()` subtraction | `ContinuousClock` / `ContinuousClock.Instant` | ContinuousClock is monotonic -- not affected by NTP adjustments or timezone changes. `Date()` can jump forward/backward. |
| Sleep/wake detection | IOPowerNotification / Darwin notification center | `NSWorkspace.didWakeNotification` | NSWorkspace notifications are the standard AppKit approach. Higher-level, more reliable, and documented. |
| Logging | print() / NSLog | `os.Logger` | Logger is Apple's recommended framework. Subsystem/category filtering in Console.app. Zero overhead when messages are not being collected. |

**Key insight:** sysctl IFMIB_IFDATA is the one area where you genuinely interact with raw C APIs. Everything else -- interface detection, name resolution, wake handling, timing, logging -- has robust Swift/Apple frameworks.

## Common Pitfalls

### Pitfall 1: Sparse Interface Index Table
**What goes wrong:** Iterating interface indices 1 through `IFMIB_IFCOUNT` and assuming every index has a valid interface. Some indices return `ENOENT`.
**Why it happens:** The kernel interface table is sparse -- interfaces can be created and destroyed, leaving gaps in the index sequence.
**How to avoid:** When iterating indices, check `sysctl` return value. If `errno == ENOENT`, skip that index and continue. Do NOT treat ENOENT as a fatal error.
**Warning signs:** "Interface count says 12 but only found 8" in debug logs.

### Pitfall 2: Counter Overflow False Positives
**What goes wrong:** Treating counter decrease as "massive amount of data transferred" instead of a counter reset.
**Why it happens:** Although `if_data64` uses 64-bit counters (overflow at ~18 EB), interface teardown/recreation resets counters to zero.
**How to avoid:** Per D-04, if `current < previous`, report zero for that sample. Do not compute a wrapped delta.
**Warning signs:** Sudden multi-terabyte speed spikes after interface reconnection.

### Pitfall 3: Post-Sleep Byte Delta Spike
**What goes wrong:** First sample after system wake shows enormous "speed" because the byte delta accumulated over the entire sleep period is divided by one polling interval.
**Why it happens:** sysctl counters continue accumulating during network-level keepalives/background traffic while the app's timer was suspended.
**How to avoid:** Per D-09, listen for `NSWorkspace.didWakeNotification` and set a flag to discard the next sample's delta.
**Warning signs:** Brief display of "999 MB/s" after opening laptop lid.

### Pitfall 4: NWPathMonitor Rapid-Fire Updates
**What goes wrong:** `pathUpdateHandler` fires many times in quick succession during network transitions (e.g., switching from Wi-Fi to Ethernet, VPN connecting), causing expensive re-enumeration each time.
**Why it happens:** The kernel emits multiple path change notifications as the network stack transitions.
**How to avoid:** Debounce NWPathMonitor updates -- wait 200-500ms after the last change before re-enumerating. Or rely on the poll-cycle re-enumeration (D-06) as the primary mechanism.
**Warning signs:** High CPU usage during network interface changes.

### Pitfall 5: Missing utun VPN Interfaces
**What goes wrong:** VPN tunnel interfaces (utun0, utun1, etc.) are not detected because they have `NWInterface.InterfaceType.other`, not a specific VPN type.
**Why it happens:** Apple's Network framework classifies utun interfaces as `.other`. There is no `.vpn` interface type.
**How to avoid:** Include `.other` in the allowed interface types set, then filter by name prefix. Allow "utun" prefix, block other `.other` interfaces unless explicitly recognized.
**Warning signs:** VPN traffic not showing up in per-interface breakdown.

### Pitfall 6: ContinuousClock vs SuspendingClock for Elapsed Time
**What goes wrong:** Using `SuspendingClock` (the default for `Task.sleep(for:)`) means elapsed time measurement pauses during system sleep, but byte counters do not pause.
**Why it happens:** `Task.sleep(for:)` defaults to `ContinuousClock`. However, if someone uses `Date()` or manually tracks time with a `SuspendingClock`, the time measurement suspends during sleep while counters keep incrementing.
**How to avoid:** Use `ContinuousClock.Instant.now` for all elapsed time calculations. ContinuousClock does NOT pause during sleep, matching the behavior of kernel byte counters. Note: `Task.sleep(for:)` already defaults to ContinuousClock.
**Warning signs:** Incorrect speed calculations after system wake.

### Pitfall 7: ifmd_name Extraction from Tuple
**What goes wrong:** Swift imports C fixed-size arrays (like `char ifmd_name[IFNAMSIZ]`) as tuples (e.g., `(Int8, Int8, Int8, ...)`), making string extraction non-obvious.
**Why it happens:** Swift-C interop represents C fixed arrays as tuples, not Swift arrays.
**How to avoid:** Use `withUnsafePointer(to: data.ifmd_name)` combined with `withMemoryRebound(to: CChar.self, capacity: IFNAMSIZ)` then `String(cString:)`.
**Warning signs:** Compile errors about tuple access or garbled interface names.

## Code Examples

### Complete sysctl Call Pattern (Verified Against macOS SDK Headers)
```swift
// Source: /Library/Developer/.../usr/include/net/if_mib.h
//         /Library/Developer/.../usr/include/net/if_var.h (if_data64)
//         XNU kernel source: bsd/net/if_mib.c (make_ifmibdata)

import Darwin

// Get interface count
func getInterfaceCount() -> Int32 {
    var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT]
    var count: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctl(&mib, UInt32(mib.count), &count, &size, nil, 0) == 0 else {
        return 0
    }
    return count
}

// Read per-interface data
func readInterfaceData(index: Int32) -> ifmibdata? {
    var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL]
    var data = ifmibdata()
    var size = MemoryLayout<ifmibdata>.size
    guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 else {
        return nil  // ENOENT for sparse indices is expected
    }
    return data
}

// Access 64-bit byte counters
// ifmibdata.ifmd_data is struct if_data64
// if_data64.ifi_ibytes is u_int64_t (UInt64 in Swift)
// if_data64.ifi_obytes is u_int64_t (UInt64 in Swift)
let data = readInterfaceData(index: 1)!
let bytesIn: UInt64 = data.ifmd_data.ifi_ibytes
let bytesOut: UInt64 = data.ifmd_data.ifi_obytes
```

### SystemConfiguration Name Resolution
```swift
// Source: Apple SystemConfiguration framework documentation
import SystemConfiguration

func buildInterfaceNameMap() -> [String: String] {
    guard let allInterfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
        return [:]
    }
    var map: [String: String] = [:]
    for interface in allInterfaces {
        guard let bsdName = SCNetworkInterfaceGetBSDName(interface) as String? else {
            continue
        }
        let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?
        map[bsdName] = displayName ?? bsdName
    }
    return map
    // Typical output: ["en0": "Wi-Fi", "en6": "USB 10/100/1000 LAN", ...]
}
```

### Sleep/Wake Detection
```swift
// Source: Apple NSWorkspace documentation
import AppKit

final class SleepWakeHandler {
    var onWake: (() -> Void)?

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleWake(_ notification: Notification) {
        onWake?()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
```

### Logger Setup
```swift
// Source: Apple os.Logger documentation, SwiftLee best practices
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bandwidth-monitor"

    /// Monitoring loop lifecycle and performance
    static let monitoring = Logger(subsystem: subsystem, category: "monitoring")

    /// Interface detection and enumeration
    static let interfaces = Logger(subsystem: subsystem, category: "interfaces")

    /// Application lifecycle (sleep/wake, launch, terminate)
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}

// Usage:
Logger.monitoring.debug("Poll cycle: \(elapsed, format: .fixed(precision: 3))s")
Logger.monitoring.warning("sysctl failed \(failures) consecutive times")
Logger.interfaces.info("Interface \(bsdName) appeared: \(displayName)")
Logger.lifecycle.info("System woke from sleep, discarding next sample")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@Published` | `@Observable` macro | macOS 14 (WWDC 2023) | Cleaner observation, no `@Published` wrappers, automatic view invalidation. Fewer property wrappers. |
| `DispatchSourceTimer` | `Task.sleep(for:tolerance:)` | Swift 5.5+ | Structured concurrency integrates with task cancellation, `@MainActor`, and energy-efficient wake coalescing. |
| `SCNetworkReachability` | `NWPathMonitor` | macOS 10.14 | Modern API, interface type detection, simpler setup. |
| `NSLog` / `print` | `os.Logger` | macOS 11 | Structured logging with subsystem/category, Console.app filtering, privacy annotations. |
| `getifaddrs()` for byte counts | `sysctl IFMIB_IFDATA` | Always available, recently validated | 64-bit counters via `if_data64`, no batching, no truncation. |

**Deprecated/outdated:**
- `SCNetworkReachability`: Legacy API, replaced by NWPathMonitor
- `DispatchSourceTimer`: Works but mixes GCD with structured concurrency
- `ObservableObject`: Still works but `@Observable` is strictly better on macOS 14+
- `getifaddrs()` for byte counting: 32-bit overflow at 4 GB

## Open Questions

1. **App Sandbox Compatibility with sysctl IFMIB_IFDATA**
   - What we know: The macOS sandbox restricts sysctl access. Most network monitoring apps (Stats, NetSpeedMonitor) distribute outside the Mac App Store or are unsigned. The batching issue only affects NET_RT_IFLIST2 for unsigned binaries; IFMIB_IFDATA's behavior under sandbox is less documented.
   - What's unclear: Whether sysctl IFMIB_IFDATA calls succeed inside a sandboxed app with `com.apple.security.app-sandbox` enabled. The kernel may restrict or batch responses.
   - Recommendation: Start development without sandbox (no entitlement file), test sysctl works. Before distribution, test with sandbox enabled. If sandboxed sysctl fails, distribute via notarized DMG (outside Mac App Store) which does not require sandbox. This is what most network monitoring apps do.

2. **Apple Patching IFMIB_IFDATA No-Batching Behavior**
   - What we know: Per STATE.md, this is an identified risk. The no-batching behavior of IFMIB_IFDATA may be an unintended omission.
   - What's unclear: Whether Apple will add batching to IFMIB_IFDATA in a future macOS update.
   - Recommendation: Implement IFMIB_IFDATA as primary. As a fallback strategy for later phases, signing the binary with a Developer ID would bypass batching even on NET_RT_IFLIST2. For Phase 1, IFMIB_IFDATA is sufficient.

3. **utun Interface Indexing Stability**
   - What we know: VPN tunnel interfaces (utun*) are created/destroyed dynamically. Their kernel indices may change between sessions.
   - What's unclear: Whether utun interface indices are stable within a single app session, or if they can change while the VPN is connected.
   - Recommendation: Re-resolve BSD name to kernel index on each poll cycle (D-06 already mandates this with poll-cycle re-enumeration). This handles any index instability.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift compiler | All code | Yes | 6.1.2 (Xcode 16.4) | -- |
| Xcode | Build system, test runner | Yes | 16.4 | -- |
| macOS SDK | System frameworks | Yes | 15.5 | -- |
| sysctl (IFMIB_IFDATA) | MON-01 byte counting | Yes | Kernel API | NET_RT_IFLIST2 (with caveats) |
| Network framework | MON-02 interface detection | Yes | macOS 10.14+ | -- |
| SystemConfiguration | MON-02 name resolution | Yes | macOS 10.1+ | -- |
| os.Logger | Logging | Yes | macOS 11+ | -- |
| swift-collections (SPM) | Deque ring buffer | Not installed | -- | Use Array (less efficient but functional) |

**Note on Swift version:** CLAUDE.md recommends Swift 6.2 / Xcode 26.3, but the environment has Swift 6.1.2 / Xcode 16.4. This is fully compatible -- all APIs and patterns work identically. The key difference is Swift 6.2 has "approachable concurrency" defaults (less verbose concurrency annotations). Swift 6.1.2 works perfectly; strict concurrency checking may require slightly more explicit `@Sendable` annotations. All recommended patterns (`@Observable`, `@MainActor`, `Task.sleep`, structured concurrency) are available in Swift 6.1.

**Missing dependencies with no fallback:** None -- all required system APIs are available.

**Missing dependencies with fallback:**
- swift-collections: Must be added via SPM when creating the Xcode project. Fallback: use `Array` with `removeFirst()` (O(n) vs O(1) but acceptable for small buffers).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode 16.4) |
| Config file | None -- Wave 0 must create test target |
| Quick run command | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme BandwidthMonitor -destination 'platform=macOS'` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MON-01 | sysctl IFMIB_IFDATA returns valid byte counters | unit | `xcodebuild test -only-testing BandwidthMonitorTests/SysctlReaderTests -destination 'platform=macOS'` | No -- Wave 0 |
| MON-01 | Speed computation from byte deltas is correct | unit | `xcodebuild test -only-testing BandwidthMonitorTests/SpeedComputationTests -destination 'platform=macOS'` | No -- Wave 0 |
| MON-01 | Counter reset detection reports zero speed | unit | `xcodebuild test -only-testing BandwidthMonitorTests/SpeedComputationTests/testCounterReset -destination 'platform=macOS'` | No -- Wave 0 |
| MON-02 | Interface filtering excludes loopback, bridge, vmnet | unit | `xcodebuild test -only-testing BandwidthMonitorTests/InterfaceFilterTests -destination 'platform=macOS'` | No -- Wave 0 |
| MON-02 | BSD names resolve to human-readable names | integration | `xcodebuild test -only-testing BandwidthMonitorTests/InterfaceDetectorTests -destination 'platform=macOS'` | No -- Wave 0 |
| MON-06 | Polling loop executes within CPU budget | manual | Instruments Time Profiler -- run app for 60s, verify < 1% CPU | N/A -- manual |
| MON-06 | No memory leaks during sustained polling | manual | Instruments Allocations -- run app for 5 min, check growth | N/A -- manual |

### Sampling Rate
- **Per task commit:** Quick run on modified test files
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green + manual Instruments verification for MON-06 before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Xcode project creation (File > New > Project > macOS > App)
- [ ] Test target creation (BandwidthMonitorTests)
- [ ] SPM dependency: swift-collections 1.1.0+
- [ ] `Tests/SysctlReaderTests.swift` -- covers MON-01 (sysctl reads)
- [ ] `Tests/SpeedComputationTests.swift` -- covers MON-01 (math correctness, counter reset)
- [ ] `Tests/InterfaceFilterTests.swift` -- covers MON-02 (filter logic)
- [ ] `Tests/InterfaceDetectorTests.swift` -- covers MON-02 (name resolution)

## Sources

### Primary (HIGH confidence)
- macOS SDK header `/usr/include/net/if_mib.h` -- Verified `struct ifmibdata` contains `struct if_data64 ifmd_data` (64-bit counters)
- macOS SDK header `/usr/include/net/if_var.h` (line 189-217) -- Verified `if_data64.ifi_ibytes` and `ifi_obytes` are `u_int64_t`
- [XNU kernel source: bsd/net/if_mib.c](https://github.com/apple/darwin-xnu/blob/main/bsd/net/if_mib.c) -- Confirmed `if_data_internal_to_if_data64()` conversion in `make_ifmibdata()`
- [Apple Developer: NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor) -- Official API for interface monitoring
- [Apple Developer: SCNetworkInterfaceCopyAll](https://developer.apple.com/documentation/systemconfiguration/scnetworkinterfacecopyall()) -- Interface enumeration
- [Apple Developer: NSWorkspace.didWakeNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification) -- Sleep/wake detection
- [Apple Developer: Task.sleep(for:tolerance:clock:)](https://developer.apple.com/documentation/swift/task/sleep(for:tolerance:clock:)) -- Energy-efficient polling
- [ifmib(4) man page](https://www.unix.com/man-page/osx/4/ifmib/) -- IFMIB_IFCOUNT enumeration, sparse table handling

### Secondary (MEDIUM confidence)
- [macOS Network Metrics Using sysctl()](https://milen.me/writings/macos-network-metrics-sysctl-net-rt-iflist2/) -- Analysis of NET_RT_IFLIST2 batching/truncation, IFMIB_IFDATA alternative. Verified against kernel source.
- [milend/macos-network-metrics commit ba188fc](https://github.com/milend/macos-network-metrics/commit/ba188fc97140072c3378a519d115b88a90f61d4c) -- C code example showing IFMIB_IFDATA pattern with `ifmibdata.ifmd_data.ifi_ibytes`
- [OSLog and Unified logging - SwiftLee](https://www.avanderlee.com/debugging/oslog-unified-logging/) -- Logger best practices
- [Hacking with Swift: NWPathMonitor](https://www.hackingwithswift.com/example-code/networking/how-to-check-for-internet-connectivity-using-nwpathmonitor) -- NWPathMonitor usage patterns
- [Swift Collections 1.4.1 release](https://forums.swift.org/t/swift-collections-1-4-1/85425) -- Latest version confirmed

### Tertiary (LOW confidence)
- App Sandbox sysctl restrictions -- Multiple sources suggest sysctl is restricted but exact IFMIB_IFDATA behavior under sandbox is unverified. Most network monitoring apps distribute outside the Mac App Store.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All APIs verified against macOS SDK headers and XNU kernel source
- Architecture: HIGH -- Patterns drawn from Apple documentation, established Swift community practices, and CLAUDE.md decisions
- Pitfalls: HIGH -- Sparse table (documented in man page), counter resets (known issue), sleep/wake spikes (common in network monitors), clock choice (Apple documentation)
- Sandbox compatibility: LOW -- Unclear whether IFMIB_IFDATA works under App Sandbox; most similar apps avoid sandbox

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable -- kernel APIs rarely change; Apple WWDC announcements in June could affect guidance)
