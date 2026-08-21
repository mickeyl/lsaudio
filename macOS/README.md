# LSAudio for macOS

LSAudio for macOS is a native macOS 26 menu-bar app built on the same `LSAudioCore` module as the CLI. It queries CoreAudio directly and never launches or parses the command-line executable.

## CLI capability mapping

| CLI | macOS app |
| --- | --- |
| Default active-process list | Menu-bar panel and Processes window |
| `--all` | Show idle clients toggle |
| Pattern argument | Search plus the signal target field |
| `--paths` | Executable-path toggle and process inspector |
| `--watch` | Push-driven event history without polling |
| `--plain` | Copy or export tab-separated text and event logs |
| `--json` | Copy or export JSON with the same fields |
| `--no-color` | Native semantic labels; color is never the sole status indicator |
| `kill [target]` | Signal sheet with live match preview |
| `--signal` | Named and numeric signal field |
| `--dry-run` | Dry-run toggle and non-destructive result |
| `--force` / `--no-input` | Replaced by explicit GUI review and confirmation |
| `--sudo` | Administrator authorization for permission-denied targets |

## Architecture

- `LSAudioCore` owns CoreAudio discovery, property-listener monitoring, filtering, signal parsing, and CLI-compatible export formatting.
- `AppModel` is the main-actor UI state boundary and receives snapshots from `AudioProcessMonitor`.
- The app performs an initial scan at launch and reacts immediately to CoreAudio property listeners. A fallback scan runs every two seconds, or every second while the menu-bar panel is open, because macOS does not notify every activity transition reliably.
- The `LSUIElement` app stays out of the Dock and opens its process window on demand.

## Build and test

XcodeGen and Shark are required locally.

```sh
make mac-build
make mac-test
make mac-run
```

## Homebrew release

The native app ships independently from the CLI formula as the
`lsaudio-menubar` Homebrew Cask. App releases use the tag
`macos-v<version>` and the GitHub asset name
`LSAudio-<version>-macOS.zip`.

```sh
make mac-release NOTARY_PROFILE=NOTARIZE
```

This target creates a Developer-ID-signed Release build with the hardened
runtime, submits it for notarization, staples the ticket, verifies Gatekeeper
acceptance, and writes the final archive to `macOS/Dist/`. Upload that exact
archive without rebuilding it, then copy its SHA-256 to
`../homebrew-formulae/Casks/lsaudio-menubar.rb`.
