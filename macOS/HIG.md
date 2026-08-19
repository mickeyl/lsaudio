# LSAudio macOS Interface Guidelines

## Product shape

LSAudio is a menu-bar utility with a compact live activity panel and one optional process window. The panel answers who is playing or recording immediately; registered idle clients, executable paths, event history, exports, and advanced signal delivery live in the process window.

## Platform and appearance

- Minimum platform: macOS 26.
- Follow the system Light or Dark appearance.
- Use native SwiftUI controls, materials, tables, inspectors, menus, and toolbars.
- Use the macOS system typeface. Technical identifiers and executable paths use the monospaced system design.
- The app is intentionally not sandboxed because signalling arbitrary user and system processes is a core product function. Release builds still use the hardened runtime and Developer ID signing.

## Semantic roles

- Output activity: blue speaker badge.
- Input activity: red microphone badge.
- Simultaneous input and output: both visible badges; never rely on color alone.
- Idle client: secondary text and neutral badge.
- Destructive actions: signal delivery controls and stop-all confirmation.
- Event start/present: success or secondary; change: accent; stop: secondary.
- Each active process row in the menu panel ends with a destructive quick action that sends `SIGTERM` to that exact PID. The button is icon-only, exposes its full action through accessibility and help text, and shows per-row progress while delivery is pending.
- Quick termination asks for confirmation by default. Settings expose a persistent toggle for users who prefer immediate delivery.
- Quick termination reuses the full signal-delivery path, including administrator authorization and localized error reporting, without opening the process window or signal sheet.

## Layout metrics

- Menu panel: 400 x 680 points, constrained by the available screen height.
- Main window minimum: 900 x 540 points; default: 1,180 x 720 points.
- Inspector width: 280-400 points.
- Menu rows reserve 12 points between trailing badges and the scroll indicator.
- Main-window search and actions belong to the detail column, not the inspector. Actions are individual toolbar items, separated into filter, refresh, signal, and export groups, so they use the available title-bar width before macOS creates an overflow menu.

## Accessibility and localization

- All icon-only controls have explicit accessibility labels and help text.
- Process data is never treated as a localization key.
- All interface copy is available in English and German.
- Plain and JSON exports remain locale-neutral and preserve the CLI field names and formats.
- Advanced signal delivery always presents the exact matches before execution. An empty target can address all active processes, but can never be combined with idle clients.
- Settings end with a centered creator credit and a clickable link to `https://www.vanille.de`.
