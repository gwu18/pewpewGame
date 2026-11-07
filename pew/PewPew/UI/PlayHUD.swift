import GameCore
import QuartzCore
import SwiftUI

/// "3 · 2 · 1 · GO!" on a glass disc (visual spec §5.3 "Countdown").
struct CountdownView: View {
    @Environment(AppModel.self) private var appModel
    var endsAt: TimeInterval

    var body: some View {
        TimelineView(.animation) { _ in
            let label = currentLabel(now: CACurrentMediaTime())
            Group {
                if label == "GO!" {
                    Text(label)
                        .font(Theme.Fonts.pixel(Theme.TypeSize.countdown * 0.6))
                        .frame(width: Theme.Metrics.goCapsule.width, height: Theme.Metrics.goCapsule.height)
                        .glassBackgroundEffect(in: .capsule)
                } else {
                    Text(label)
                        .font(Theme.Fonts.pixel(Theme.TypeSize.countdown))
                        .frame(width: Theme.Metrics.countdownDisc, height: Theme.Metrics.countdownDisc)
                        .glassBackgroundEffect(in: .circle)
                }
            }
            .foregroundStyle(Theme.Palette.bullseyeGold.color)
            .pixelShadow(Theme.Shadow.countdown)
        }
        .allowsHitTesting(false)
    }

    private func currentLabel(now: TimeInterval) -> String {
        let round = appModel.session.tuning.round
        let total = round.countdownStep * 3 + round.goDuration
        let elapsed = total - (endsAt - now)
        switch Int(max(elapsed, 0) / round.countdownStep) {
        case 0: return "3"
        case 1: return "2"
        case 2: return "1"
        default: return "GO!"
        }
    }
}

/// In-round time and score (visual spec §5.3 "HUD"). Never hit-testable.
struct PlayHUD: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let hud = appModel.session.hud
        let seconds = Int(hud.timeRemaining.rounded(.up))
        HStack(spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("TIME")
                    .font(Theme.Fonts.hudLabel)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(String(format: "%02d", seconds))
                    .font(Theme.Fonts.pixel(Theme.TypeSize.hudTime))
                    .foregroundStyle(seconds <= 5 ? Theme.Palette.bullseyeGold.color : Theme.Palette.paper.color)
            }
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 2, height: 80)
            VStack(alignment: .trailing, spacing: Theme.Space.s) {
                HStack {
                    Text("SCORE")
                        .font(Theme.Fonts.hudLabel)
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if hud.multiplier > 1 {
                        comboChip(hud.multiplier)
                    }
                }
                Text(hud.score.formatted())
                    .font(Theme.Fonts.pixel(Theme.TypeSize.hudScore))
                    .foregroundStyle(Theme.Palette.paper.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 30)
        .frame(width: Theme.Metrics.hud.width, height: Theme.Metrics.hud.height)
        .glassBackgroundEffect(in: .rect(cornerRadius: Theme.Radius.hud))
        .allowsHitTesting(false)
    }

    private func comboChip(_ multiplier: Double) -> some View {
        let gold = multiplier >= 2
        let text = multiplier == multiplier.rounded() ? "×\(Int(multiplier))" : String(format: "×%.1f", multiplier)
        return Text(text)
            .font(Theme.Fonts.pixel(Theme.TypeSize.chip))
            .foregroundStyle(Theme.Palette.ink.color)
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, Theme.Space.xs)
            .background(gold ? Theme.Palette.bullseyeGold.color : Theme.Palette.paper.color, in: .rect(cornerRadius: Theme.Radius.chip))
    }
}
