import AppKit
import Observation
import os
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    // MARK: - Properties

    private let statusItem: NSStatusItem
    private let networkMonitor: NetworkMonitor
    private let appDatabase: AppDatabase?
    private let textBuilder = SpeedTextBuilder()

    // Phase 4: Popover + context menu
    private let popoverState = PopoverState()
    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 550)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                networkMonitor: networkMonitor,
                appDatabase: appDatabase,
                popoverState: popoverState
            )
        )
        return popover
    }()

    // MARK: - Init

    init(statusItem: NSStatusItem, networkMonitor: NetworkMonitor, appDatabase: AppDatabase? = nil) {
        self.statusItem = statusItem
        self.networkMonitor = networkMonitor
        self.appDatabase = appDatabase
        super.init()
    }

    // MARK: - Setup

    func setup() {
        // D-18: em dash before first poll
        updateStatusItemText(text: "\u{2014}")

        // D-01: Left-click opens popover, right-click opens context menu
        // Do NOT set statusItem.menu -- that intercepts all clicks
        if let button = statusItem.button {
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        startObserving()

        Logger.menuBar.info("StatusBarController setup complete")
    }

    // MARK: - Observation (withObservationTracking re-registration pattern)

    private func startObserving() {
        withObservationTracking {
            let speed = self.networkMonitor.aggregateSpeed
            let hasInterfaces = !self.networkMonitor.interfaceSpeeds.isEmpty

            // D-15: Read display preferences from UserDefaults on each cycle.
            // Since withObservationTracking re-registers every ~2 seconds,
            // preference changes are picked up within one poll cycle.
            let displayModePref = DisplayModePref(
                rawValue: UserDefaults.standard.string(forKey: PreferenceKey.displayMode) ?? "auto"
            ) ?? .auto
            let unitModePref = UnitModePref(
                rawValue: UserDefaults.standard.string(forKey: PreferenceKey.unitMode) ?? "auto"
            ) ?? .auto

            let text = self.textBuilder.build(
                speed: speed,
                mode: displayModePref.toDisplayMode(),
                unit: unitModePref.toUnitMode(),
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

    // MARK: - Click Handling (D-01)

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // D-07: Default to Dashboard tab on left-click open
            popoverState.selectedTab = .dashboard
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showPopover() {
        guard !popover.isShown else { return }
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = buildContextMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // menu is nilled out in menuDidClose(_:)
    }


    // MARK: - Context Menu (D-02)

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let dashboard = NSMenuItem(
            title: "Dashboard",
            action: #selector(showDashboard),
            keyEquivalent: ""
        )
        dashboard.target = self
        menu.addItem(dashboard)

        let prefs = NSMenuItem(
            title: "Preferences",
            action: #selector(showPreferences),
            keyEquivalent: ""
        )
        prefs.target = self
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

    // MARK: - Context Menu Actions (D-03)

    @objc private func showDashboard() {
        popoverState.selectedTab = .dashboard
        showPopover()
    }

    @objc private func showPreferences() {
        popoverState.selectedTab = .preferences
        showPopover()
    }

    // MARK: - NSMenuDelegate

    func menuDidClose(_ menu: NSMenu) {
        // Restore click handling to button action after menu closes
        statusItem.menu = nil
    }

    // MARK: - Actions

    @objc private func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
    }
}
