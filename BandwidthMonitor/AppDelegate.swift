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

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // D-17: First launch goes straight to menu bar, no onboarding
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        statusBarController = StatusBarController(
            statusItem: statusItem,
            networkMonitor: networkMonitor
        )
        statusBarController?.setup()

        networkMonitor.start()

        // D-16: Auto-register as login item on first launch
        registerLoginItem()

        Logger.lifecycle.info("Application launched, menu bar active")
    }

    func applicationWillTerminate(_ notification: Notification) {
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
