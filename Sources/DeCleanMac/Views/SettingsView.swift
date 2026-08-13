import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton(selected: $selected)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Changes apply the next time you scan, and are remembered between launches.")
                        .font(.system(size: 13)).foregroundColor(Theme.muted)
                }

                // ---- Large & Old Files threshold ----
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Large & Old Files").font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(engine.largeFileMinSizeMB) MB and up")
                            .font(.system(size: 12.5, design: .monospaced)).foregroundColor(Theme.mint)
                    }
                    Text("Only files at or above this size will show up as \"large files\".")
                        .font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
                    Slider(
                        value: Binding(
                            get: { Double(engine.largeFileMinSizeMB) },
                            set: { engine.largeFileMinSizeMB = Int($0) }
                        ),
                        in: 10...2000, step: 10
                    )
                    .tint(Theme.mint)
                    HStack {
                        Text("10 MB").font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.mutedDim)
                        Spacer()
                        Text("2 GB").font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.mutedDim)
                    }
                }
                .padding(16)
                .background(Theme.panel2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                // ---- Duplicate Finder threshold ----
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Duplicate Finder").font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text("up to \(engine.duplicateMaxSizeMB) MB")
                            .font(.system(size: 12.5, design: .monospaced)).foregroundColor(Theme.mint)
                    }
                    Text("Files larger than this are skipped entirely — the biggest factor in how fast (or slow) a duplicate scan feels. Lower it if scans feel heavy.")
                        .font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
                    Slider(
                        value: Binding(
                            get: { Double(engine.duplicateMaxSizeMB) },
                            set: { engine.duplicateMaxSizeMB = Int($0) }
                        ),
                        in: 1...200, step: 1
                    )
                    .tint(Theme.mint)
                    HStack {
                        Text("1 MB").font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.mutedDim)
                        Spacer()
                        Text("200 MB").font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.mutedDim)
                    }
                }
                .padding(16)
                .background(Theme.panel2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                // ---- Folders to scan ----
                VStack(alignment: .leading, spacing: 10) {
                    Text("Folders to Scan").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Used by both Large & Old Files and Duplicate Finder. Turn off folders you know are huge (e.g. Music) to speed things up.")
                        .font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)

                    VStack(spacing: 8) {
                        ForEach(ScannerEngine.scannableFolderNames, id: \.self) { name in
                            let isOn = engine.enabledScanFolderNames.contains(name)
                            Button {
                                if isOn {
                                    engine.enabledScanFolderNames.remove(name)
                                } else {
                                    engine.enabledScanFolderNames.insert(name)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: folderIcon(name)).foregroundColor(isOn ? Theme.mint : Theme.mutedDim).frame(width: 20)
                                    Text(name).font(.system(size: 13)).foregroundColor(Theme.text)
                                    Spacer()
                                    Capsule()
                                        .fill(isOn ? Theme.mint : Theme.panel)
                                        .frame(width: 38, height: 22)
                                        .overlay(Circle().fill(.white).frame(width: 16, height: 16).offset(x: isOn ? 8 : -8))
                                        .overlay(Capsule().stroke(Theme.line, lineWidth: isOn ? 0 : 1))
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

                // ---- Always skipped (informational) ----
                VStack(alignment: .leading, spacing: 8) {
                    Text("Always Skipped").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("These are skipped automatically in every scan, regardless of the settings above, because they're either not useful to flag or extremely expensive to walk into:")
                        .font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
                    VStack(alignment: .leading, spacing: 4) {
                        bulletRow("App bundles & packages (.app, .photoslibrary, etc.) — treated as one item, never opened")
                        bulletRow("Developer folders — node_modules, .git, .build, DerivedData, Pods, and similar")
                        bulletRow("Hidden files and folders (names starting with a dot)")
                    }
                }
                .padding(16)
                .background(Theme.panel2)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                Button {
                    showResetConfirm = true
                } label: {
                    Text("Reset to Defaults")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.panel2)
                        .foregroundColor(Theme.text)
                        .cornerRadius(9)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            .padding(24)
        }
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
        .confirmationDialog("Reset all settings to defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { engine.resetSettingsToDefaults() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundColor(Theme.mutedDim)
            Text(text).font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
        }
    }

    private func folderIcon(_ name: String) -> String {
        switch name {
        case "Downloads": return "arrow.down.circle"
        case "Documents": return "doc.text"
        case "Desktop": return "menubar.dock.rectangle"
        case "Movies": return "film"
        case "Music": return "music.note"
        case "Pictures": return "photo"
        default: return "folder"
        }
    }
}
