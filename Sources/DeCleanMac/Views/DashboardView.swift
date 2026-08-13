import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab
    @State private var isScanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome back").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Here's how your MacBook is doing today").font(.system(size: 13)).foregroundColor(Theme.muted)
                }

                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SMART CARE").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.mint)
                        Text("Your system could use some attention.")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Run a Smart Scan to check real cache, logs, and junk files on your Mac.")
                            .font(.system(size: 13)).foregroundColor(Theme.muted)
                        Button {
                            runSmartScan()
                        } label: {
                            Text(isScanning ? "Scanning..." : "Run Smart Scan")
                                .font(.system(size: 13.5, weight: .semibold))
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Theme.mint)
                                .foregroundColor(Color(hex: "0A1210"))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isScanning)
                    }
                    Spacer()
                    GaugeView(score: engine.healthScore)
                        .frame(width: 160, height: 160)
                }
                .padding(28)
                .background(Theme.panel)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1))

                // ---- Featured actions: the two most important features ----
                Text("Most Used").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.mutedDim)
                HStack(spacing: 16) {
                    featuredAction(
                        title: "Clear Cache",
                        subtitle: "Scan and remove real system junk, logs, browser cache & trash",
                        icon: "trash.fill",
                        color: Theme.mint,
                        tab: .cleanup
                    )
                    featuredAction(
                        title: "Uninstall Apps",
                        subtitle: "Remove unwanted apps from /Applications, moved safely to Trash",
                        icon: "app.badge.checkmark",
                        color: Theme.violet,
                        tab: .apps
                    )
                }

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Storage Usage").font(.system(size: 15, weight: .bold, design: .rounded))
                        StorageBar(slices: engine.diskSlices, total: engine.diskTotal, free: engine.diskFree)
                        ForEach(engine.diskSlices) { slice in
                            HStack {
                                Circle().fill(Color(hex: slice.color)).frame(width: 9, height: 9)
                                Text(slice.label).font(.system(size: 12.5)).foregroundColor(Theme.muted)
                                Spacer()
                                Text(formatBytes(slice.bytes)).font(.system(size: 12, design: .monospaced))
                            }
                        }
                        HStack {
                            Circle().fill(Theme.line).frame(width: 9, height: 9)
                            Text("Free Space").font(.system(size: 12.5)).foregroundColor(Theme.muted)
                            Spacer()
                            Text(formatBytes(engine.diskFree)).font(.system(size: 12, design: .monospaced))
                        }
                    }
                    .padding(22)
                    .background(Theme.panel)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 13) {
                        Text("System Info").font(.system(size: 15, weight: .bold, design: .rounded))
                        infoRow("Total Disk", formatBytes(engine.diskTotal))
                        infoRow("Last Scan", engine.lastScanText)
                        infoRow("macOS", ProcessInfo.processInfo.operatingSystemVersionString)
                        infoRow("Host Name", ProcessInfo.processInfo.hostName)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
                }

                Text("More Tools").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.mutedDim)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    quickAction("Protection", "shield", Theme.amber, "Check Gatekeeper & SIP status", .protection)
                    quickAction("Speed & Memory", "gauge.with.dots.needle.67percent", Theme.amber, "Login items, memory, agents", .speed)
                    quickAction("Large & Old Files", "doc.text.magnifyingglass", Theme.danger, "Find files taking up space", .files)
                    quickAction("Duplicate Finder", "doc.on.doc", Theme.violet, "Find identical files", .duplicates)
                    quickAction("History", "clock.arrow.circlepath", Theme.mint, "See what's been cleaned", .history)
                    quickAction("Settings", "gearshape.fill", Theme.muted, "Adjust scan thresholds & folders", .settings)
                }
            }
        }
        .onAppear { engine.refreshDiskUsage() }
    }

    private func runSmartScan() {
        isScanning = true
        Task {
            await engine.scanAllCategories()
            isScanning = false
            selected = .cleanup
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundColor(Theme.muted)
            Spacer()
            Text(v).font(.system(size: 12.5, design: .monospaced))
        }
    }

    private func featuredAction(title: String, subtitle: String, icon: String, color: Color, tab: AppTab) -> some View {
        Button {
            selected = tab
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    color.opacity(0.16).frame(width: 50, height: 50).cornerRadius(13)
                    Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                    Text(subtitle).font(.system(size: 11.5)).foregroundColor(Theme.mutedDim).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.mutedDim).font(.system(size: 12, weight: .bold))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.4), lineWidth: 1.3))
        }
        .buttonStyle(.plain)
    }

    private func quickAction(_ title: String, _ icon: String, _ color: Color, _ desc: String, _ tab: AppTab) -> some View {
        Button {
            selected = tab
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    color.opacity(0.14).frame(width: 34, height: 34).cornerRadius(9)
                    Image(systemName: icon).foregroundColor(color)
                }
                Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.text)
                Text(desc).font(.system(size: 11.5)).foregroundColor(Theme.mutedDim)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct GaugeView: View {
    let score: Int
    var body: some View {
        ZStack {
            Circle().stroke(Color.black.opacity(0.35), lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(AngularGradient(colors: [Theme.mint, Theme.violet], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: score)
            VStack(spacing: 2) {
                Text("\(score)").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Health Score").font(.system(size: 10.5)).foregroundColor(Theme.muted)
            }
        }
    }
}

struct StorageBar: View {
    let slices: [DiskSlice]
    let total: Int64
    let free: Int64
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(slices) { s in
                    Rectangle().fill(Color(hex: s.color))
                        .frame(width: total > 0 ? geo.size.width * CGFloat(s.bytes) / CGFloat(total) : 0)
                }
                Rectangle().fill(Theme.line)
            }
            .cornerRadius(10)
        }
        .frame(height: 20)
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}
