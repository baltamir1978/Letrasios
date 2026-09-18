import SwiftUI

@main
struct LetrasApp: App {
    @State private var listener = SongListener()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(listener)
        }
        // Opening the app is the whole interaction: it starts listening straight away.
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: listener.appBecameActive()
            case .background: listener.appEnteredBackground()
            default: break
            }
        }
    }
}
