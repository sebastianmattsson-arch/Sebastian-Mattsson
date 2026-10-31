import SwiftUI

@main
struct PoangLoggApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(Theme.red)
        }
    }
}
