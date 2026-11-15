# AGENTS.md: Keep Open

macOS menu bar app (SwiftUI) that reopens chosen apps when they quit. See README.md for features.

## Stack
- Swift 6 toolchain, Swift Package Manager (`Package.swift`), language mode v5. macOS 14+.
- No Xcode project (`*.xcodeproj` is gitignored). No third-party dependencies.
- Logging: `os.Logger`, subsystem `com.marcusgalves.KeepOpen`.

## Layout
- `Sources/KeepOpen/`: the app (single executable target).
  - `MonitoredApp.swift`: persisted model + `KeepOpenConfig`.
  - `AppStore.swift`: config state; saves `config.json` on every change (`fileURL` injectable for tests).
  - `Monitor.swift`: sweep timer, termination/launch observers, running detection, reopen.
  - `ProcessScanner.swift`: watched-process lookup. `LoginItem.swift`: `SMAppService` login agent.
  - `ContentView.swift`, `AppRow.swift`, `FadingWindow.swift`, `KeepOpenApp.swift`: UI.
- `Resources/`: `Info.plist`, login agent plist, `AppIcon.icns`.
- `scripts/`: `build-app.sh`, `install.sh`, `make-icon.swift`.
- `Tests/`: unit tests (if present).

## Commands
- Check: `swift build` (must be warning-free for touched files).
- Test: `swift test` (when a test target exists).
- App bundle: `./scripts/build-app.sh` builds `build/Keep Open.app` (universal, signed with the first Apple Development / Developer ID identity, else ad-hoc).

## Side effects (read before running)
- `./scripts/install.sh` QUITS the running Keep Open, DELETES `/Applications/Keep Open.app`, copies the new build and opens it. Only run it when the task asks for a live/manual test.
- The app reads and writes the real config at `~/Library/Application Support/KeepOpen/config.json`. Back it up before any manual test (`cp config.json config.json.bak-<date>`); tests must use a temp `fileURL`, never the real file.
- A running Keep Open reopens apps: an enabled entry can launch real apps on Marcus's Mac.
- `make-icon.swift` overwrites `Resources/AppIcon.icns`.

## Rules
- The repo is intentionally PUBLIC (approved by Marcus on 2026-11-15). Never commit personal data: no real config.json contents, no paths under the user's home, no tokens. Secret-scan `git diff --cached` before every commit.
- UI copy and code in en-US.
- Keep it dependency-free; prefer AppKit/Foundation APIs.
- Read app metadata from the on-disk `Contents/Info.plist`, not `Bundle(url:)` (Foundation caches bundles per path, so in-place app updates are missed).

## Maestri
- Architect: none
- Release: maestro (granted by Marcus on 2026-11-15: push to origin/main; this app has no deploy)
