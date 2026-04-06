<!-- GSD:project-start source:PROJECT.md -->
## Project

**PipeView**

A macOS menu bar application that monitors real-time network throughput (upload/download) per network interface, displays live speeds in the menu bar with user-configurable units, and provides beautiful graphs of historical bandwidth usage in a popover window. Data is persisted locally in SQLite for viewing usage across minutes, hours, days, weeks, and months.

**Core Value:** Reliable, always-visible network throughput monitoring — the user can glance at the menu bar and instantly know their current upload/download speeds, and open the popover to understand usage patterns over time.

### Constraints

- **Platform**: macOS only — native Swift, no cross-platform frameworks
- **Data storage**: SQLite — simple, local, no server
- **Architecture**: Modular and debuggable — clear separation between monitoring, storage, and UI layers
- **macOS version**: Target macOS 13+ (for Swift Charts and modern SwiftUI APIs)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.2 (Xcode 26.3) | Primary language | Required for native macOS development. Swift 6.2 brings "approachable concurrency" making async/await patterns natural. Strict concurrency checking catches data races at compile time -- critical for a multi-threaded monitoring app. |
| SwiftUI | macOS 13+ APIs | UI framework for popover content, charts, settings | Declarative UI that integrates natively with Swift Charts. MenuBarExtra scene provides first-party menu bar app support. Significantly less boilerplate than AppKit for charts and data-driven views. |
| AppKit (NSStatusItem) | macOS 13+ | Menu bar text display | SwiftUI's MenuBarExtra cannot efficiently display rapidly-updating text (upload/download speeds). NSStatusItem with NSStatusBarButton.title gives direct control over the menu bar text with minimal overhead. Use AppKit for the status item, SwiftUI for everything inside the popover. |
| Swift Charts | macOS 13+ (Charts framework) | Time series line/area charts, bar charts | First-party Apple framework. Supports line marks, area marks, bar marks, scrollable axes, and selection gestures. No third-party dependency needed. Integrates natively with SwiftUI. |
| GRDB.swift | 7.10.0 | SQLite database access, migrations, observation | The standard Swift SQLite toolkit for app developers. Provides type-safe queries, schema migrations, WAL mode for concurrent reads/writes, and ValueObservation for reactive UI updates. Far more capable than SQLite.swift. Superior raw performance to SwiftData for local-only databases. |
| GRDBQuery | 0.11.0 | SwiftUI database observation | The @Query property wrapper for GRDB -- equivalent of @FetchRequest for Core Data. Lets SwiftUI views directly observe database changes without manual plumbing. |
| Network framework (NWPathMonitor) | macOS 10.14+ | Detect active interfaces, monitor connectivity changes | Apple's modern networking framework. NWPathMonitor.availableInterfaces provides interface type detection (wifi, wiredEthernet, etc.) and notifies on changes. Use for knowing which interfaces are active -- not for byte counting. |
| sysctl (IFMIB_IFDATA) | Kernel API | Read per-interface bytes sent/received | The recommended low-level API for reading 64-bit network byte counters per interface. IFMIB_IFDATA with IFDATA_GENERAL returns ifmibdata containing if_data64 with ifi_ibytes/ifi_obytes. Avoids the 1KiB batching and 4GiB truncation bugs that plague NET_RT_IFLIST2 on recent macOS versions. |
| SystemConfiguration | macOS 10.1+ | Map BSD interface names to human-readable names | SCNetworkInterfaceCopyAll() + SCNetworkInterfaceGetBSDName()/GetInterfaceType() maps en0/en1 to "Wi-Fi"/"Ethernet". Essential for the per-interface breakdown UI. |
### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| MenuBarExtraAccess | 1.2.2 | Programmatic control of MenuBarExtra state | Only if you need to programmatically show/hide the popover or access the underlying NSStatusItem from SwiftUI. May not be needed if using the hybrid AppKit+SwiftUI approach (which gives direct NSStatusItem access anyway). |
| swift-collections | 1.1+ | OrderedDictionary, Deque for time-series buffers | Use Deque for the in-memory ring buffer of recent network samples. More efficient than Array for FIFO append/remove-first patterns. |
| swift-algorithms | 1.2+ | Chunked, windows, strided iteration | Useful when downsampling time-series data for different chart zoom levels (e.g., aggregating per-second samples into per-minute averages). |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 26.3 | IDE, build system, debugging | Latest stable. Requires macOS Sequoia 15.6+. Includes Swift 6.2.3 and all required SDKs. |
| Swift Package Manager | Dependency management | Built into Xcode. Use for GRDB, GRDBQuery, and any other dependencies. No CocoaPods or Carthage needed. |
| Instruments (Time Profiler) | Performance profiling | Critical for verifying the monitoring timer and status bar updates don't consume excessive CPU. Target < 1% CPU at 1-second polling interval. |
| Instruments (Allocations) | Memory profiling | Verify no memory leaks from the repeating timer/database write cycle. Menu bar apps run indefinitely so leaks compound. |
| SwiftLint | Code style enforcement | Optional but recommended. Catches common Swift style issues. Configure via .swiftlint.yml in project root. |
## Project Setup
# Xcode project creation (via Xcode GUI):
# 1. File > New > Project > macOS > App
# 2. Interface: SwiftUI
# 3. Language: Swift
# 4. Storage: None (we use GRDB, not SwiftData/Core Data)
# Add Swift Package dependencies in Xcode:
# Package URL: https://github.com/groue/GRDB.swift
#   Version: 7.10.0 (Up to Next Major)
# Package URL: https://github.com/groue/GRDBQuery
#   Version: 0.11.0 (Up to Next Major)
# Package URL: https://github.com/apple/swift-collections
#   Version: 1.1.0 (Up to Next Major)
# Info.plist configuration:
# Set "Application is agent (UIElement)" = YES
# This prevents the app from showing in the Dock
## Architecture Approach: Hybrid AppKit + SwiftUI
- MenuBarExtra with `.menuBarExtraStyle(.window)` creates a popover-like window, but updating the label text every second causes performance issues with SwiftUI's diffing
- NSStatusItem.button.title can be set directly on the main thread with negligible overhead
- MenuBarExtra lacks API for right-click menus, programmatic dismiss, or window access without third-party libraries
- The popover content (charts, interface list, settings) is 100% SwiftUI -- AppKit is only for the thin status item shell
- ~20% AppKit: NSStatusItem setup, NSPopover hosting, application lifecycle (AppDelegate)
- ~80% SwiftUI: All views inside the popover, charts, data binding, settings
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| GRDB.swift | SwiftData | Only if you need iCloud sync. SwiftData has worse raw performance and is heavier for a local-only time-series database. Also less mature for macOS. |
| GRDB.swift | SQLite.swift | Never for this project. SQLite.swift is less feature-rich (no migrations, no observation, no WAL pool). GRDB is strictly superior for app development. |
| GRDB.swift | Core Data | Only if you already know Core Data well and want iCloud sync. More complex setup, heavier runtime, ORM impedance mismatch for time-series data. |
| Swift Charts | ChartsOrg/Charts (DGCharts) | Only if targeting macOS 12 or earlier. Third-party, MPAndroidChart port, UIKit-based. Swift Charts is first-party and SwiftUI-native. |
| sysctl (IFMIB_IFDATA) | sysctl (NET_RT_IFLIST2) | Avoid. NET_RT_IFLIST2 suffers from 1KiB batching for unsigned binaries and a 4GiB truncation kernel bug (rdar://106029568). IFMIB_IFDATA avoids both issues. |
| sysctl (IFMIB_IFDATA) | getifaddrs() | Avoid. Only exposes 32-bit counters that overflow quickly on modern high-bandwidth connections. |
| sysctl (IFMIB_IFDATA) | nettop / Network Extension | Avoid. nettop is CPU-heavy. Network Extension requires entitlements and is designed for per-app monitoring, not aggregate interface stats. |
| Hybrid AppKit+SwiftUI | Pure SwiftUI MenuBarExtra | Only for simple menu bar apps that don't need frequent text updates. MenuBarExtra label updates every second cause unnecessary SwiftUI re-renders. |
| NWPathMonitor | SCNetworkReachability | Never. SCNetworkReachability is the legacy API. NWPathMonitor is its modern replacement with better interface detection. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| SwiftData | Overkill for time-series data. Worse performance than direct SQLite. Designed for object graphs, not append-heavy time-series workloads. | GRDB.swift |
| Electron / web-based wrappers | Massive memory overhead for a menu bar utility. A native Swift app uses ~10-20 MB. Electron would use 100-200+ MB. | Native Swift + SwiftUI |
| getifaddrs() for byte counting | 32-bit counters only. Overflows at 4 GB on modern connections. | sysctl with IFMIB_IFDATA |
| NET_RT_IFLIST2 for byte counting | 1KiB batching for unsigned apps + 4GiB truncation kernel bug on recent macOS. | sysctl with IFMIB_IFDATA |
| DispatchSourceTimer for monitoring loop | Works but lacks tolerance API at the Swift Concurrency level. Mixes GCD and structured concurrency. | Task.sleep(for:tolerance:) in an async loop. Use structured concurrency throughout. |
| CocoaPods / Carthage | Legacy dependency managers. SPM is built into Xcode and handles all our dependencies. | Swift Package Manager |
| ChartsOrg/Charts (DGCharts) | Third-party UIKit port. Doesn't integrate with SwiftUI natively. Swift Charts is first-party and purpose-built. | Swift Charts |
| Per-app bandwidth monitoring (nettop) | CPU-heavy, requires elevated permissions, and is explicitly out of scope per PROJECT.md. | Per-interface aggregate monitoring via sysctl |
## Stack Patterns by Variant
- Use Swift Charts for all charting (line, area, bar)
- Use MenuBarExtra scene as fallback or use hybrid AppKit approach
- Use `chartScrollableAxes`, `chartXVisibleDomain` for scrollable time-series
- Gain access to SwiftUI Observable macro (@Observable instead of ObservableObject)
- Cleaner state management with fewer property wrappers
- Consider this the minimum if starting fresh in 2026
- Latest Swift Charts features
- Best SwiftUI performance
- Recommended only if you don't need to support older machines
- Gains @Observable macro for cleaner architecture
- Broad install base (Sonoma supports 2018+ Macs)
- Swift Charts still available (introduced in macOS 13)
- Good balance of modern APIs and user reach
## Version Compatibility
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| GRDB.swift 7.10.0 | Swift 6.1+, Xcode 16.3+, macOS 10.15+ | Fully compatible with Xcode 26.3 and Swift 6.2. |
| GRDBQuery 0.11.0 | Swift 6+, Xcode 16+, macOS 11+ | Companion to GRDB. Same SPM integration. |
| Swift Charts | macOS 13+ only | First-party. No separate package -- import Charts. |
| MenuBarExtraAccess 1.2.2 | macOS 13+ | Only needed if using pure SwiftUI MenuBarExtra approach. |
| swift-collections 1.1+ | Swift 5.9+, all platforms | Lightweight. Deque is the key type for this project. |
| Network framework | macOS 10.14+ | First-party. import Network. No package needed. |
| SystemConfiguration | macOS 10.1+ | First-party. import SystemConfiguration. No package needed. |
## Confidence Assessment
| Decision | Confidence | Rationale |
|----------|------------|-----------|
| Swift + SwiftUI + AppKit hybrid | HIGH | This is the standard pattern for macOS menu bar apps. Verified across multiple sources, open-source implementations, and Apple documentation. |
| GRDB.swift for SQLite | HIGH | Community consensus choice for Swift SQLite. 7.10.0 is current. ValueObservation + GRDBQuery provide reactive SwiftUI integration. Verified on GitHub releases page. |
| Swift Charts | HIGH | First-party Apple framework. Confirmed available on macOS 13+. Supports all required chart types (line, area, bar, scrollable). |
| sysctl IFMIB_IFDATA for network bytes | MEDIUM | Verified as working API that avoids NET_RT_IFLIST2 pitfalls. The "no batching" behavior may be an unintended omission that Apple could patch. Mitigation: also implement NET_RT_IFLIST2 as fallback, and sign the binary with a Developer ID to bypass batching. |
| macOS 14 minimum target | MEDIUM | Opinionated recommendation for @Observable benefits. macOS 13 is a safe fallback if broader compatibility needed. |
| NWPathMonitor for interface detection | HIGH | Apple's documented, recommended API for network path monitoring. Confirmed in official Apple documentation. |
## Sources
- [macOS Network Metrics Using sysctl()](https://milen.me/writings/macos-network-metrics-sysctl-net-rt-iflist2/) -- Detailed analysis of NET_RT_IFLIST2 vs IFMIB_IFDATA, batching/truncation bugs. MEDIUM confidence (independent developer research, verified against Apple docs).
- [GRDB.swift GitHub Releases](https://github.com/groue/GRDB.swift/releases) -- Version 7.10.0 confirmed Feb 2025. HIGH confidence.
- [GRDBQuery GitHub](https://github.com/groue/GRDBQuery) -- Version 0.11.0 confirmed. HIGH confidence.
- [Apple Developer: Swift Charts](https://developer.apple.com/documentation/Charts) -- Official documentation. HIGH confidence.
- [Apple Developer: MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra) -- Official documentation. HIGH confidence.
- [Apple Developer: NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor) -- Official documentation. HIGH confidence.
- [Apple Developer: if_msghdr2](https://developer.apple.com/documentation/kernel/if_msghdr2) -- Kernel structure for network metrics. HIGH confidence.
- [Apple Developer: SCNetworkInterface](https://developer.apple.com/documentation/systemconfiguration/scnetworkinterface) -- Interface name resolution. HIGH confidence.
- [NetSpeedMonitor (GitHub)](https://github.com/elegracer/NetSpeedMonitor) -- Open-source macOS menu bar network monitor. Uses sysctl + SwiftUI. Validates architectural approach.
- [Xcode Releases](https://xcodereleases.com/) -- Xcode 26.3 with Swift 6.2.3 confirmed as latest stable. HIGH confidence.
- [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) -- Version 1.2.2. Mac App Store safe. HIGH confidence.
- [Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) -- Practical guide for hybrid AppKit+SwiftUI approach.
- [Approachable Concurrency in Swift 6.2](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) -- Swift 6.2 concurrency improvements. MEDIUM confidence.
- [SwiftData vs GRDB comparison](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) -- Performance analysis favoring GRDB for local-only databases.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
