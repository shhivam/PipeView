import AppKit
import os

/// Detects system wake from sleep via NSWorkspace.didWakeNotification (per D-09).
/// Calls onWake closure so NetworkMonitor can discard the first post-wake byte delta.
final class SleepWakeHandler {
    var onWake: (() -> Void)?

    private let logger = Logger.lifecycle

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        logger.info("SleepWakeHandler registered for wake notifications")
    }

    @objc private func handleWake(_ notification: Notification) {
        logger.info("System woke from sleep -- will discard next sample")
        onWake?()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
