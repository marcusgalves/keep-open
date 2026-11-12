# Keep Open

A small macOS menu bar app that keeps your favorite apps running. If one of them
quits or crashes, Keep Open opens it again in the background, without stealing focus.

It replaces the classic "shell script + LaunchAgent" setup with a native list you
can see and edit: toggle an app on or off, add with **+**, remove with **−**. Changes
apply immediately, with no launchd reload.

## Features

- Native SwiftUI menu bar window, styled like the lists in System Settings.
- Per-app switch: keep the app in the list but stop watching it.
- **+** offers the apps that are running now, or any app via Finder.
- Status per app: running, not running, last reopened, or the error from the last attempt.
- Reopens an app 10 s after it quits (enough time for self-updaters to relaunch on their
  own), plus a periodic check (15 s to 5 min).
- Apps open hidden and in the background (like `open -g -j`).
- **Watched process**: for apps whose work runs in a helper, check a process name instead
  of the app (e.g. Karabiner-Elements → `Karabiner-Core-Service`). Right-click a row.
- Pause switch for when you want apps to stay closed (updates, debugging).
- **Open at login** registers Keep Open as a per-user LaunchAgent through `SMAppService`:
  it starts at login and launchd restarts it if it crashes, but not after you choose Quit.

## Requirements

macOS 14 Sonoma or later. Building needs Xcode 16 or later (Swift 6 toolchain).

## Build and install

```sh
git clone https://github.com/marcusgalves/keep-open.git
cd keep-open
./scripts/install.sh   # builds, copies to /Applications and opens it
```

`./scripts/build-app.sh` only builds `build/Keep Open.app` (universal binary).
`swift run` works for UI work, but *Open at login* needs the app bundle.

Signing: the script uses your first *Apple Development* or *Developer ID Application*
identity from the keychain, and falls back to ad-hoc (`SIGN_IDENTITY=-` forces it).
A stable identity matters with *Open at login*: an ad-hoc signature changes on every
build, launchd rejects the new binary, and Keep Open has to register again (it does
so by itself when opened, which can take about 30 seconds).

## Configuration

The list lives in `~/Library/Application Support/KeepOpen/config.json`:

```json
{
  "checkInterval": 60,
  "isPaused": false,
  "apps": [
    {
      "id": "F5C04308-74F8-437A-85D2-4D26BB5EE85D",
      "name": "Karabiner-Elements",
      "path": "/Applications/Karabiner-Elements.app",
      "bundleIdentifier": "org.pqrs.Karabiner-Elements.Settings",
      "processName": "Karabiner-Core-Service",
      "isEnabled": true
    }
  ]
}
```

The app writes this file on every change. If you edit it by hand, quit and reopen Keep Open.

## How it decides an app is running

- With a **watched process** set: a process owned by your user whose executable has that
  exact name (the same idea as `pgrep -u $USER`).
- Otherwise: a running app with the same bundle identifier (or the same bundle path).

If an app moved, Keep Open finds it again through its bundle identifier.

## Logs

```sh
log stream --predicate 'subsystem == "com.marcusgalves.KeepOpen"'
```

## Migrating from a shell script LaunchAgent

Add the same apps in Keep Open, then unload the old agent:

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/<your-agent>.plist
```

## License

MIT
