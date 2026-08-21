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
- `AudioProcessMonitor.swift` — shared CoreAudio snapshot monitor with property listeners and explicit refresh requests
- `AudioProcessExport.swift`, `AudioSignal.swift` — shared CLI/app contracts
- `ProcessRenderer.swift` — table / plain / JSON rendering
- `Table.swift`, `OutputStyle.swift` — box-drawing table and ANSI/TTY/NO_COLOR handling

The shared files live in `Sources/LSAudioCore`; both the CLI target and native
macOS app compile that module. The app lives in `macOS/`, uses XcodeGen as its
project source of truth, targets macOS 26, and localizes UI copy through Shark.
The app supplements CoreAudio notifications with an adaptive fallback scan:
every two seconds normally and every second while the menu-bar panel is open.

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
- `make mac-build` / `make mac-test` / `make mac-run` build, test, and launch
  the native menu-bar app.

## Releasing the CLI

1. Bump `version` in `LSAudio.swift` and the `.TH` line in `lsaudio.1`
2. Commit and push (branch: `master`)
3. `gh release create v<version> --title "v<version>" --notes "<summary>"`

## Releasing the macOS App

The app shares the CLI marketing version but uses its own release tag
`macos-v<version>`.

1. Set `MARKETING_VERSION` for both targets in `macOS/project.yml`.
2. Commit and push the release state. The app build number is stamped from the
   Git commit count.
3. Run `make smoke`, `make mac-test`, and `make mac-build`.
4. Run `make mac-release NOTARY_PROFILE=NOTARIZE`.
5. Upload the exact `macOS/Dist/LSAudio-<version>-macOS.zip` archive to a GitHub
   release tagged `macos-v<version>`.
6. Update and validate `Formula/lsaudio.rb` plus
   `Casks/lsaudio-menubar.rb` in `../homebrew-formulae`, then commit and push
   that repository without including unrelated working-tree changes.
