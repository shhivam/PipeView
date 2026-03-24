import AppKit

/// Floating utility panel for the bandwidth monitor's main content window.
///
/// Replaces NSPopover with a centered, always-on-top panel that dismisses
/// when the user clicks outside or switches focus (per D-01, D-02, D-03, UIST-02).
@MainActor
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Float above other windows
        isFloatingPanel = true
        level = .floating

        // Hide title bar chrome
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Hide standard window buttons (close/minimize/zoom)
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // D-03: No animation on appear/disappear
        animationBehavior = .none

        // Reuse panel instance across toggles (don't release on close)
        isReleasedWhenClosed = false

        // Not draggable -- fixed centered position
        isMovableByWindowBackground = false

        // Show on all spaces (follows user across desktops)
        collectionBehavior.insert(.fullScreenAuxiliary)
    }

    // Allow the panel to receive keyboard events (for pickers, chart interactions)
    override var canBecomeKey: Bool { true }

    // Panels should not become main window (auxiliary panel semantics)
    override var canBecomeMain: Bool { false }

    // D-02: Dismiss when user clicks outside or switches focus
    override func resignKey() {
        super.resignKey()
        close()
    }
}
