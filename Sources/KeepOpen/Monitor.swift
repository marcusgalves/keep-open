import AppKit

/// Reopens monitored apps that are not running.
///
/// Two triggers: an app quitting (reopened after `relaunchDelay`, which leaves
/// room for self-updaters that quit and relaunch on their own) and a periodic
/// sweep every `checkInterval` seconds that also catches helper processes.
@MainActor
final class Monitor {
    private let store: AppStore
    private var timer: Timer?
    private var inFlight: Set<UUID> = []
    private var observers: [NSObjectProtocol] = []
    private var scheduledInterval: TimeInterval = 0

    let relaunchDelay: TimeInterval = 10

    init(store: AppStore) {
        self.store = store
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            let url = app?.bundleURL
            MainActor.assumeIsolated { self?.handleTermination(bundleID: bundleID, url: url) }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStatus() }
        })

        store.onChange = { [weak self] in
            self?.rescheduleIfNeeded()
            self?.sweep()
        }
        rescheduleIfNeeded()
        sweep()
    }

    /// Checks every enabled app and opens the ones that are not running.
    func sweep() {
        refreshStatus()
        guard !store.config.isPaused else { return }
        for app in store.enabledApps where !store.running.contains(app.id) && !inFlight.contains(app.id) {
            open(app, reason: "not running")
        }
    }

    func open(_ app: MonitoredApp, reason: String) {
        guard let url = app.resolvedURL else {
            store.lastError[app.id] = "App not found at \(app.path)"
            log.error("\(app.name, privacy: .public): not found at \(app.path, privacy: .public)")
            return
        }
        inFlight.insert(app.id)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false      // like `open -g`
        configuration.hides = true           // like `open -j`
        configuration.addsToRecentItems = false

        let id = app.id
        let name = app.name
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.inFlight.remove(id)
                if let message {
                    self.store.lastError[id] = message
                    log.error("Failed to open \(name, privacy: .public): \(message, privacy: .public)")
                } else {
                    self.store.lastError[id] = nil
                    self.store.lastReopened[id] = Date()
                    log.notice("Opened \(name, privacy: .public) (\(reason, privacy: .public))")
                }
                self.refreshStatus()
            }
        }
    }

    func refreshStatus() {
        let runningApps = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
        let bundleIDs = Set(runningApps.compactMap(\.bundleIdentifier))
        let bundlePaths = Set(runningApps.compactMap { $0.bundleURL?.standardizedFileURL.path })
        let needsProcesses = store.config.apps.contains { $0.watchedProcessName != nil }
        let processNames = needsProcesses ? ProcessScanner.executableNames() : []

        var running = Set<UUID>()
        for app in store.config.apps {
            let isRunning: Bool
            if let processName = app.watchedProcessName {
                isRunning = processNames.contains(processName)
            } else if let bundleID = app.bundleIdentifier {
                isRunning = bundleIDs.contains(bundleID)
            } else {
                isRunning = bundlePaths.contains(URL(fileURLWithPath: app.path).standardizedFileURL.path)
            }
            if isRunning { running.insert(app.id) }
        }
        if running != store.running { store.running = running }
    }

    private func handleTermination(bundleID: String?, url: URL?) {
        refreshStatus()
        let path = url?.standardizedFileURL.path
        let watched = store.enabledApps.contains { app in
            (bundleID != nil && app.bundleIdentifier == bundleID)
                || (path != nil && URL(fileURLWithPath: app.path).standardizedFileURL.path == path)
        }
        guard watched else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + relaunchDelay) { [weak self] in
            self?.sweep()
        }
    }

    private func rescheduleIfNeeded() {
        let interval = store.config.checkInterval
        guard interval != scheduledInterval || timer == nil else { return }
        scheduledInterval = interval
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sweep() }
        }
        timer.tolerance = min(5, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
