# Changelog

All notable user-facing changes to LSAudio are documented in this file.

## [1.1.1] - 2026-08-21

### Added

- Added adaptive verification scans every two seconds, increasing to once per
  second while the menu-bar panel is open.
- Added a dedicated macOS app icon for Spotlight, Finder, and system app
  pickers.

### Improved

- Refreshed audio activity immediately whenever the menu-bar panel opens.
- Kept signal-delivery errors visible until they are dismissed.
- Retained CoreAudio property listeners for immediate updates while using the
  verification scan only as a fallback for notifications macOS omits.

## [1.1.0] - 2026-08-19

### Added

- Added the native macOS 26 menu-bar app with live playback and recording
  counts, quick SIGTERM actions, process inspection, event history, exports,
  and configurable confirmation.

## [1.0.0] - 2026-06-07

### Added

- Added the initial command-line release for listing, watching, and signaling
  CoreAudio client processes.

[1.1.1]: https://github.com/mickeyl/lsaudio/compare/macos-v1.1.0...macos-v1.1.1
[1.1.0]: https://github.com/mickeyl/lsaudio/releases/tag/macos-v1.1.0
[1.0.0]: https://github.com/mickeyl/lsaudio/releases/tag/v1.0.0
