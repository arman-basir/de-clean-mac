import SwiftUI
import AppKit

struct AppsView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var isLoading = false
    @State private var uninstallingID: String?
    @State private var errorMessage: String?
    @State private var failedApp: InstalledApp?
    @State private var searchText: String = ""
    @State private var pendingUninstall: InstalledApp?
    @State private var iconCache: [String: NSImage] = [:]

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return engine.apps }
        return engine.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton(selected: $selected)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Uninstall Apps").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Scans /Applications and ~/Applications (\(engine.apps.count) found)")
                            .font(.system(size: 13)).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    if isLoading { ProgressView().scaleEffect(0.7) }
                    Button {
                        Task { isLoading = true; await engine.loadApps(); cacheIcons(); isLoading = false }
                    } label: {
                        Text("Refresh")
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(Theme.panel2)
                            .foregroundColor(Theme.text)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(isLoading)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.mutedDim).font(.system(size: 12))
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Theme.mutedDim)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.panel2)
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))

                if let errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.amber)
                            Text(errorMessage).font(.system(size: 12.5)).foregroundColor(Theme.text)
                            Spacer()
                            Button { self.errorMessage = nil; self.failedApp = nil } label: {
                                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.muted)
                            }.buttonStyle(.plain)
                        }
                        if let failedApp {
                            Button {
                                uninstallElevated(failedApp)
                            } label: {
                                Text("Try with Admin Password").font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(Theme.amber)
                                    .foregroundColor(Color(hex: "0A1210"))
                                    .cornerRadius(8)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Theme.amber.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.amber.opacity(0.4), lineWidth: 1))
                }

                if isLoading && engine.apps.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Scanning /Applications and computing sizes...")
                                .font(.system(size: 12.5)).foregroundColor(Theme.mutedDim)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if filteredApps.isEmpty {
                    Text(searchText.isEmpty
                        ? "No applications found, or Full Disk Access hasn't been granted yet."
                        : "No apps match \"\(searchText)\".")
                        .font(.system(size: 13)).foregroundColor(Theme.mutedDim)
                }

                VStack(spacing: 8) {
                    ForEach(filteredApps) { app in
                        HStack(spacing: 12) {
                            Image(nsImage: iconCache[app.id] ?? NSImage())
                                .resizable().frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).font(.system(size: 13, weight: .medium))
                                Text(app.lastUsed.map { formattedDate($0) } ?? "Unknown")
                                    .font(.system(size: 11)).foregroundColor(Theme.mutedDim)
                            }
                            Spacer()
                            Text(formatBytes(app.sizeBytes)).font(.system(size: 12.5, design: .monospaced)).foregroundColor(Theme.muted)

                            if uninstallingID == app.id {
                                ProgressView().scaleEffect(0.6).frame(width: 70)
                            } else {
                                Button {
                                    pendingUninstall = app
                                } label: {
                                    Text("Uninstall").font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 13).padding(.vertical, 7)
                                        .background(Theme.danger)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Theme.panel2)
                        .cornerRadius(12)
                    }
                }

                Text("Uninstalling moves the app to the Trash. Leftover files (preferences/cache) may remain in ~/Library — macOS doesn't provide a reliable receipts database without a separate installed helper. Apps installed system-wide (not by your user account) may require admin permission to remove.")
                    .font(.system(size: 11)).foregroundColor(Theme.mutedDim)
            }
            .padding(24)
        }
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
        .onAppear {
            if engine.apps.isEmpty {
                isLoading = true
                Task { await engine.loadApps(); cacheIcons(); isLoading = false }
            } else {
                cacheIcons()
            }
        }
        .confirmationDialog(
            "Uninstall this app?",
            isPresented: Binding(get: { pendingUninstall != nil }, set: { if !$0 { pendingUninstall = nil } }),
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                if let app = pendingUninstall { uninstall(app) }
                pendingUninstall = nil
            }
            Button("Cancel", role: .cancel) { pendingUninstall = nil }
        } message: {
            if let app = pendingUninstall {
                Text("\"\(app.name)\" (\(formatBytes(app.sizeBytes))) will be moved to the Trash.")
            }
        }
    }

    private func uninstall(_ app: InstalledApp) {
        errorMessage = nil
        failedApp = nil
        uninstallingID = app.id
        Task {
            do {
                try await engine.uninstallApp(app)
            } catch {
                errorMessage = "Couldn't remove \"\(app.name)\": \(error.localizedDescription)"
                failedApp = app
            }
            uninstallingID = nil
        }
    }

    private func uninstallElevated(_ app: InstalledApp) {
        errorMessage = nil
        failedApp = nil
        uninstallingID = app.id
        Task {
            do {
                try await engine.uninstallAppElevated(app)
            } catch {
                errorMessage = "Still couldn't remove \"\(app.name)\" with admin privileges: \(error.localizedDescription)"
                failedApp = app
            }
            uninstallingID = nil
        }
    }

    private func cacheIcons() {
        for app in engine.apps where iconCache[app.id] == nil {
            iconCache[app.id] = NSWorkspace.shared.icon(forFile: app.path.path)
        }
    }

    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return "Last opened: " + f.string(from: d)
    }
}
