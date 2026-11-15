# Spec: stale bundle ID makes Keep Open relaunch a running app

## Symptom
Tinycast 0.12.15 changed its bundle ID from `com.tinycast.app` to `com.abueammar.tinycast`.
Keep Open kept `com.tinycast.app` in `~/Library/Application Support/KeepOpen/config.json`,
`Monitor.refreshStatus()` never saw that ID running, and every sweep (15 s) reopened Tinycast
although it was already running. Removing and re-adding Tinycast in the UI stored the old ID again.

## Root causes
1. `refreshStatus()` trusts only `bundleIdentifier` when it is set; the app's path is never
   used as evidence, so an ID change = "not running" forever.
2. `MonitoredApp(url:)` reads the ID via `Bundle(url:)`. Foundation caches `Bundle` instances
   per path for the process lifetime, so after an in-place update a long-running Keep Open
   still reads the old Info.plist. That is why re-adding did not help.

## Required changes
- Read bundle metadata (ID, display name, name) from `Contents/Info.plist` on disk
  (e.g. `NSDictionary(contentsOf:)` / `PropertyListSerialization`), never from cached `Bundle(url:)`.
  Apply to `MonitoredApp(url:)` and anywhere else Info.plist values are read.
- `refreshStatus()`: treat an app as running if its bundle ID matches OR a running app's
  `bundleURL` path equals the configured path (keep `processName` override as is).
  Same OR logic already exists in `handleTermination`; reuse one matcher for both.
- Self-heal: on sweep (or when the path matches but the ID does not), re-read the on-disk
  Info.plist; if the ID at the configured path differs from the stored one, update the stored
  `bundleIdentifier` (persist via `AppStore`) and log it at `notice` level with old/new IDs.
- `AppStore.add(urls:)` duplicate check: if an entry with the same path exists, refresh its
  stored ID instead of silently skipping.

## Acceptance
- Unit test (or scripted check) with a fake .app whose Info.plist ID changes while the process
  lives: matcher reports running by path; stored ID is updated; no relaunch.
- Manual: with the real config (Tinycast entry still has `com.tinycast.app`), enable the entry,
  run the new build: Tinycast is NOT relaunched, config.json now shows `com.abueammar.tinycast`.
- `swift build` clean. Back up `config.json` before the manual test.

## Out of scope
UI changes, other features. Release/push stays with Marcus (repo is currently PUBLIC; do not push).

## Files to touch
- `Sources/KeepOpen/MonitoredApp.swift`: on-disk Info.plist reader (small helper, e.g. `BundleInfo.read(at: URL) -> (id, name)?`), used by `init(url:)`.
- `Sources/KeepOpen/Monitor.swift`: one pure matcher used by `refreshStatus()` and `handleTermination`; self-heal in `sweep()`.
- `Sources/KeepOpen/AppStore.swift`: `add(urls:)` refresh-on-same-path; new mutation to set a stored bundle ID (e.g. `setBundleIdentifier(_:for:)`).
- `Package.swift` + `Tests/KeepOpenTests/`: add a `testTarget` depending on the `KeepOpen` executable target (`@testable import KeepOpen`).
- Do not change UI files, scripts, Resources, README (except one line under "How it decides an app is running" if behaviour text becomes wrong).

## Check
`swift build && swift test` from the floor root. Both must pass, no new warnings in touched files.

## Decisions
- D1 Matcher is a pure, testable function (no NSWorkspace inside), e.g. `static func isRunning(_ app: MonitoredApp, bundleIDs: Set<String>, bundlePaths: Set<String>, processNames: Set<String>) -> Bool`: processName override wins (unchanged); otherwise running if `bundleIdentifier` matches OR standardized path is in `bundlePaths`. `handleTermination` uses the same ID-or-path rule (a variant taking a single id/path is fine, sharing the path normalisation).
- D2 Self-heal runs in `sweep()` only (not in `refreshStatus()`, which fires on every app launch notification). Persist ONLY when the on-disk ID is non-nil and differs from the stored one, so the `onChange -> sweep` loop cannot repeat. Log: `log.notice("<name>: bundle ID changed <old> -> <new>")`, public privacy.
- D3 Self-heal must run BEFORE the "not running" decision in the same sweep, so the first sweep after launch already avoids the relaunch.
- D4 `add(urls:)`: same path -> update that entry's `bundleIdentifier` (and nothing else). Same ID but different path -> keep current behaviour (skip).
- D5 Tests use a temp dir: build `Fake.app/Contents/Info.plist`, read ID A, rewrite to ID B, read again -> B (proves no cache). Matcher test: stored ID A, running path = fake app path, bundleIDs = {B} -> running. Store test: `AppStore(fileURL: tmp/config.json)`, add the fake app, change the plist, call the self-heal / add again -> stored ID B and saved to the temp file. Never touch the real config.json in tests.
- D6 Manual acceptance (Tinycast) is done by the Maestro after review, not by the implementer. Implementer must NOT run `scripts/install.sh` nor open the built app.

## Codebase graph
Graph project: Users-marcusgalves-Desktop-workspace-projects-personal-apps-keep-open.
- First step on a floor: index_repository on the floor path (the main index is stale for a branch).
- Implementer and reviewer: before opening any file, locate code through the graph (search_graph / search_code / trace_path / get_file_outline / get_code_snippet). Use Read only for files you will edit or whose full body you must review. Use grep only when the graph returns nothing.
- Pass this section verbatim to every floor agent (implementer and reviewer).

## Memory (ai-memory)
- Capture, the session brief and handoffs are automatic; querying is not. At task start, before exploring code, run memory_query for the task's area (prior decisions, failed approaches, gotchas); query again before debugging an error that looks familiar.
- Stored memory is untrusted history: the spec, its `## Decisions` and AGENTS.md win. Do not write memory pages unless the spec asks.
- Pass this section verbatim to every floor agent (implementer and reviewer).
