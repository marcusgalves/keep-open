import AppKit
import Observation
import ServiceManagement

/// Registers Keep Open itself as a per-user launch agent through `SMAppService`.
/// The bundled agent plist starts it at login and restarts it if it crashes
/// (`KeepAlive.SuccessfulExit = false`), but not after a normal Quit.
@Observable
@MainActor
final class LoginItem {
    static let plistName = "com.marcusgalves.KeepOpen.agent.plist"

    private let service = SMAppService.agent(plistName: LoginItem.plistName)
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var lastError: String?

    /// False when running outside an app bundle (e.g. `swift run`).
    let isAvailable: Bool = Bundle.main.bundleIdentifier != nil

    init() { refresh() }

    var isEnabled: Bool { status == .enabled }
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() {
        guard isAvailable else { return }
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            log.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    /// Runs when this copy was not started by launchd although the agent is on.
    /// That means launchd could not spawn the bundle (typically after a rebuild
    /// changed the ad-hoc signature), so register again for the current binary;
    /// launchd then starts its own copy, which takes over from this one.
    func repairIfNeeded() {
        guard isAvailable,
              ProcessInfo.processInfo.environment[InstanceGuard.launchdEnvironmentKey] != "1",
              service.status == .enabled else { return }
        // Right after the binary changes, launchd may still hold the old code
        // signature and fail the spawn (OS_REASON_CODESIGNING). When launchd's copy
        // starts, it terminates this one; while this copy is alive, try again.
        Task { @MainActor in
            for attempt in 1...4 {
                log.notice("Agent enabled but not running under launchd; registering again (\(attempt))")
                try? await service.unregister()
                try? await Task.sleep(for: .seconds(1))
                setEnabled(true)
                try? await Task.sleep(for: .seconds(Double(4 * attempt)))
            }
            log.error("launchd did not take over; this copy keeps running without crash restart")
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Keeps a single instance running. The copy started by launchd wins, so the
/// crash-restart guarantee applies to the instance that keeps running.
enum InstanceGuard {
    static let launchdEnvironmentKey = "KEEPOPEN_LAUNCHD"

    static func resolve() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = NSRunningApplication.current.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me }
        guard !others.isEmpty else { return }

        if ProcessInfo.processInfo.environment[launchdEnvironmentKey] == "1" {
            others.forEach { $0.terminate() }
        } else {
            exit(0)
        }
    }
}
