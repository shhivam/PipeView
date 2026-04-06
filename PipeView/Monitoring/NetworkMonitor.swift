import Observation
import os

/// Main monitoring engine. Polls sysctl for per-interface byte counters, computes speeds,
/// and publishes results as @Observable state for SwiftUI consumption.
///
/// Architecture: @MainActor @Observable (per research recommendation).
/// NOT a custom actor -- SwiftUI models must be @MainActor for direct observation.
@MainActor
@Observable
final class NetworkMonitor {
    // MARK: - Published State (observed by SwiftUI views)

    /// Current speed for each active interface
    private(set) var interfaceSpeeds: [InterfaceSpeed] = []

    /// Sum of all interface speeds (per D-08)
    private(set) var aggregateSpeed: Speed = .zero

    /// Latest complete snapshot (convenience for consumers)
    private(set) var latestSnapshot: NetworkSnapshot = .empty

    /// Whether the monitor is currently polling
    private(set) var isRunning: Bool = false

    // MARK: - Configuration

    /// Polling interval (per D-01: default 2 seconds, per D-02: configurable internally)
    var pollingInterval: Duration = .seconds(2)

    // MARK: - Internal State

    private var pollingTask: Task<Void, Never>?
    private var previousCounters: [String: ByteCounters] = [:]
    private var previousTimestamp: ContinuousClock.Instant?
    private var consecutiveFailures: Int = 0
    private var discardNextSample: Bool = false

    // MARK: - Dependencies

    private let reader = SysctlReader()
    private let interfaceDetector = InterfaceDetector()
    private let sleepWakeHandler = SleepWakeHandler()
    private let logger = Logger.monitoring

    // MARK: - Lifecycle

    /// Start the monitoring loop. Safe to call multiple times (restarts).
    func start() {
        stop()

        interfaceDetector.startMonitoring()

        sleepWakeHandler.onWake = { [weak self] in
            Task { @MainActor [weak self] in
                self?.discardNextSample = true
                Logger.lifecycle.info("Wake detected -- discarding next sample (per D-09)")
            }
        }

        isRunning = true
        logger.info("NetworkMonitor started with \(self.pollingInterval) interval")

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(
                    for: self?.pollingInterval ?? .seconds(2),
                    tolerance: .milliseconds(500)  // Energy efficiency: allow CPU coalescing
                )
            }
        }
    }

    /// Stop the monitoring loop and clean up.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        interfaceDetector.stopMonitoring()
        isRunning = false
        previousCounters = [:]
        previousTimestamp = nil
        consecutiveFailures = 0
        discardNextSample = false
        logger.info("NetworkMonitor stopped")
    }

    // MARK: - Polling

    private func pollOnce() {
        let now = ContinuousClock.Instant.now

        // Per D-06: Re-enumerate interface list on each poll cycle as safety net
        interfaceDetector.refreshInterfaces()
        let activeInterfaces = interfaceDetector.activeInterfaces

        var newSpeeds: [InterfaceSpeed] = []

        for iface in activeInterfaces {
            guard let counters = reader.readCounters(forInterfaceIndex: iface.index) else {
                // Per D-10: Skip failed sysctl samples, log at debug level
                consecutiveFailures += 1
                if consecutiveFailures >= 5 {
                    logger.warning("sysctl failed \(self.consecutiveFailures) consecutive times for \(iface.bsdName)")
                } else {
                    logger.debug("sysctl read failed for \(iface.bsdName) (index=\(iface.index))")
                }
                continue
            }
            consecutiveFailures = 0

            if discardNextSample {
                // Per D-09: Post-wake -- record counters but don't compute speed
                previousCounters[iface.bsdName] = counters
                continue
            }

            if let prev = previousCounters[iface.bsdName],
               let prevTime = previousTimestamp {
                let elapsed = now - prevTime
                let elapsedSeconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18

                // Per D-03: Raw byte delta / elapsed time, no smoothing
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

        // Update published state
        interfaceSpeeds = newSpeeds
        // Per D-08: Aggregate total across all active interfaces
        aggregateSpeed = newSpeeds.reduce(.zero) { $0 + $1.speed }
        latestSnapshot = NetworkSnapshot(
            interfaceSpeeds: newSpeeds,
            aggregateSpeed: aggregateSpeed,
            timestamp: .now
        )

        logger.debug("Poll: \(newSpeeds.count) interfaces, aggregate in=\(self.aggregateSpeed.bytesInPerSecond, format: .fixed(precision: 0)) B/s out=\(self.aggregateSpeed.bytesOutPerSecond, format: .fixed(precision: 0)) B/s")
    }
}
