import GameCore
import QuartzCore
import SwiftUI

/// End-of-round panel (visual spec §5.3 "Results"); tally animation is M7b.
struct ResultsPanel: View {
    @Environment(AppModel.self) private var appModel
    var result: RoundResult

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.m) {
                FaceIcon(size: 30)
                Text("ROUND OVER")
                    .font(Theme.Fonts.pixel(Theme.TypeSize.header))
                    .foregroundStyle(Theme.Palette.paper.color)
            }

            Text("SCORE")
                .font(Theme.Fonts.hudLabel)
                .tracking(2)
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Space.xl)
            Text(result.score.formatted())
                .font(Theme.Fonts.pixel(Theme.TypeSize.resultsScore))
                .foregroundStyle(Theme.Palette.bullseyeGold.color)
                .pixelShadow(Theme.Shadow.hero)
                .padding(.top, Theme.Space.s)

            Text("\(Int(result.config.length)) s · \(result.config.space == .roam ? "Roam Room" : "Stay Put")")
                .font(Theme.Fonts.caption.weight(.semibold))
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, Theme.Space.xs)
                .background(.white.opacity(0.12), in: .capsule)
                .padding(.top, Theme.Space.l)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.m), count: 3), spacing: Theme.Space.m) {
                stat("Hits", "\(result.hits) / \(max(result.targetsResolved, result.hits))")
                stat("Accuracy", result.accuracy.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                stat("Avg reaction", milliseconds(result.avgReaction))
                stat("Fastest", milliseconds(result.fastest))
                stat("Best streak", "\(result.bestStreak)")
                stat("Bullseyes", "\(result.bullseyes)", gold: true)
            }
            .padding(.top, Theme.Space.xl)

            HStack(spacing: Theme.Space.l) {
                Button {
                    UISound.play(.tap)
                    #if DEBUG
                    appModel.autoplay.reset()
                    #endif
                    appModel.session.start(now: CACurrentMediaTime())
                } label: {
                    Text("PLAY AGAIN").frame(maxWidth: .infinity, minHeight: 44)
                }
                .primaryPixelButton()
                .layoutPriority(1.4)
                .accessibilityLabel("Play again")

                Button {
                    UISound.play(.back)
                    appModel.session.returnToLobby()
                } label: {
                    Text("Menu").frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryButton()
                .frame(width: 170)
                .accessibilityLabel("Return to menu")
            }
            .padding(.top, Theme.Space.xl)
        }
        .padding(.horizontal, Theme.Space.panelH)
        .padding(.vertical, Theme.Space.panelV)
        .frame(width: Theme.Metrics.results.width)
        .glassBackgroundEffect(in: .rect(cornerRadius: Theme.Radius.panel))
    }

    private func stat(_ label: String, _ value: String, gold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Fonts.number(Theme.TypeSize.stat))
                .foregroundStyle(gold ? Theme.Palette.bullseyeGold.color : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, Theme.Space.l)
        .background(.black.opacity(0.2), in: .rect(cornerRadius: Theme.Radius.tile))
    }

    private func milliseconds(_ value: TimeInterval?) -> String {
        value.map { "\(Int(($0 * 1000).rounded())) ms" } ?? "—"
    }
}
