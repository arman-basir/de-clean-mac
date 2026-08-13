import SwiftUI

struct FilesView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var isScanning = false
    @State private var pendingDelete: LargeFile?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            BackButton(selected: $selected)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Large & Old Files").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Scans folders enabled in Settings for files over \(engine.largeFileMinSizeMB) MB").font(.system(size: 13)).foregroundColor(Theme.muted)
                }
                Spacer()
                Button {
                    Task { isScanning = true; await engine.scanLargeFiles(); isScanning = false }
                } label: {
                    Text(isScanning ? "Scanning..." : "Rescan")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.panel2)
                        .foregroundColor(Theme.text)
                        .cornerRadius(9)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                }.buttonStyle(.plain).disabled(isScanning)
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

            if engine.largeFiles.isEmpty && !isScanning {
                Text("No large files found, or not scanned yet.")
                    .font(.system(size: 13)).foregroundColor(Theme.mutedDim)
            }

            VStack(spacing: 8) {
                ForEach(engine.largeFiles) { file in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill").foregroundColor(Theme.mint)
                            .frame(width: 34, height: 34)
                            .background(Theme.mint.opacity(0.14)).cornerRadius(9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(file.path.deletingLastPathComponent().path).font(.system(size: 10.5)).foregroundColor(Theme.mutedDim).lineLimit(1)
                        }
                        Spacer()
                        Text(formatBytes(file.sizeBytes)).font(.system(size: 12.5, design: .monospaced)).foregroundColor(Theme.muted)
                        Button {
                            pendingDelete = file
                        } label: {
                            Text("Delete").font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 13).padding(.vertical, 7)
                                .background(Theme.panel2)
                                .foregroundColor(Theme.text)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.panel2)
                    .cornerRadius(12)
                }
            }
        }
        .padding(24)
        }
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
        .onAppear {
            if engine.largeFiles.isEmpty {
                Task { isScanning = true; await engine.scanLargeFiles(); isScanning = false }
            }
        }
        .confirmationDialog(
            "Delete this file?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let file = pendingDelete {
                    do {
                        try engine.deleteLargeFile(file)
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
                Text("\"\(file.name)\" (\(formatBytes(file.sizeBytes))) will be moved to the Trash.")
            }
        }
    }
}
