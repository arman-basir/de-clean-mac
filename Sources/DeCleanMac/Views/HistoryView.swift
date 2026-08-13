import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var showClearConfirm = false

    var totalFreed: Int64 {
        engine.history.reduce(0) { $0 + $1.bytesFreed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton(selected: $selected)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("History").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("\(engine.history.count) actions · \(formatBytes(totalFreed)) freed in total")
                            .font(.system(size: 13)).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    if !engine.history.isEmpty {
                        Button {
                            showClearConfirm = true
                        } label: {
                            Text("Clear History")
                                .font(.system(size: 12.5, weight: .semibold))
                                .padding(.horizontal, 13).padding(.vertical, 7)
                                .background(Theme.panel2)
                                .foregroundColor(Theme.text)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }

                if engine.history.isEmpty {
                    Text("No actions yet. Anything you clean, uninstall, or delete will show up here.")
                        .font(.system(size: 13)).foregroundColor(Theme.mutedDim)
                }

                VStack(spacing: 8) {
                    ForEach(engine.history) { entry in
                        HStack(spacing: 12) {
                            ZStack {
                                iconColor(for: entry.action).opacity(0.14)
                                    .frame(width: 32, height: 32).cornerRadius(9)
                                Image(systemName: icon(for: entry.action))
                                    .font(.system(size: 13))
                                    .foregroundColor(iconColor(for: entry.action))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entry.action) · \(entry.detail)")
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11)).foregroundColor(Theme.mutedDim)
                            }
                            Spacer()
                            if entry.bytesFreed > 0 {
                                Text("−\(formatBytes(entry.bytesFreed))")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.mint)
                            }
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
        .confirmationDialog("Clear all history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { engine.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only clears the log — it does not undo anything or restore deleted files.")
        }
    }

    private func icon(for action: String) -> String {
        switch action {
        case "Cleaned": return "trash"
        case "Uninstalled": return "app.badge.checkmark"
        case "Deleted File": return "doc.badge.minus"
        case "Deleted Duplicate": return "doc.on.doc"
        case "Removed Login Item": return "power"
        default: return "checkmark.circle"
        }
    }

    private func iconColor(for action: String) -> Color {
        switch action {
        case "Cleaned": return Theme.mint
        case "Uninstalled": return Theme.danger
        case "Deleted File": return Theme.amber
        case "Deleted Duplicate": return Theme.violet
        default: return Theme.muted
        }
    }
}
