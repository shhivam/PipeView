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

    // Phase 8: Floating panel + context menu
    private let popoverState = PopoverState()
    private lazy var panel: FloatingPanel = {
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 650))
        panel.contentView = NSHostingView(
            rootView: PopoverContentView(
                networkMonitor: networkMonitor,
                appDatabase: appDatabase,
                popoverState: popoverState
            )
        )
        return panel
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

        // D-01: Left-click opens panel, right-click opens context menu
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
            togglePanel()
        }
    }

    // MARK: - Panel Management (D-01, D-02, D-03, D-09)

    private func togglePanel() {
        if panel.isVisible {
            panel.close()
        } else {
            // D-09: Default to Dashboard tab on left-click open
            popoverState.selectedTab = .dashboard
            centerPanelOnActiveScreen()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func showPanel() {
        guard !panel.isVisible else { return }
        centerPanelOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Centers the panel on the screen that currently has keyboard focus.
    /// Uses `visibleFrame` to avoid placing the panel behind the menu bar or Dock.
    private func centerPanelOnActiveScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - panelSize.height) / 2

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func showContextMenu() {
        let menu = buildContextMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // menu is nilled out in menuDidClose(_:)
    }


    // MARK: - Context Menu (D-08)

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

    // MARK: - Context Menu Actions (D-08, D-09)

    @objc private func showDashboard() {
        popoverState.selectedTab = .dashboard
        showPanel()
    }

    @objc private func showPreferences() {
        popoverState.selectedTab = .preferences
        showPanel()
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
