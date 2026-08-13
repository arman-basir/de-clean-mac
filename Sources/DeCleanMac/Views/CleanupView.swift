import SwiftUI

struct CleanupView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var isScanningAll = false
    @State private var toast: String?
    @State private var showCleanConfirm = false

    var totalSelected: Int64 {
        engine.categories.filter { $0.selected }.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            BackButton(selected: $selected)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Clear Cache").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Scan and safely remove files you don't need").font(.system(size: 13)).foregroundColor(Theme.muted)
                }
                Spacer()
                Button {
                    let allSelected = engine.categories.allSatisfy { $0.selected }
                    for i in engine.categories.indices {
                        engine.categories[i].selected = !allSelected
                    }
                } label: {
                    Text(engine.categories.allSatisfy { $0.selected } ? "Deselect All" : "Select All")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.panel2)
                        .foregroundColor(Theme.text)
                        .cornerRadius(9)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                }.buttonStyle(.plain)
                Button {
                    Task { isScanningAll = true; await engine.scanAllCategories(); isScanningAll = false }
                } label: {
                    Text(isScanningAll ? "Scanning..." : "Scan All")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.panel2)
                        .foregroundColor(Theme.text)
                        .cornerRadius(9)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                }.buttonStyle(.plain).disabled(isScanningAll)
            }

            VStack(spacing: 10) {
                ForEach($engine.categories) { $cat in
                    Button {
                        cat.selected.toggle()
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(cat.selected ? Theme.mint : Color.clear)
                                .frame(width: 19, height: 19)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(cat.selected ? Theme.mint : Theme.mutedDim, lineWidth: 1.5))
                                .overlay(cat.selected ? AnyView(Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "0A1210"))) : AnyView(EmptyView()))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.name).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.text)
                                Text(cat.desc).font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
                            }
                            Spacer()
                            if cat.isScanning {
                                ProgressView().scaleEffect(0.6).frame(width: 60)
                            } else {
                                Text(formatBytes(cat.sizeBytes)).font(.system(size: 13.5, design: .monospaced)).foregroundColor(Theme.text)
                            }
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Theme.panel2)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }
            }

            HStack {
                Text("Selected total: ").font(.system(size: 13)).foregroundColor(Theme.muted)
                    + Text(formatBytes(totalSelected)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(Theme.mint)
                Spacer()
                Button {
                    showCleanConfirm = true
                } label: {
                    Text("Clean Now").font(.system(size: 13.5, weight: .semibold))
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(totalSelected > 0 ? Theme.mint : Theme.mutedDim)
                        .foregroundColor(Color(hex: "0A1210"))
                        .cornerRadius(10)
                }.buttonStyle(.plain).disabled(totalSelected == 0 || engine.isCleaning)
            }
            .padding(.top, 6)

            if let toast {
                Text(toast).font(.system(size: 12.5)).foregroundColor(Theme.mint)
            }

            Text("Items are moved to the Trash, not permanently deleted. Some folders may require Full Disk Access in System Settings > Privacy & Security.")
                .font(.system(size: 11)).foregroundColor(Theme.mutedDim)
        }
        .padding(24)
        }
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
        .confirmationDialog(
            "Clean \(formatBytes(totalSelected))?",
            isPresented: $showCleanConfirm,
            titleVisibility: .visible
        ) {
            Button("Clean Now", role: .destructive) {
                Task {
                    let result = await engine.cleanSelected()
                    if result.failedCount > 0 {
                        toast = "\(formatBytes(result.freed)) freed. \(result.failedCount) item(s) couldn't be removed — try enabling Full Disk Access in System Settings > Privacy & Security."
                    } else {
                        toast = "\(formatBytes(result.freed)) freed up successfully"
                    }
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    toast = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected items will be moved to the Trash. You can restore them from there before it's emptied.")
        }
    }
}
