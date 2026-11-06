import SwiftUI

struct LauncherView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var errorMessage: String?

    private let buttonRed = Color(red: 200 / 255, green: 50 / 255, blue: 30 / 255)

    var body: some View {
        VStack(spacing: 16) {
            Text("PewPew")
                .font(.system(size: 40, weight: .black, design: .rounded))

            Text("Hit the targets. Beat the clock.")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)

            Button("ENTER ARENA") {
                Task { await enterArena() }
            }
            .font(.system(size: 20, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .tint(buttonRed)
            .frame(maxWidth: .infinity, minHeight: 68)
            .disabled(appModel.arenaState == .opening)

            if let message = errorMessage ?? appModel.launchError {
                Text(message)
                    .font(.system(size: 17))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("Uses hand tracking. Best in a clear, well-lit space.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 520, height: 380)
    }

    private func enterArena() async {
        appModel.arenaState = .opening
        appModel.launchError = nil
        errorMessage = nil
        switch await openImmersiveSpace(id: "arena") {
        case .opened:
            appModel.arenaState = .open
            dismissWindow(id: "launcher")
        case .userCancelled, .error:
            appModel.arenaState = .closed
            errorMessage = "Couldn't open the arena. Try again."
        @unknown default:
            appModel.arenaState = .closed
            errorMessage = "Couldn't open the arena. Try again."
        }
    }
}
