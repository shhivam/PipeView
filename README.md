<p align="center">
  <h1 align="center">PipeView</h1>
  <p align="center">A lightweight macOS menu bar app for real-time network bandwidth monitoring.</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/github/license/shhivam/PipeView" alt="License">
</p>

> [!NOTE]
> PipeView is currently in early release. If you run into issues, please [open an issue](https://github.com/shhivam/PipeView/issues).

## Features

- **Live speeds in the menu bar** — see your upload/download rates at a glance (↑ 1.2 MB/s ↓ 45 KB/s)
- **Per-interface breakdown** — Wi-Fi, Ethernet, VPN shown separately
- **Historical charts** — view bandwidth usage across 1 hour, 24 hours, 7 days, or 30 days
- **Cumulative stats** — total data transferred today, this week, and this month
- **Configurable units** — auto-scale, or lock to KB/s, MB/s, GB/s
- **Adjustable polling** — update every 1s, 2s, or 5s
- **Launch at login** — start automatically with your Mac
- **Zero bloat** — native Swift, ~15 MB memory, <1% CPU

## Install

### Download

1. Go to the [Releases](https://github.com/shhivam/PipeView/releases) page
2. Download **PipeView-v1.0.dmg**
3. Open the DMG and drag **PipeView.app** to **Applications**

### Bypass Gatekeeper (required — app is not notarized)

Since this app is not signed with an Apple Developer certificate, macOS will block it by default. Run this once after installing:

```bash
xattr -rd com.apple.quarantine /Applications/PipeView.app
```

Then open the app normally. If macOS still shows a warning, go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from source

Requires **Xcode 16+** and **macOS 14 (Sonoma)** or later.

```bash
git clone https://github.com/shhivam/PipeView.git
cd PipeView
open PipeView.xcodeproj
```

Then hit **⌘R** to build and run.

## Usage

- **Left-click** the menu bar item to open the dashboard
- **Right-click** for quick access to preferences, about, or quit
- **Esc** or the close button dismisses the panel

## Built with

- [Swift](https://swift.org) + [SwiftUI](https://developer.apple.com/xcode/swiftui/) + AppKit
- [Swift Charts](https://developer.apple.com/documentation/charts) for historical graphs
- [GRDB.swift](https://github.com/groue/GRDB.swift) for local SQLite storage
- `sysctl IFMIB_IFDATA` for accurate 64-bit network byte counters

## License

[WTFPL](LICENSE)
