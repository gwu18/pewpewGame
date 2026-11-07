#if DEBUG
import GameCore
import QuartzCore
import SwiftUI

/// Simulator/test tools. Debug builds only, and hidden until the lobby's "Debug" button is used.
struct DebugPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DEBUG")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                control("Hide") { appModel.showDebug = false }
            }
            Text(status)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            HStack(spacing: 6) {
                control(appModel.autoplay.enabled ? "Autoplay: on" : "Autoplay: off", action: toggleAutoplay)
                control("Expire all", action: expireAll)
            }
            HStack(spacing: 6) {
                control("Hit outer", action: { hit(rho: 0.5) })
                control("Hit bullseye", action: { hit(rho: 0.1) })
                control("Miss shot", action: miss)
            }
        }
        .padding(12)
        .frame(width: 340)
        .glassBackgroundEffect(in: .rect(cornerRadius: 20))
    }

    private var status: String {
        let hud = appModel.session.hud
        switch appModel.session.phase {
        case .lobby:
            return "Lobby"
        case .tutorial(let step):
            return "Tutorial \(step)"
        case .countdown:
            return "Countdown"
        case .playing:
            return "\(Int(hud.timeRemaining.rounded(.up)))s  \(hud.score)  ×\(hud.multiplier)"
        case .results(let result):
            return "Score \(result.score)  hits \(result.hits)  expired \(result.expired)"
        }
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .semibold))
            .controlSize(.small)
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
