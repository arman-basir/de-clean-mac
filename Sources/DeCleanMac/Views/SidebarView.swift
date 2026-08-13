import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var engine: ScannerEngine
    @Binding var selected: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                LogoMark()
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("De Clean Mac").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("SYSTEM CARE").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.mutedDim)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20)

            ForEach(AppTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: tab.icon).frame(width: 17)
                        Text(tab.title).font(.system(size: 13.5, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(selected == tab ? Theme.mint.opacity(0.14) : Color.clear)
                    .foregroundColor(selected == tab ? Theme.mint : Theme.muted)
                    .cornerRadius(9)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Free Space").font(.system(size: 11.5)).foregroundColor(Theme.muted)
                    Spacer()
                    Text(formatBytes(engine.diskFree)).font(.system(size: 11.5, weight: .semibold))
                }
                GeometryReader { geo in
                    let ratio = engine.diskTotal > 0 ? Double(engine.diskTotal - engine.diskFree) / Double(engine.diskTotal) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.35)).frame(height: 5)
                        Capsule().fill(LinearGradient(colors: [Theme.mint, Theme.violet], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * ratio, height: 5)
                    }
                }.frame(height: 5)
            }
            .padding(12)
            .background(Theme.panel2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        }
        .padding(14)
        .frame(width: 236)
        .background(Theme.panel)
    }
}
