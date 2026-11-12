import AppKit

/// One app that Keep Open reopens when it is not running.
struct MonitoredApp: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// Path to the `.app` bundle.
    var path: String
    var bundleIdentifier: String?
    /// Optional executable name to look for instead of the app itself.
    /// Useful for apps whose work runs in a helper process
    /// (e.g. Karabiner-Elements runs `Karabiner-Core-Service`).
    var processName: String?
    var isEnabled: Bool = true

    init(url: URL) {
        let bundle = Bundle(url: url)
        self.name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        self.path = url.path
        self.bundleIdentifier = bundle?.bundleIdentifier
    }

    /// The bundle URL, falling back to a Launch Services lookup if the app moved.
    var resolvedURL: URL? {
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }
        return nil
    }

    var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: resolvedURL?.path ?? path)
        image.size = NSSize(width: 32, height: 32)
        return image
    }

    var watchedProcessName: String? {
        guard let processName = processName?.trimmingCharacters(in: .whitespaces),
              !processName.isEmpty else { return nil }
        return processName
    }
}

/// Everything persisted to disk.
struct KeepOpenConfig: Codable {
    var checkInterval: TimeInterval = 60
    var isPaused: Bool = false
    var apps: [MonitoredApp] = []
}
