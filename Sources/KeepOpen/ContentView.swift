import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(LoginItem.self) private var loginItem
    @Environment(\.monitor) private var monitor

    @State private var selection: Set<UUID> = []
    @State private var editing: MonitoredApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            appList
            footer
        }
        .padding(14)
        .frame(width: 360)
        .sheet(item: $editing) { app in
            AppDetailSheet(app: app) { processName in
                store.setProcessName(processName, for: app.id)
            }
        }
        .onAppear {
            loginItem.refresh()
            monitor?.refreshStatus()
        }
        .background(FadingWindow())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep Open").font(.headline)
                Text(store.config.isPaused
                     ? "Paused. Apps that quit stay closed."
                     : "Reopens these apps when they quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Monitoring", isOn: Binding(
                get: { !store.config.isPaused },
                set: { store.setPaused(!$0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .help(store.config.isPaused ? "Resume monitoring" : "Pause monitoring")
        }
    }

    // MARK: List

    private var appList: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.sortedApps) { app in
                    AppRow(app: app)
                        .tag(app.id)
                        .contextMenu { contextMenu(for: app) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .alternatingRowBackgrounds(.disabled)
            .frame(height: listHeight)
            .overlay {
                if store.config.apps.isEmpty {
                    ContentUnavailableView {
                        Label("No Apps", systemImage: "square.dashed")
                    } description: {
                        Text("Click + to add an app to keep open.")
                    }
                }
            }
            .onDeleteCommand { removeSelection() }

            Divider()

            HStack(spacing: 0) {
                AddAppMenu(existing: store.config.apps) { urls in
                    store.add(urls: urls)
                }
                Divider().frame(height: 14).padding(.horizontal, 2)
                Button(action: removeSelection) {
                    Image(systemName: "minus").frame(width: 22, height: 20)
                }
                .disabled(selection.isEmpty)
                .help("Remove the selected app")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 6)
            .frame(height: 26)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor))
        )
    }

    private var listHeight: CGFloat {
        let rows = max(store.config.apps.count, 3)
        return min(CGFloat(rows) * 46 + 10, 560)
    }

    @ViewBuilder
    private func contextMenu(for app: MonitoredApp) -> some View {
        Button("Open Now") { monitor?.open(app, reason: "opened from menu") }
        Button("Show in Finder") {
            if let url = app.resolvedURL {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        Button("Watched Process…") { editing = app }
        Divider()
        Button("Remove", role: .destructive) {
            store.remove(ids: [app.id])
            selection.remove(app.id)
        }
    }

    private func removeSelection() {
        guard !selection.isEmpty else { return }
        store.remove(ids: selection)
        selection.removeAll()
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if loginItem.isAvailable {
                HStack {
                    Text("Open at login")
                    Spacer()
                    Toggle("Open at login", isOn: Binding(
                        get: { loginItem.isEnabled || loginItem.needsApproval },
                        set: { loginItem.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                }
                if loginItem.needsApproval {
                    HStack(spacing: 4) {
                        Text("Needs approval in Login Items.")
                            .foregroundStyle(.secondary)
                        Button("Open Settings") { loginItem.openSystemSettings() }
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                }
                if let error = loginItem.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            HStack {
                Text("Check every")
                Spacer()
                Picker("Check every", selection: Binding(
                    get: { store.config.checkInterval },
                    set: { store.setCheckInterval($0) }
                )) {
                    ForEach(Self.intervals, id: \.self) { seconds in
                        Text(Self.label(for: seconds)).tag(seconds)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
            }

            Divider()

            HStack {
                Button("Check Now") { monitor?.sweep() }
                    .disabled(store.config.isPaused)
                Spacer()
                Button("Quit Keep Open") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
    }

    private static let intervals: [TimeInterval] = [15, 30, 60, 120, 300]

    private static func label(for seconds: TimeInterval) -> String {
        seconds < 60 ? "\(Int(seconds)) seconds" : (seconds == 60 ? "1 minute" : "\(Int(seconds / 60)) minutes")
    }
}
