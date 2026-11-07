import Foundation

/// Decides when the next target appears and what kind it is. One director per round.
public struct SpawnDirector: Sendable {
    public static let allowMoving = false // M5

    private var due: [TimeInterval]
    private var nextRaw: Int
    private let roundStart: TimeInterval
    private let roundEnd: TimeInterval
    private let config: RoundConfig
    private let tuning: Tuning

    public init(
        config: RoundConfig,
        tuning: Tuning = .default,
        roundStart: TimeInterval,
        roundEnd: TimeInterval,
        nextID: Int = 1,
        rng: inout SeededRandom
    ) {
        self.config = config
        self.tuning = tuning
        self.roundStart = roundStart
        self.roundEnd = roundEnd
        self.nextRaw = nextID
        let slots = tuning.spawn.maxConcurrent.value(config.difficulty)
        let window = tuning.spawn.firstDelay
        due = (0..<slots).map { _ in
            roundStart + TimeInterval.random(in: window.lower...window.upper, using: &rng)
        }
    }

    /// Targets that should appear now. `liveCount` includes targets already in the arena.
    public mutating func nextRequests(now: TimeInterval, liveCount: Int, rng: inout SeededRandom) -> [SpawnRequest] {
        guard roundEnd - now >= tuning.spawn.noSpawnTail else { return [] }
        let cap = tuning.spawn.maxConcurrent.value(config.difficulty)
        var requests: [SpawnRequest] = []
        var waiting: [TimeInterval] = []
        for time in due {
            if time <= now, liveCount + requests.count < cap {
                requests.append(makeRequest(now: now, rng: &rng))
            } else {
                waiting.append(time)
            }
        }
        due = waiting
        return requests
    }

    /// A slot freed by a hit or an expiry. The replacement waits out a difficulty delay.
    public mutating func targetResolved(at time: TimeInterval, rng: inout SeededRandom) {
        let window = tuning.spawn.delay.value(config.difficulty)
        due.append(time + TimeInterval.random(in: window.lower...window.upper, using: &rng))
    }

    /// The arena could not place this slot. Try again at `time`.
    public mutating func deferSpawn(until time: TimeInterval) {
        due.append(time)
    }

    private mutating func makeRequest(now: TimeInterval, rng: inout SeededRandom) -> SpawnRequest {
        let type = pickType(now: now, rng: &rng)
        let id = TargetID(raw: nextRaw)
        nextRaw += 1
        return SpawnRequest(
            id: id,
            type: type,
            diameter: diameter(for: type),
            lifetime: lifetime(for: type),
            motion: motion(for: type),
            config: config
        )
    }

    private func pickType(now: TimeInterval, rng: inout SeededRandom) -> TargetType {
        if now < roundStart + tuning.spawn.warmup { return .normal }
        var weights = tuning.spawn.weights.value(config.difficulty)
        if !Self.allowMoving { weights.moving = 0 }
        let total = weights.normal + weights.small + weights.moving
        guard total > 0 else { return .normal }
        var roll = Int.random(in: 0..<total, using: &rng)
        if roll < weights.normal { return .normal }
        roll -= weights.normal
        return roll < weights.small ? .small : .moving
    }

    private func lifetime(for type: TargetType) -> TimeInterval {
        var life = tuning.targets.lifetimeBlaster.value(type)
        if config.controls == .touch { life += tuning.targets.touchLifetimeExtra }
        if config.space == .roam { life *= tuning.targets.roamLifetimeMultiplier }
        return life * tuning.targets.lifetimeMultiplier.value(config.difficulty)
    }

    private func diameter(for type: TargetType) -> Float {
        let table = config.controls == .blaster ? tuning.targets.diameterBlaster : tuning.targets.diameterTouch
        var size = table.value(type) * tuning.targets.sizeMultiplier.value(config.difficulty)
        if config.bigTargets { size *= tuning.targets.bigTargetsMultiplier }
        return size
    }

    private func motion(for type: TargetType) -> Motion {
        guard type == .moving else { return .none }
        return config.controls == .blaster
            ? .strafe(amplitude: tuning.targets.strafeBlasterAmplitude, period: tuning.targets.strafeBlasterPeriod)
            : .strafe(amplitude: tuning.targets.strafeTouchAmplitude, period: tuning.targets.strafeTouchPeriod)
    }
}
