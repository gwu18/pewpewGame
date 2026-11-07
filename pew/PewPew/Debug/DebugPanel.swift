#if DEBUG
import GameCore
import QuartzCore
import SwiftUI

struct DebugPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(status)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            HStack(spacing: 6) {
                control("Start 30s", action: start)
                control(appModel.autoplay.enabled ? "Autoplay On" : "Autoplay", action: toggleAutoplay)
            }
            HStack(spacing: 6) {
                control("Hit", action: { hit(rho: 0.5) })
                control("Bullseye", action: { hit(rho: 0.1) })
                control("Miss", action: miss)
                control("Expire", action: expireAll)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var status: String {
        let hud = appModel.session.hud
        switch appModel.session.phase {
        case .lobby:
            return "Lobby"
        case .tutorial(let step):
            return "Tutorial \(step)"
        case .countdown:
            return "Countdown \(Int(hud.timeRemaining))s"
        case .playing:
            return "\(Int(hud.timeRemaining.rounded(.up)))s  \(hud.score)  ×\(hud.multiplier)"
        case .results(let result):
            return "Score \(result.score)  hits \(result.hits)  expired \(result.expired)"
        }
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 12, weight: .semibold))
            .controlSize(.small)
    }

    private func start() {
        appModel.autoplay.reset()
        appModel.session.config.length = 30
        appModel.session.start(now: CACurrentMediaTime())
    }

    private func toggleAutoplay() {
        appModel.autoplay.enabled.toggle()
    }

    private func hit(rho: Float) {
        guard let id = appModel.arena.nearestTargetID() else { return }
        appModel.session.registerHit(
            HitEvent(target: id, source: .debug, timestamp: CACurrentMediaTime(), normalizedRadius: rho)
        )
    }

    private func miss() {
        appModel.session.registerMissedShot(at: CACurrentMediaTime(), source: .debug)
    }

    private func expireAll() {
        appModel.session.forceExpireAll(now: CACurrentMediaTime())
    }
}
#endif
