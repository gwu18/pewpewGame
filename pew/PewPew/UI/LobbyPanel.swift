import GameCore
import QuartzCore
import SwiftUI

/// The in-Arena start menu (visual spec §5.3 "Lobby").
struct LobbyPanel: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #if DEBUG
    @State private var showingHowTo = LaunchFlags.howToPlay
    #else
    @State private var showingHowTo = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingHowTo {
                HowToPlayCard { showingHowTo = false }
            } else {
                menu
            }
        }
        .padding(.horizontal, Theme.Space.panelH)
        .padding(.vertical, Theme.Space.panelV)
        .frame(width: Theme.Metrics.lobby.width)
        .glassBackgroundEffect(in: .rect(cornerRadius: Theme.Radius.panel))
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(logoSize: Theme.TypeSize.logo, iconSize: 52)
            Text("Hit the targets. Beat the clock.")
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Space.m)

            if !appModel.tracking.handTrackingAvailable {
                Label("Hand tracking is off, so you're using Look & Pinch: look at a target and pinch to hit it.", systemImage: "info.circle")
                    .font(Theme.Fonts.caption)
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.18), in: .rect(cornerRadius: Theme.Radius.tile))
                    .padding(.top, Theme.Space.xl)
            }

            VStack(alignment: .leading, spacing: 14) {
                row("Round") {
                    Picker("Round length", selection: lengthBinding) {
                        Text("30 s").tag(TimeInterval(30))
                        Text("60 s").tag(TimeInterval(60))
                    }
                }
                row("Space") {
                    Picker("Space", selection: spaceBinding) {
                        Text("Stay Put").tag(SpaceMode.stayPut)
                        Text("Roam Room").tag(SpaceMode.roam)
                    }
                }
                Text(appModel.session.config.space == .roam ? "Walk around — clear some space first" : "Stay in one spot")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Theme.Metrics.rowLabelWidth)
            }
            .padding(.top, Theme.Space.xxl)

            PixelDivider()
                .padding(.vertical, Theme.Space.xl)

            Button(action: start) {
                Text("START").frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryPixelButton()
            .accessibilityLabel("Start round")

            HStack {
                Button("How to Play") {
                    UISound.play(.tap)
                    showingHowTo = true
                }
                .secondaryButton()
                Spacer()
                #if DEBUG
                Button(appModel.showDebug ? "Hide Debug" : "Debug") {
                    UISound.play(appModel.showDebug ? .toggleOff : .toggleOn)
                    appModel.showDebug.toggle()
                }
                .font(Theme.Fonts.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .frame(minHeight: Theme.Metrics.secondaryButtonHeight)
                Spacer()
                #endif
                Button("Exit Arena") {
                    UISound.play(.back)
                    Task { await dismissImmersiveSpace() }
                }
                .font(Theme.Fonts.row)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .frame(minHeight: Theme.Metrics.secondaryButtonHeight)
                .accessibilityLabel("Exit arena")
            }
            .padding(.top, Theme.Space.l)
        }
    }

    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(Theme.Fonts.row)
                .frame(width: Theme.Metrics.rowLabelWidth, alignment: .leading)
            control()
                .pickerStyle(.segmented)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    private var lengthBinding: Binding<TimeInterval> {
        Binding(
            get: { appModel.session.config.length },
            set: {
                UISound.play(.tap)
                appModel.session.config.length = $0
            }
        )
    }

    private var spaceBinding: Binding<SpaceMode> {
        Binding(
            get: { appModel.session.config.space },
            set: {
                UISound.play($0 == .roam ? .toggleOn : .toggleOff)
                appModel.session.config.space = $0
            }
        )
    }

    private func start() {
        UISound.play(.tap)
        #if DEBUG
        appModel.autoplay.reset()
        #endif
        appModel.session.start(now: CACurrentMediaTime())
    }
}

/// Static "How to Play" card until the M8 tutorial lands (build plan §7).
private struct HowToPlayCard: View {
    var onBack: () -> Void

    private let steps: [(String, String)] = [
        ("hand.point.up.left.fill", "Targets pop up in front of you. Poke one with a fingertip to hit it."),
        ("scope", "Aim for the middle. Red scores more, the gold bullseye scores most."),
        ("bolt.fill", "Hit targets back to back to build a combo. Misses and timeouts reset it."),
        ("eye", "No hand tracking? Look at a target and pinch."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.l) {
                FaceIcon(size: 40)
                Text("HOW TO PLAY")
                    .font(Theme.Fonts.pixel(Theme.TypeSize.header))
                    .foregroundStyle(Theme.Palette.paper.color)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        Image(systemName: steps[index].0)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 32)
                        Text(steps[index].1)
                            .font(Theme.Fonts.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, Theme.Space.xxl)

            PixelDivider()
                .padding(.vertical, Theme.Space.xl)

            Button {
                UISound.play(.back)
                onBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .secondaryButton()
        }
    }
}
