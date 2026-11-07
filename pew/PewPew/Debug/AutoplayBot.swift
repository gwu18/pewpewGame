#if DEBUG
import Foundation
import GameCore
import Observation

@MainActor
@Observable
final class AutoplayBot {
    var enabled = false
    private var due: [TargetID: TimeInterval] = [:]
    private var decided: Set<TargetID> = []
    private var rng = SeededRandom(seed: 1)
    private var nextMissAt: TimeInterval?

    func reset() {
        due.removeAll()
        decided.removeAll()
        nextMissAt = nil
    }

    func update(now: TimeInterval, session: GameSession, arena: ArenaController) {
        guard enabled, case .playing = session.phase else { return }
        let live = Set(arena.snapshots().map(\.id))
        for id in live where due[id] == nil && !decided.contains(id) {
            due[id] = now + TimeInterval.random(in: 0.45...1.3, using: &rng)
        }
        for id in live {
            guard let time = due[id], time <= now else { continue }
            due[id] = nil
            decided.insert(id)
            guard Float.random(in: 0...1, using: &rng) < 0.75 else { continue }
            let rho = Float.random(in: 0...0.8, using: &rng)
            session.registerHit(HitEvent(target: id, source: .debug, timestamp: now, normalizedRadius: rho))
        }
        due = due.filter { live.contains($0.key) }
        decided.formIntersection(live)
        if nextMissAt == nil { nextMissAt = now + 1 }
        if let check = nextMissAt, now >= check {
            nextMissAt = now + 1
            if Float.random(in: 0...1, using: &rng) < 0.1 {
                session.registerMissedShot(at: now, source: .debug)
            }
        }
    }
}
#endif
