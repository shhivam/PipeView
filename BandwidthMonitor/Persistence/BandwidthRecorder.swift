import Foundation
import GRDB
import Observation
import os

/// Records bandwidth data by observing NetworkMonitor, accumulating snapshots,
/// and writing RawSample records to the database.
///
/// Accumulates `accumulationCount` poll-cycle snapshots (default 5 at 2s = 10s),
/// then writes one RawSample per active interface with total bytes.
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
    private var recordingTask: Task<Void, Never>?
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
        // Stub -- will be implemented in GREEN phase
    }

    func stop() {
        // Stub -- will be implemented in GREEN phase
    }

    func flush() async {
        // Stub -- will be implemented in GREEN phase
    }

    // MARK: - Testable Entry Point

    /// Process and write a batch of snapshots to the database.
    /// Exposed for testing; the observation loop calls this internally.
    func processAndWrite(snapshots: [NetworkSnapshot]) async {
        // Stub -- will be implemented in GREEN phase
    }
}
