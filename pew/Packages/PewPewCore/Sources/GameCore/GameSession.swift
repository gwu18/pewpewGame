import Foundation
import Observation
import os

struct LiveTarget {
    var type: TargetType
    var spawnTime: TimeInterval
    var expiresAt: TimeInterval
}

@MainActor
@Observable
public final class GameSession {
    public private(set) var phase: GamePhase
    public var config = RoundConfig()
    public weak var arena: ArenaRendering?

    public let tuning: Tuning
    private var live: [TargetID: LiveTarget] = [:]
    private var nextID = 1
    // M1-TEMP: first tick may spawn immediately.
    private var nextSpawnAt: TimeInterval = 0
    private var rng: SeededRandom

    public init(tuning: Tuning = .default, seed: UInt64 = .random(in: 0 ... UInt64.max)) {
        self.tuning = tuning
        self.rng = SeededRandom(seed: seed)
        // M1-TEMP
        self.phase = .playing(endsAt: .infinity)
    }

    /// Clears the live round so the next arena visit starts from the acceptance pose.
    public func reset() {
        live.removeAll()
        nextID = 1
        nextSpawnAt = 0
        phase = .playing(endsAt: .infinity)
    }

    public func tick(now: TimeInterval) {
        guard case .playing = phase else { return }
        guard live.isEmpty, now >= nextSpawnAt else { return }
        let id = TargetID(raw: nextID)
        let request = SpawnRequest(
            id: id,
            type: .normal,
            diameter: tuning.targets.diameterTouch.normal,
            lifetime: .infinity, // M1-TEMP
            motion: .none,
            config: config
        )
        guard arena?.spawnTarget(request, at: now) == true else { return }
        nextID += 1
        live[id] = LiveTarget(type: .normal, spawnTime: now, expiresAt: .infinity)
    }

    @discardableResult
    public func registerHit(_ hit: HitEvent) -> HitOutcome? {
        // M1-TEMP: the only phase is .playing. M2 rejects every other phase here.
        guard case .playing = phase else { return nil }
        guard let target = live[hit.target] else { return nil }
        guard hit.timestamp <= target.expiresAt else { return nil }
        live[hit.target] = nil
        let ring = ring(for: hit.normalizedRadius)
        // M1-TEMP: flat score. The real formula lands in M2.
        let outcome = HitOutcome(
            points: 100,
            ring: ring,
            reactionTime: hit.timestamp - target.spawnTime,
            multiplier: 1,
            streak: 1
        )
        arena?.removeTarget(hit.target, reason: .hit(outcome))
        nextSpawnAt = hit.timestamp + 1 // M1-TEMP
        print("PewPew +\(outcome.points)")
        Logger(subsystem: "com.garywu.pewpew", category: "score").info("PewPew +\(outcome.points, privacy: .public)")
        return outcome
    }

    public func nextFloat(in range: ClosedRange<Float>) -> Float {
        Float.random(in: range, using: &rng)
    }

    private func ring(for rho: Float) -> Ring {
        if rho <= tuning.score.goldRadius { return .gold }
        if rho <= tuning.score.redRadius { return .red }
        return .none
    }
}
