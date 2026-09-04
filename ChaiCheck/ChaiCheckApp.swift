import SwiftUI

@main
struct ChaiCheckApp: App {
    @StateObject private var engine = SteepEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.tick(at: .now)
            }
        }
    }
}
