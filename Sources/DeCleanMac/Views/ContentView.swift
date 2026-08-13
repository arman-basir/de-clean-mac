import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: ScannerEngine
    @State private var selected: AppTab = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selected: $selected)
            Divider().background(Theme.line)
            Group {
                switch selected {
                case .dashboard: DashboardView(selected: $selected)
                case .cleanup: CleanupView(selected: $selected)
                case .protection: ProtectionView(selected: $selected)
                case .speed: SpeedView(selected: $selected)
                case .apps: AppsView(selected: $selected)
                case .files: FilesView(selected: $selected)
                case .duplicates: DuplicatesView(selected: $selected)
                case .history: HistoryView(selected: $selected)
                case .settings: SettingsView(selected: $selected)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(28)
            .background(Theme.bg)
        }
        .background(Theme.bg)
        .foregroundColor(Theme.text)
    }
}
