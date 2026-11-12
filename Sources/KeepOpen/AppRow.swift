import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppRow: View {
    @Environment(AppStore.self) private var store
    let app: MonitoredApp

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).lineLimit(1)
                if let status {
                    Text(status.text)
                        .font(.caption)
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                        .help(status.text)
                }
            }

            Spacer(minLength: 8)

            Toggle(app.name, isOn: Binding(
                get: { app.isEnabled },
                set: { store.setEnabled($0, for: app.id) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .help(app.watchedProcessName.map { "Watching process \($0)" } ?? app.path)
    }

    private var status: (text: String, color: Color)? {
        guard app.isEnabled else { return nil }
        if let error = store.lastError[app.id] {
            return ("Couldn’t open: \(error)", .red)
        }
        let isRunning = store.running.contains(app.id)
        if !isRunning {
            return (store.config.isPaused ? "Not running" : "Not running, opening soon", .orange)
        }
        if let date = store.lastReopened[app.id] {
            return ("Running · reopened \(date.formatted(date: .omitted, time: .shortened))", .secondary)
        }
        return ("Running", .secondary)
    }
}

/// The "+" button: pick from running apps or choose any app in Finder.
struct AddAppMenu: View {
    let existing: [MonitoredApp]
    let add: ([URL]) -> Void

    var body: some View {
        Menu {
            let candidates = runningCandidates
            if !candidates.isEmpty {
                Section("Running Apps") {
                    ForEach(candidates, id: \.processIdentifier) { app in
                        Button {
                            if let url = app.bundleURL { add([url]) }
                        } label: {
                            Label {
                                Text(app.localizedName ?? app.bundleURL?.lastPathComponent ?? "App")
                            } icon: {
                                if let icon = app.icon { Image(nsImage: menuIcon(icon)) }
                            }
                        }
                    }
                }
                Divider()
            }
            Button("Choose App…") { presentOpenPanel() }
        } label: {
            Image(systemName: "plus").frame(width: 22, height: 20)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add an app")
    }

    private var runningCandidates: [NSRunningApplication] {
        let known = Set(existing.compactMap(\.bundleIdentifier))
        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier, app.bundleURL?.pathExtension == "app",
                      id != me, !known.contains(id), app.activationPolicy != .prohibited
                else { return false }
                return seen.insert(id).inserted
            }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private func menuIcon(_ image: NSImage) -> NSImage {
        let copy = image.copy() as! NSImage
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Add Apps to Keep Open"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in add(urls) }
        }
    }
}

/// Lets the user point the check at a helper process instead of the app.
struct AppDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let app: MonitoredApp
    let save: (String?) -> Void
    @State private var processName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(nsImage: app.icon).resizable().frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.headline)
                    Text(app.bundleIdentifier ?? app.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Watched process")
                TextField("Process name", text: $processName, prompt: Text("The app itself"))
                    .textFieldStyle(.roundedBorder)
                Text("Leave empty to check the app itself. Enter an executable name when the app does its work in a helper, e.g. Karabiner-Core-Service.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(processName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 320)
        .onAppear { processName = app.processName ?? "" }
    }
}
