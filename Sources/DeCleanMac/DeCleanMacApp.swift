import SwiftUI

@main
struct DeCleanMacApp: App {
    @StateObject private var engine = ScannerEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 1040, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
