import AppKit
import ServiceManagement
import os

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    // Strong reference prevents deallocation (Pitfall 1)
    private var statusItem: NSStatusItem!
    private var statusBarController: StatusBarController?
    private let networkMonitor = NetworkMonitor()

    // Phase 3: Database and recording
    private var appDatabase: AppDatabase?
    private var bandwidthRecorder: BandwidthRecorder?

    // Phase 3: Aggregation and pruning
    private var aggregationEngine: AggregationEngine?
    private var pruningManager: PruningManager?
    private var aggregationTask: Task<Void, Never>?
    private var pruningTask: Task<Void, Never>?

    // Phase 5: UserDefaults observer for update interval preference
    private var preferencesObserver: NSObjectProtocol?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // D-17: First launch goes straight to menu bar, no onboarding
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        // Phase 6: Compute initial interval once, used for both NetworkMonitor and BandwidthRecorder
        let initialInterval = UpdateIntervalPref(
            rawValue: UserDefaults.standard.integer(forKey: PreferenceKey.updateInterval)
        ) ?? .twoSeconds

        // Phase 3: Database + recording
        do {
            let database = try AppDatabase.makeDefault()
            self.appDatabase = database

            let recorder = BandwidthRecorder(
                networkMonitor: networkMonitor,
                database: database,
                pollingInterval: initialInterval.timeInterval
            )
            recorder.start()
            self.bandwidthRecorder = recorder

            // Aggregation engine
            let engine = AggregationEngine(database: database)
            self.aggregationEngine = engine

            // Pruning manager
            let pruner = PruningManager(database: database)
            self.pruningManager = pruner

            // Run pruning on launch (per D-09: catches stale data after days off)
            Task {
                try? await pruner.pruneOldSamples()
                // Run initial aggregation to catch up on any un-aggregated data
                await engine.runFullAggregation()
            }

            // Start background aggregation timer (every 10 seconds)
            // Cascading is fast and idempotent, so a single full cycle is sufficient.
            aggregationTask = Task { [weak engine] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10), tolerance: .seconds(2))
                    guard !Task.isCancelled else { break }
                    await engine?.runFullAggregation()
                }
            }

            // Start background pruning timer (per D-09: once per 24 hours while running)
            pruningTask = Task { [weak pruner] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(86400), tolerance: .seconds(60))
                    guard !Task.isCancelled else { break }
                    try? await pruner?.pruneOldSamples()
                }
            }

            Logger.lifecycle.info("Database, recorder, aggregation, and pruning initialized")
        } catch {
            Logger.lifecycle.error("Failed to initialize database: \(error.localizedDescription)")
            // App continues without recording -- monitoring and menu bar still work
        }

        // Phase 5: StatusBarController created after database init so appDatabase can be passed.
        // appDatabase is optional -- HistoryView handles nil gracefully (shows empty state).
        statusBarController = StatusBarController(
            statusItem: statusItem,
            networkMonitor: networkMonitor,
            appDatabase: appDatabase
        )
        statusBarController?.setup()

        // Phase 5: Set initial polling interval from user preference before starting
        networkMonitor.pollingInterval = initialInterval.duration

        networkMonitor.start()

        // Phase 5: Observe update interval preference changes (Pitfall 7)
        // Note: The closure is @Sendable but runs on .main queue, so we use
        // MainActor.assumeIsolated to access @MainActor properties safely.
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let intervalPref = UpdateIntervalPref(
                    rawValue: UserDefaults.standard.integer(forKey: PreferenceKey.updateInterval)
                ) ?? .twoSeconds
                self.networkMonitor.pollingInterval = intervalPref.duration
                self.bandwidthRecorder?.pollingInterval = intervalPref.timeInterval
            }
        }

        // D-16: Auto-register as login item on first launch
        registerLoginItem()

        Logger.lifecycle.info("Application launched, menu bar active")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cancel background aggregation and pruning tasks
        aggregationTask?.cancel()
        pruningTask?.cancel()

        // Flush any buffered samples before terminating (per Pitfall 5)
        if let recorder = bandwidthRecorder {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await recorder.flush()
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2.0) // 2 second timeout to avoid hanging
            recorder.stop()
        }

        networkMonitor.stop()
        Logger.lifecycle.info("Application terminating")
    }

    // MARK: - Login Item (SYS-01, D-16)

    private func registerLoginItem() {
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
                Logger.lifecycle.info("Registered as login item successfully")
            } else {
                Logger.lifecycle.debug("Already registered as login item")
            }
        } catch {
            // Expected to fail in Xcode debug builds (not running from /Applications)
            Logger.lifecycle.error("Failed to register login item: \(error.localizedDescription)")
        }
    }
}
