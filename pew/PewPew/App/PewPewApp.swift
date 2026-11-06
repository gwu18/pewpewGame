import SwiftUI

@main
struct PewPewApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: "launcher") {
            LauncherView()
                .environment(model)
        }
        .defaultSize(width: 520, height: 380)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "arena") {
            ArenaView()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
