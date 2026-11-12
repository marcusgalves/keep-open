import AppKit
import SwiftUI

@main
struct KeepOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(delegate.store)
                .environment(delegate.loginItem)
                .environment(\.monitor, delegate.monitor)
        } label: {
            Image(systemName: menuBarSymbol)
                .accessibilityLabel("Keep Open")
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbol: String {
        if delegate.store.config.isPaused { return "pause.circle" }
        if delegate.store.hasProblem { return "exclamationmark.triangle" }
        return "lifepreserver"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppStore()
    let loginItem = LoginItem()
    private(set) lazy var monitor = Monitor(store: store)

    func applicationWillFinishLaunching(_ notification: Notification) {
        InstanceGuard.resolve()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
    }
}

private struct MonitorKey: EnvironmentKey {
    static let defaultValue: Monitor? = nil
}

extension EnvironmentValues {
    var monitor: Monitor? {
        get { self[MonitorKey.self] }
        set { self[MonitorKey.self] = newValue }
    }
}
