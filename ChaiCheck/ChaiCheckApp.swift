import SwiftUI

@main
struct ChaiCheckApp: App {
    @StateObject private var store = TeaStore()
    @StateObject private var brew = BrewEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(brew)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                brew.tick(at: .now)
                brew.syncStayAwake()
            }
        }
    }
}
