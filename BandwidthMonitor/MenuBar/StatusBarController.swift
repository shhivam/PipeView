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

    // Hardcoded defaults for Phase 2 (preferences deferred to Phase 5)
    private let displayMode: DisplayMode = .auto
    private let unitMode: SpeedFormatter.UnitMode = .auto

    // Phase 4: Popover + context menu
    private var selectedTab: PopoverTab = .metrics
    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 550)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                networkMonitor: networkMonitor,
                appDatabase: appDatabase,
                selectedTab: makeTabBinding()
            )
        )
        return popover
    }()

    /// Creates a `Binding<PopoverTab>` that reads/writes `selectedTab` on the main actor.
    /// Uses `MainActor.assumeIsolated` inside the Sendable closure because StatusBarController
    /// is `@MainActor` and the Binding is only used from SwiftUI views (also main-thread).
    private func makeTabBinding() -> Binding<PopoverTab> {
        Binding(
            get: { [weak self] in
                MainActor.assumeIsolated { self?.selectedTab ?? .metrics }
            },
            set: { [weak self] newValue in
                MainActor.assumeIsolated { self?.selectedTab = newValue }
            }
        )
    }

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
            // D-06: Default to Metrics tab on left-click open
            selectedTab = .metrics
            // Update the hosting controller's root view to reflect tab change
            updatePopoverRootView()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showPopover() {
        guard !popover.isShown else { return }
        if let button = statusItem.button {
            updatePopoverRootView()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = buildContextMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // menu is nilled out in menuDidClose(_:)
    }

    private func updatePopoverRootView() {
        let rootView = PopoverContentView(
            networkMonitor: networkMonitor,
            appDatabase: appDatabase,
            selectedTab: makeTabBinding()
        )
        (popover.contentViewController as? NSHostingController<PopoverContentView>)?.rootView = rootView
    }

    // MARK: - Context Menu (D-02)

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let metrics = NSMenuItem(
            title: "Metrics",
            action: #selector(showMetrics),
            keyEquivalent: ""
        )
        metrics.target = self
        menu.addItem(metrics)

        let history = NSMenuItem(
            title: "History",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        history.target = self
        menu.addItem(history)

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

    @objc private func showMetrics() {
        selectedTab = .metrics
        showPopover()
    }

    @objc private func showHistory() {
        selectedTab = .history
        showPopover()
    }

    @objc private func showPreferences() {
        selectedTab = .preferences
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
