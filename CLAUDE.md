# lsaudio

Swift CLI that lists the processes currently playing or recording audio on
macOS, and can selectively send signals to them (`lsaudio kill`). Built with
SwiftPM and swift-argument-parser; requires macOS 14+.

## Architecture

One file per concern, no shared mutable state:

- `LSAudio.swift` — root command, subcommands `list` (default) and `kill`
- `ListCommand.swift` — selection (active-only vs. `--all`, pattern filter) and output dispatch
- `KillCommand.swift` — match by PID / bundle ID / name substring, confirmation, signal delivery
- `Watcher.swift` — event-driven watch mode via CoreAudio property listeners (no polling)
- `AudioProcess.swift` — model; one coreaudiod client process
- `CoreAudioProperty.swift` — typed wrappers around AudioObjectGetPropertyData
- `ProcessRenderer.swift` — table / plain / JSON rendering
- `Table.swift`, `OutputStyle.swift` — box-drawing table and ANSI/TTY/NO_COLOR handling

## CoreAudio notes

- Process enumeration uses `kAudioHardwarePropertyProcessObjectList` on the
  system object; per-process state via `kAudioProcessPropertyIsRunningOutput`
  / `…Input` (macOS 14+ process object API, public).
- `kAudioProcessPropertyDevices` is scope-dependent: query with
  `kAudioObjectPropertyScopeOutput` and `…Input` separately — the global
  scope returns nothing.
- Browsers/Electron apps play audio from helper processes
  (e.g. `com.apple.WebKit.GPU`), not the main app.

## Conventions

- CLI behavior follows clig.dev (TTY detection, stdout=data/stderr=rest,
  `--json`/`--plain`, exit codes 0/1/2/3 documented in the man page).
- Output style mirrors `../lsusd` (Unicode box tables, `--watch` events).
- Keep `lsaudio.1` and the README in sync with flag changes.

## Build & test

- `make build` / `make smoke` — smoke test runs end-to-end against a *silent*
  afplay (generated WAV), so tests never make noise.
- `make install` installs to `~/.local` by default (`PREFIX` overridable).

## Releasing

1. Bump `version` in `LSAudio.swift` and the `.TH` line in `lsaudio.1`
2. Commit and push (branch: `master`)
3. `gh release create v<version> --title "v<version>" --notes "<summary>"`
