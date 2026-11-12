import AppKit
import Observation
import os

let log = Logger(subsystem: "com.marcusgalves.KeepOpen", category: "app")

/// Holds the list of monitored apps and runtime status. Every change is saved
/// immediately, and the monitor picks it up without a restart.
@Observable
@MainActor
final class AppStore {
    private(set) var config = KeepOpenConfig()

    // Runtime status (not persisted).
    var running: Set<UUID> = []
    var lastReopened: [UUID: Date] = [:]
    var lastError: [UUID: String] = [:]

    /// Called after any config change so the monitor can react at once.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored let fileURL: URL

    init(fileURL: URL = AppStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("KeepOpen", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    var sortedApps: [MonitoredApp] {
        config.apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var enabledApps: [MonitoredApp] { config.apps.filter(\.isEnabled) }

    var hasProblem: Bool {
        enabledApps.contains { lastError[$0.id] != nil }
    }

    // MARK: Mutations

    func add(urls: [URL]) {
        update { config in
            for url in urls {
                let app = MonitoredApp(url: url)
                let duplicate = config.apps.contains {
                    $0.path == app.path || ($0.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier)
                }
                if !duplicate { config.apps.append(app) }
            }
        }
    }

    func remove(ids: Set<UUID>) {
        update { $0.apps.removeAll { ids.contains($0.id) } }
        for id in ids {
            lastError[id] = nil
            lastReopened[id] = nil
        }
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        update { config in
            guard let index = config.apps.firstIndex(where: { $0.id == id }) else { return }
            config.apps[index].isEnabled = enabled
        }
        if !enabled { lastError[id] = nil }
    }

    func setProcessName(_ name: String?, for id: UUID) {
        update { config in
            guard let index = config.apps.firstIndex(where: { $0.id == id }) else { return }
            let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
            config.apps[index].processName = trimmed.isEmpty ? nil : trimmed
        }
    }

    func setPaused(_ paused: Bool) {
        update { $0.isPaused = paused }
    }

    func setCheckInterval(_ interval: TimeInterval) {
        update { $0.checkInterval = max(5, interval) }
    }

    private func update(_ change: (inout KeepOpenConfig) -> Void) {
        change(&config)
        save()
        onChange?()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            config = try JSONDecoder().decode(KeepOpenConfig.self, from: data)
        } catch {
            log.error("Could not read \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Could not save config: \(error.localizedDescription, privacy: .public)")
        }
    }
}
