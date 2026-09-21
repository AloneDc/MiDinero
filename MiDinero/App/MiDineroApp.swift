import SwiftUI

@main
@MainActor
struct MiDineroApp: App {
    @State private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.indigo)
        }
    }
}
