import SwiftUI

struct LauncherView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Wordmark(logoSize: Theme.TypeSize.launcherLogo, iconSize: 56)
                .padding(.top, Theme.Space.s)

            Text("Hit the targets. Beat the clock.")
                .font(Theme.Fonts.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Space.l)

            Spacer(minLength: Theme.Space.xl)

            Button {
                UISound.play(.tap)
                Task { await enterArena() }
            } label: {
                Text(appModel.arenaState == .opening ? "OPENING" : "ENTER ARENA")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryPixelButton()
            .disabled(appModel.arenaState == .opening)
            .accessibilityLabel("Enter arena")

            Group {
                if let message = errorMessage ?? appModel.launchError {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Label("Uses hand tracking. Best in a clear, well-lit space.", systemImage: "hand.raised.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .font(Theme.Fonts.caption)
            .multilineTextAlignment(.center)
            .padding(.top, Theme.Space.l)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.xxl)
        .frame(width: Theme.Metrics.launcher.width, height: Theme.Metrics.launcher.height)
        .onAppear { UISound.preload() }
        #if DEBUG
        .task {
            if LaunchFlags.enterArena, appModel.arenaState == .closed { await enterArena() }
        }
        #endif
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
