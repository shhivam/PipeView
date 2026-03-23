import Foundation
import GRDB
import Observation
import os

/// Records bandwidth data by observing NetworkMonitor, accumulating snapshots,
/// and writing RawSample records to the database.
///
/// Accumulates `accumulationCount` poll-cycle snapshots (default 5 at 2s = 10s),
/// then writes one RawSample per active interface with total bytes.
/// Database writes happen off the main thread via `nonisolated` writeSamples.
@MainActor
final class BandwidthRecorder {
    // MARK: - Configuration

    /// Number of snapshots to accumulate before writing (per D-01: 5 cycles * 2s = 10s)
    let accumulationCount: Int

    /// Assumed polling interval for converting speed to bytes
    let pollingInterval: TimeInterval

    // MARK: - Dependencies

    private let networkMonitor: NetworkMonitor
    private let database: AppDatabase
    private let logger = Logger.persistence

    // MARK: - State

    private var buffer: [NetworkSnapshot] = []
    private(set) var isRecording: Bool = false
    private(set) var totalSamplesWritten: Int = 0

    // MARK: - Init

    init(
        networkMonitor: NetworkMonitor,
        database: AppDatabase,
        accumulationCount: Int = 5,
        pollingInterval: TimeInterval = 2.0
    ) {
        self.networkMonitor = networkMonitor
        self.database = database
        self.accumulationCount = accumulationCount
        self.pollingInterval = pollingInterval
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRecording else { return }
        isRecording = true
        buffer.removeAll()
        logger.info("BandwidthRecorder started (accumulating \(self.accumulationCount) snapshots)")

        // Use withObservationTracking re-registration pattern (same as StatusBarController)
        // to observe latestSnapshot changes and accumulate in buffer.
        startObserving()
    }

    /// Observe NetworkMonitor.latestSnapshot changes using the
    /// withObservationTracking re-registration pattern.
    private func startObserving() {
        withObservationTracking {
            let snapshot = self.networkMonitor.latestSnapshot
            self.handleSnapshot(snapshot)
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.startObserving()
            }
        }
    }

    /// Process a new snapshot: buffer it and write when full.
    private func handleSnapshot(_ snapshot: NetworkSnapshot) {
        // Skip empty snapshots (no active interfaces)
        guard !snapshot.interfaceSpeeds.isEmpty else { return }

        buffer.append(snapshot)

        if buffer.count >= accumulationCount {
            let samples = buffer
            buffer.removeAll()
            let interval = pollingInterval
            let db = database
            Task {
                await Self.writeSamples(from: samples, pollingInterval: interval, database: db) { count in
                    await MainActor.run {
                        self.totalSamplesWritten += count
                    }
                }
            }
        }
    }

    func stop() {
        isRecording = false
        logger.info("BandwidthRecorder stopped (total samples written: \(self.totalSamplesWritten))")
    }

    /// Flush any buffered snapshots to the database (called on app termination per Pitfall 5).
    /// Writes whatever is in the buffer even if < accumulationCount snapshots.
    func flush() async {
        guard !buffer.isEmpty else { return }
        let samples = buffer
        buffer.removeAll()
        logger.info("Flushing \(samples.count) buffered snapshots")
        let interval = pollingInterval
        let db = database
        await Self.writeSamples(from: samples, pollingInterval: interval, database: db) { count in
            await MainActor.run {
                self.totalSamplesWritten += count
            }
        }
    }

    // MARK: - Testable Entry Point

    /// Process and write a batch of snapshots to the database.
    /// Exposed for testing; the observation loop calls this internally.
    func processAndWrite(snapshots: [NetworkSnapshot]) async {
        let interval = pollingInterval
        let db = database
        await Self.writeSamples(from: snapshots, pollingInterval: interval, database: db) { count in
            await MainActor.run {
                self.totalSamplesWritten += count
            }
        }
    }

    // MARK: - Writing

    /// Convert accumulated snapshots to RawSample records and write to database.
    /// Static + nonisolated: executes off the main thread (per Pitfall 1).
    /// The onSuccess callback reports count back to the actor for tracking.
    private nonisolated static func writeSamples(
        from snapshots: [NetworkSnapshot],
        pollingInterval: TimeInterval,
        database: AppDatabase,
        onSuccess: @Sendable (Int) async -> Void
    ) async {
        let rawSamples = buildRawSamples(from: snapshots, pollingInterval: pollingInterval)

        guard !rawSamples.isEmpty else { return }

        do {
            try await database.dbWriter.write { dbConn in
                for var sample in rawSamples {  // swiftlint:disable:this variable_name
                    try sample.insert(dbConn)
                }
            }
            await onSuccess(rawSamples.count)
        } catch {
            Logger.persistence.error("Failed to write raw samples: \(error.localizedDescription)")
        }
    }

    // MARK: - Sample Building (pure function, no isolation needed)

    /// Build RawSample records from accumulated snapshots.
    /// Pure function: takes snapshots and config, returns records to insert.
    private nonisolated static func buildRawSamples(
        from snapshots: [NetworkSnapshot],
        pollingInterval: TimeInterval
    ) -> [RawSample] {
        guard !snapshots.isEmpty else { return [] }

        let count = snapshots.count
        let duration = pollingInterval * Double(count)
        let timestamp = snapshots.last!.timestamp.timeIntervalSince1970

        // Group speeds by interface across all snapshots
        var interfaceTotals: [String: (totalBytesIn: Double, totalBytesOut: Double)] = [:]
        for snapshot in snapshots {
            for ifSpeed in snapshot.interfaceSpeeds {
                let key = ifSpeed.interface.bsdName
                let existing = interfaceTotals[key, default: (totalBytesIn: 0, totalBytesOut: 0)]
                // Per D-11: Convert speed (bytes/sec) to total bytes for this poll interval
                interfaceTotals[key] = (
                    totalBytesIn: existing.totalBytesIn + ifSpeed.speed.bytesInPerSecond * pollingInterval,
                    totalBytesOut: existing.totalBytesOut + ifSpeed.speed.bytesOutPerSecond * pollingInterval
                )
            }
        }

        // Create one RawSample per interface
        return interfaceTotals.map { (interfaceId, totals) in
            RawSample(
                id: nil,
                interfaceId: interfaceId,
                timestamp: timestamp,
                bytesIn: totals.totalBytesIn,
                bytesOut: totals.totalBytesOut,
                duration: duration
            )
        }
    }
}
