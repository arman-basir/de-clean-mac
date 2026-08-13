import SwiftUI

struct ProtectionView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                BackButton(selected: $selected)
                Spacer()
            }

            Image(systemName: engine.protectionChecks.isEmpty ? "shield" : "checkmark.shield.fill")
                .resizable().scaledToFit().frame(width: 72, height: 72)
                .foregroundColor(Theme.mint)

            Text(engine.protectionChecks.isEmpty ? "Your Mac hasn't been scanned yet" : "Security check complete")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("Checks Gatekeeper status, System Integrity Protection, and user Launch Agents. This is a built-in macOS diagnostic, not a full antivirus engine.")
                .font(.system(size: 13)).foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button {
                Task { await engine.runProtectionScan() }
            } label: {
                Text(engine.isProtectionScanning ? "Scanning..." : "Start Scan")
                    .font(.system(size: 13.5, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(Theme.mint)
                    .foregroundColor(Color(hex: "0A1210"))
                    .cornerRadius(10)
            }.buttonStyle(.plain).disabled(engine.isProtectionScanning)

            if !engine.protectionChecks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    row("Gatekeeper", engine.gatekeeperStatus)
                    row("SIP", engine.sipStatus)
                    Divider().background(Theme.line)
                    ForEach(engine.protectionChecks, id: \.self) { c in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark").foregroundColor(Theme.mint).font(.system(size: 11, weight: .bold))
                            Text(c).font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.muted)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 480)
                .background(Theme.panel2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            }
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.panel)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 12.5)).foregroundColor(Theme.muted)
            Spacer()
            Text(v).font(.system(size: 11.5, design: .monospaced)).lineLimit(1)
        }
    }
}
