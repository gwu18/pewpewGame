import Foundation
import GameCore
import GestureCore
import simd

@MainActor
final class InputCoordinator {
    private let session: GameSession
    private let arena: ArenaController
    private let tracking: TrackingService
    private let touch = Tuning.default.touch
    private var previousTip: [Chirality: SIMD3<Float>] = [:]
    private var lastHit: [Chirality: TimeInterval] = [:]

    init(session: GameSession, arena: ArenaController, tracking: TrackingService) {
        self.session = session
        self.arena = arena
        self.tracking = tracking
    }

    func update(now: TimeInterval) {
        for frame in [tracking.latestLeft, tracking.latestRight].compactMap({ $0 }) {
            guard let tip = frame.joints[.indexTip] else { continue }
            let previous = previousTip[frame.chirality] ?? tip
            previousTip[frame.chirality] = tip
            if let last = lastHit[frame.chirality], now - last < touch.cooldown { continue }
            guard let result = HitMath.resolveTouch(
                prevTip: previous,
                tip: tip,
                targets: arena.snapshots(),
                forgiveness: touch.forgiveness
            ) else { continue }
            lastHit[frame.chirality] = now
            session.registerHit(
                HitEvent(
                    target: result.id,
                    source: .touch,
                    timestamp: now,
                    normalizedRadius: result.normalizedRadius
                )
            )
        }
    }
}
