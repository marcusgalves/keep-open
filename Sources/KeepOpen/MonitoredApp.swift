import AppKit

/// Reads bundle metadata straight from `Contents/Info.plist` on disk.
/// Foundation's `Bundle(url:)` caches instances per path for the process lifetime,
/// hiding changes after an in-place app update.
enum BundleInfo {
    struct Metadata {
        let bundleIdentifier: String?
        let name: String?
    }

    static func read(at appURL: URL) -> Metadata? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        let id = nonEmpty(plist["CFBundleIdentifier"] as? String)
        let name = nonEmpty(plist["CFBundleDisplayName"] as? String)
            ?? nonEmpty(plist["CFBundleName"] as? String)
        return Metadata(bundleIdentifier: id, name: name)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

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
        let info = BundleInfo.read(at: url)
        self.name = info?.name ?? url.deletingPathExtension().lastPathComponent
        self.path = url.path
        self.bundleIdentifier = info?.bundleIdentifier
    }

    static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
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
