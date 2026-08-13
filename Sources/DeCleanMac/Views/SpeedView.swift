import SwiftUI

struct SpeedView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var isFreeingMemory = false
    @State private var memoryMessage: (text: String, isError: Bool)?
    @State private var pendingRemoveLoginItem: LoginItemEntry?
    @State private var loginItemErrorBanner: String?
    @State private var launchAgentError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton(selected: $selected)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Speed & Memory").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Real memory usage, login items, and startup agents").font(.system(size: 13)).foregroundColor(Theme.muted)
                }

                // ---- Memory ----
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Memory").font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Button {
                            Task {
                                isFreeingMemory = true
                                let result = await engine.freeUpMemory()
                                if result.succeeded {
                                    memoryMessage = ("Memory purge completed.", false)
                                } else {
                                    memoryMessage = ("Couldn't free memory: \(result.message ?? "unknown error").", true)
                                }
                                isFreeingMemory = false
                                try? await Task.sleep(nanoseconds: 4_000_000_000)
                                memoryMessage = nil
                            }
                        } label: {
                            Text(isFreeingMemory ? "Freeing..." : "Free Up Memory")
                                .font(.system(size: 12.5, weight: .semibold))
                                .padding(.horizontal, 13).padding(.vertical, 7)
                                .background(Theme.panel2)
                                .foregroundColor(Theme.text)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                        }.buttonStyle(.plain).disabled(isFreeingMemory)
                    }

                    memoryBar

                    if let memoryMessage {
                        Text(memoryMessage.text)
                            .font(.system(size: 11.5))
                            .foregroundColor(memoryMessage.isError ? Theme.amber : Theme.mint)
                    }

                    HStack(spacing: 18) {
                        memoryLegend("Used", engine.memoryStats.usedBytes, Theme.violet)
                        memoryLegend("Free", engine.memoryStats.freeBytes, Theme.mint)
                        memoryLegend("Wired", engine.memoryStats.wiredBytes, Theme.amber)
                        memoryLegend("Compressed", engine.memoryStats.compressedBytes, Theme.danger)
                    }

                    Text("macOS already manages memory efficiently on its own. \"Free Up Memory\" runs the built-in purge tool to clear inactive disk-cache pages — it's not a substitute for more RAM and its effect is often small.")
                        .font(.system(size: 11)).foregroundColor(Theme.mutedDim)
                }
                .padding(16)
                .background(Theme.panel2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                // ---- Login Items ----
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Login Items").font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(engine.loginItems.count) found").font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
                    }
                    Text("The same list shown in System Settings > General > Login Items.")
                        .font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)

                    if let loginItemErrorBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.amber)
                            Text(loginItemErrorBanner).font(.system(size: 12)).foregroundColor(Theme.text)
                        }
                        .padding(10)
                        .background(Theme.amber.opacity(0.12))
                        .cornerRadius(10)
                    }

                    if let error = engine.loginItemsError {
                        Text(error).font(.system(size: 12)).foregroundColor(Theme.amber)
                    } else if engine.loginItems.isEmpty {
                        Text("No login items found.").font(.system(size: 12.5)).foregroundColor(Theme.mutedDim)
                    }

                    VStack(spacing: 8) {
                        ForEach(engine.loginItems) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "power").foregroundColor(Theme.violet).frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name).font(.system(size: 13, weight: .medium))
                                    Text(item.path).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.mutedDim).lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    pendingRemoveLoginItem = item
                                } label: {
                                    Text("Remove").font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Theme.danger)
                                        .foregroundColor(.white)
                                        .cornerRadius(7)
                                }.buttonStyle(.plain)
                            }
                            .padding(11)
                            .background(Theme.panel)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
                .background(Theme.panel2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                // ---- Launch Agents ----
                VStack(alignment: .leading, spacing: 10) {
                    Text("Launch Agents").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Background helpers from ~/Library/LaunchAgents — toggling unloads/reloads them via launchctl.")
                        .font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)

                    if let launchAgentError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.amber)
                            Text(launchAgentError).font(.system(size: 12)).foregroundColor(Theme.text)
                        }
                        .padding(10)
                        .background(Theme.amber.opacity(0.12))
                        .cornerRadius(10)
                    }

                    if engine.startupItems.isEmpty {
                        Text("No user Launch Agents found.")
                            .font(.system(size: 12.5)).foregroundColor(Theme.mutedDim)
                    }

                    VStack(spacing: 8) {
                        ForEach(engine.startupItems) { item in
                            Button {
                                Task {
                                    do {
                                        try await engine.toggleStartupItem(item)
                                    } catch {
                                        launchAgentError = error.localizedDescription
                                    }
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Capsule()
                                        .fill(item.enabled ? Theme.mint : Theme.panel)
                                        .frame(width: 38, height: 22)
                                        .overlay(
                                            Circle().fill(.white)
                                                .frame(width: 16, height: 16)
                                                .offset(x: item.enabled ? 8 : -8)
                                        )
                                        .overlay(Capsule().stroke(Theme.line, lineWidth: item.enabled ? 0 : 1))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.text)
                                        Text(item.path.lastPathComponent).font(.system(size: 10.5, design: .monospaced)).foregroundColor(Theme.mutedDim)
                                    }
                                    Spacer()
                                }
                                .padding(11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Theme.panel)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
                .background(Theme.panel2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
            }
            .padding(24)
        }
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
        .onAppear {
            engine.loadStartupItems()
            Task { await engine.loadLoginItems() }
            Task { await engine.refreshMemoryStats() }
        }
        .confirmationDialog(
            "Remove this login item?",
            isPresented: Binding(get: { pendingRemoveLoginItem != nil }, set: { if !$0 { pendingRemoveLoginItem = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let item = pendingRemoveLoginItem {
                    Task {
                        do {
                            try await engine.removeLoginItem(item)
                        } catch {
                            loginItemErrorBanner = error.localizedDescription
                        }
                    }
                }
                pendingRemoveLoginItem = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoveLoginItem = nil }
        } message: {
            if let item = pendingRemoveLoginItem {
                Text("\"\(item.name)\" will no longer launch automatically when you log in.")
            }
        }
    }

    private var memoryBar: some View {
        GeometryReader { geo in
            let total = max(engine.memoryStats.totalBytes, 1)
            HStack(spacing: 2) {
                segment(engine.memoryStats.usedBytes - engine.memoryStats.wiredBytes - engine.memoryStats.compressedBytes, total, geo.size.width, Theme.violet)
                segment(engine.memoryStats.wiredBytes, total, geo.size.width, Theme.amber)
                segment(engine.memoryStats.compressedBytes, total, geo.size.width, Theme.danger)
                segment(engine.memoryStats.freeBytes, total, geo.size.width, Theme.mint)
            }
        }
        .frame(height: 18)
        .background(Color.black.opacity(0.3))
        .cornerRadius(9)
    }

    private func segment(_ value: Int64, _ total: Int64, _ width: CGFloat, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: max(0, width * CGFloat(value) / CGFloat(total)))
    }

    private func memoryLegend(_ label: String, _ bytes: Int64, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11.5)).foregroundColor(Theme.muted)
            Text(formatBytes(bytes)).font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.mutedDim)
        }
    }
}
