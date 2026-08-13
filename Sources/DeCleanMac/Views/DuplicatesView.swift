import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var pendingDelete: LargeFile?
    @State private var errorMessage: String?

    var totalWasted: Int64 {
        engine.duplicateGroups.reduce(0) { $0 + $1.wastedBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton(selected: $selected)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Duplicate Finder").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Scans folders enabled in Settings for exact duplicate files under \(engine.duplicateMaxSizeMB) MB")
                            .font(.system(size: 13)).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    if engine.isDuplicateScanning {
                        Button {
                            engine.cancelDuplicateScan()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Theme.danger.opacity(0.16))
                                .foregroundColor(Theme.danger)
                                .cornerRadius(9)
                        }.buttonStyle(.plain)
                    } else {
                        Button {
                            Task { await engine.scanDuplicates() }
                        } label: {
                            Text("Rescan")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Theme.panel2)
                                .foregroundColor(Theme.text)
                                .cornerRadius(9)
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.amber)
                        Text(errorMessage).font(.system(size: 12.5)).foregroundColor(Theme.text)
                        Spacer()
                        Button { self.errorMessage = nil } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.muted)
                        }.buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.amber.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.amber.opacity(0.4), lineWidth: 1))
                }

                if engine.isDuplicateScanning && engine.duplicateGroups.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if engine.duplicateScanTotal > 0 {
                                // Determinate bar once we know how many groups need comparing.
                                ProgressView(value: Double(engine.duplicateScanProgress), total: Double(engine.duplicateScanTotal))
                                    .progressViewStyle(.linear)
                                    .frame(width: 220)
                                    .tint(Theme.mint)
                                Text("\(engine.duplicateScanProgress) / \(engine.duplicateScanTotal) potential matches compared")
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.mutedDim)
                            } else {
                                // Total file count isn't known yet during the initial folder walk.
                                ProgressView()
                                if engine.duplicateScanProgress > 0 {
                                    Text("\(engine.duplicateScanProgress) files scanned so far")
                                        .font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.mutedDim)
                                }
                            }
                            Text(engine.duplicateScanPhase.isEmpty ? "Scanning files..." : engine.duplicateScanPhase)
                                .font(.system(size: 12.5, weight: .medium)).foregroundColor(Theme.text)
                            Text("Files over the size limit, app bundles, photo libraries, and dev folders (node_modules, .git, etc.) are skipped to keep this fast. Click Cancel any time to stop.")
                                .font(.system(size: 11)).foregroundColor(Theme.mutedDim)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                        Spacer()
                    }.padding(.vertical, 40)
                } else if engine.duplicateGroups.isEmpty {
                    Text("No duplicate files found.")
                        .font(.system(size: 13)).foregroundColor(Theme.mutedDim)
                } else {
                    HStack {
                        Text("Space that could be freed: ").font(.system(size: 13)).foregroundColor(Theme.muted)
                            + Text(formatBytes(totalWasted)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(Theme.mint)
                        Spacer()
                    }
                }

                VStack(spacing: 14) {
                    ForEach(engine.duplicateGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(group.files.count) copies · \(formatBytes(group.sizeEach)) each")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.muted)
                                Spacer()
                                Text("wastes \(formatBytes(group.wastedBytes))")
                                    .font(.system(size: 11.5, design: .monospaced)).foregroundColor(Theme.amber)
                            }
                            ForEach(Array(group.files.enumerated()), id: \.element.id) { idx, file in
                                HStack(spacing: 10) {
                                    if idx == 0 {
                                        Text("KEEP").font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                            .background(Theme.mint.opacity(0.16)).foregroundColor(Theme.mint).cornerRadius(5)
                                    } else {
                                        Text("COPY").font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                            .background(Theme.mutedDim.opacity(0.16)).foregroundColor(Theme.mutedDim).cornerRadius(5)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.name).font(.system(size: 12.5)).lineLimit(1)
                                        Text(file.path.deletingLastPathComponent().path)
                                            .font(.system(size: 10)).foregroundColor(Theme.mutedDim).lineLimit(1)
                                    }
                                    Spacer()
                                    if idx > 0 {
                                        Button {
                                            pendingDelete = file
                                        } label: {
                                            Text("Delete").font(.system(size: 11.5, weight: .semibold))
                                                .padding(.horizontal, 11).padding(.vertical, 5)
                                                .background(Theme.danger)
                                                .foregroundColor(.white)
                                                .cornerRadius(7)
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Theme.panel2)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
        .onAppear {
            if engine.duplicateGroups.isEmpty && !engine.isDuplicateScanning {
                Task { await engine.scanDuplicates() }
            }
        }
        .onDisappear {
            if engine.isDuplicateScanning {
                engine.cancelDuplicateScan()
            }
        }
        .confirmationDialog(
            "Delete this copy?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let file = pendingDelete {
                    do {
                        try engine.deleteDuplicate(file)
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let file = pendingDelete {
                Text("\"\(file.name)\" will be moved to the Trash. The other identical copy will be kept.")
            }
        }
    }
}
