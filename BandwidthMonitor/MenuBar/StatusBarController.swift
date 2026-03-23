import AppKit
import Observation
import os

@MainActor
final class StatusBarController: NSObject {
    // MARK: - Properties

    private let statusItem: NSStatusItem
    private let networkMonitor: NetworkMonitor
    private let textBuilder = SpeedTextBuilder()

    // Hardcoded defaults for Phase 2 (preferences deferred to Phase 5)
    private let displayMode: DisplayMode = .auto
    private let unitMode: SpeedFormatter.UnitMode = .auto

    // MARK: - Init

    init(statusItem: NSStatusItem, networkMonitor: NetworkMonitor) {
        self.statusItem = statusItem
        self.networkMonitor = networkMonitor
        super.init()
    }

    // MARK: - Setup

    func setup() {
        // D-18: em dash before first poll
        updateStatusItemText(text: "\u{2014}")

        // D-13: both left-click and right-click open same NSMenu
        statusItem.menu = buildMenu()

        startObserving()

        Logger.menuBar.info("StatusBarController setup complete")
    }

    // MARK: - Observation (withObservationTracking re-registration pattern)

    private func startObserving() {
        withObservationTracking {
            let speed = self.networkMonitor.aggregateSpeed
            let hasInterfaces = !self.networkMonitor.interfaceSpeeds.isEmpty

            let text = self.textBuilder.build(
                speed: speed,
                mode: self.displayMode,
                unit: self.unitMode,
                hasInterfaces: hasInterfaces
            )

            self.updateStatusItemText(text: text)
        } onChange: {
            Task { @MainActor [weak self] in
                self?.startObserving()
            }
        }
    }

    // MARK: - Status Item Text

    // D-04 / BAR-04: monospacedDigitSystemFont for tabular figures (anti-jitter)
    private func updateStatusItemText(text: String) {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .regular
        )
        statusItem.button?.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: font]
        )
    }

    // MARK: - Menu (D-12, D-13)

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let metrics = NSMenuItem(title: "Metrics", action: nil, keyEquivalent: "")
        metrics.isEnabled = false
        menu.addItem(metrics)

        let prefs = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        prefs.isEnabled = false
        menu.addItem(prefs)

        menu.addItem(.separator())

        let about = NSMenuItem(
            title: "About Bandwidth Monitor",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(
            title: "Quit Bandwidth Monitor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
    }
}
