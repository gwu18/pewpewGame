import Foundation
import Observation

struct LiveTarget {
    var type: TargetType
    var spawnTime: TimeInterval
    var expiresAt: TimeInterval
}

@MainActor
@Observable
public final class GameSession {
    public private(set) var phase: GamePhase = .lobby
    public private(set) var hud = HUDState()
    public var config = RoundConfig()
    public weak var arena: ArenaRendering?
    public var onEvent: ((GameEvent) -> Void)?
    /// Illegal calls assert in debug when this is true. Tests leave it off.
    public var strict = false

    public let tuning: Tuning
    private var roundConfig = RoundConfig()
    private var live: [TargetID: LiveTarget] = [:]
    private var director: SpawnDirector?
    private var stats = RoundStats()
    private var streak = 0
    private var appliedMultiplier = 1.0
    private var announcedCountdown = 0
    private var announcedGo = false
    private var finalMark = 10
    private var rng: SeededRandom

    public init(tuning: Tuning = .default, seed: UInt64 = .random(in: 0...UInt64.max)) {
        self.tuning = tuning
        self.rng = SeededRandom(seed: seed)
    }

    /// Drops the round without a result. Used when the arena closes.
    public func reset() {
        returnToLobby()
    }

    public func start(now: TimeInterval) {
        switch phase {
        case .lobby, .results: beginCountdown(at: now)
        default: reject("start")
        }
    }

    public func startTutorial(now: TimeInterval) {
        _ = now
        guard phase == .lobby else { reject("startTutorial"); return }
        phase = .tutorial(.touch)
        emit(.tutorialAdvanced(.touch))
    }

    public func tutorialPoseDetected() {
        guard case .tutorial(let step) = phase else { reject("tutorialPoseDetected"); return }
        let next: TutorialStep
        switch step {
        case .touch: next = .gunPose
        case .gunPose: next = .gunFire
        case .gunFire: next = .done
        case .done: reject("tutorialPoseDetected"); return
        }
        phase = .tutorial(next)
        emit(.tutorialAdvanced(next))
    }

    public func skipTutorial(now: TimeInterval) {
        guard case .tutorial = phase else { reject("skipTutorial"); return }
        beginCountdown(at: now)
    }

    public func returnToLobby() {
        clearRound()
        arena?.removeAllTargets()
        phase = .lobby
    }

    public func tick(now: TimeInterval) {
        switch phase {
        case .countdown(let endsAt):
            updateCountdown(now: now, endsAt: endsAt)
            if case .playing(let playEnd) = phase {
                updatePlaying(now: now, endsAt: playEnd)
            }
        case .playing(let endsAt):
            updatePlaying(now: now, endsAt: endsAt)
        default:
            break
        }
    }

    @discardableResult
    public func registerHit(_ hit: HitEvent) -> HitOutcome? {
        guard isScoring else { reject("registerHit"); return nil }
        guard let target = live[hit.target], hit.timestamp <= target.expiresAt else { return nil }
        live[hit.target] = nil
        let outcome = ScoreCalculator.outcome(
            type: target.type,
            rho: hit.normalizedRadius,
            reactionTime: hit.timestamp - target.spawnTime,
            streakBefore: streak,
            tuning: tuning
        )
        streak = outcome.streak
        stats.recordHit(outcome, source: hit.source)
        hud.score = stats.score
        noteMultiplier(outcome.multiplier)
        arena?.removeTarget(hit.target, reason: .hit(outcome))
        resolveSlot(at: hit.timestamp)
        emit(.targetHit(outcome, hit.target))
        return outcome
    }

    public func registerMissedShot(at time: TimeInterval, source: InputSource) {
        _ = (time, source)
        guard case .playing = phase else { reject("registerMissedShot"); return }
        stats.recordMiss()
        breakStreak()
        emit(.missedShot)
    }

    /// Expires every live target immediately. Debug panel only.
    public func forceExpireAll(now: TimeInterval) {
        guard case .playing = phase else { reject("forceExpireAll"); return }
        for id in Array(live.keys) {
            expire(id, at: now)
        }
    }

    public func nextFloat(in range: ClosedRange<Float>) -> Float {
        Float.random(in: range, using: &rng)
    }

    private var isScoring: Bool {
        switch phase {
        case .playing, .tutorial: true
        default: false
        }
    }

    private var countdownLength: TimeInterval {
        tuning.round.countdownStep * 3 + tuning.round.goDuration
    }

    private func beginCountdown(at now: TimeInterval) {
        clearRound()
        roundConfig = config
        hud.timeRemaining = config.length
        phase = .countdown(endsAt: now + countdownLength)
    }

    private func clearRound() {
        live.removeAll()
        director = nil
        stats = RoundStats()
        streak = 0
        appliedMultiplier = 1
        hud = HUDState()
        announcedCountdown = 0
        announcedGo = false
        finalMark = 10
    }

    private func updateCountdown(now: TimeInterval, endsAt: TimeInterval) {
        let step = tuning.round.countdownStep
        let elapsed = now - (endsAt - countdownLength)
        let marks = [3, 2, 1]
        for index in marks.indices where elapsed >= step * Double(index) && announcedCountdown <= index {
            announcedCountdown = index + 1
            emit(.countdownTick(marks[index]))
        }
        if elapsed >= step * 3, !announcedGo {
            announcedGo = true
            emit(.go)
        }
        if now >= endsAt {
            beginPlaying(at: endsAt)
        }
    }

    private func beginPlaying(at start: TimeInterval) {
        let end = start + roundConfig.length
        finalMark = 10
        hud.timeRemaining = roundConfig.length
        director = SpawnDirector(config: roundConfig, tuning: tuning, roundStart: start, roundEnd: end, rng: &rng)
        phase = .playing(endsAt: end)
    }

    private func updatePlaying(now: TimeInterval, endsAt: TimeInterval) {
        let remaining = max(0, endsAt - now)
        hud.timeRemaining = remaining
        while finalMark >= 1, remaining <= TimeInterval(finalMark) {
            emit(.finalSecondsTick(finalMark))
            finalMark -= 1
        }
        let expired = live.compactMap { id, target in now > target.expiresAt ? id : nil }
        for id in expired {
            expire(id, at: now)
        }
        guard now < endsAt else {
            finishRound()
            return
        }
        spawn(now: now)
    }

    private func spawn(now: TimeInterval) {
        guard var director else { return }
        let requests = director.nextRequests(now: now, liveCount: live.count, rng: &rng)
        for request in requests {
            if arena?.spawnTarget(request, at: now) == true {
                live[request.id] = LiveTarget(
                    type: request.type,
                    spawnTime: now,
                    expiresAt: now + request.lifetime
                )
                emit(.targetSpawned(request.id))
            } else {
                director.deferSpawn(until: now + tuning.spawn.placementRetry)
            }
        }
        self.director = director
    }

    private func expire(_ id: TargetID, at time: TimeInterval) {
        guard live.removeValue(forKey: id) != nil else { return }
        stats.recordExpired()
        breakStreak()
        arena?.removeTarget(id, reason: .expired)
        resolveSlot(at: time)
        emit(.targetExpired(id))
    }

    private func finishRound() {
        let ids = Array(live.keys)
        live.removeAll()
        director = nil
        for id in ids {
            arena?.removeTarget(id, reason: .roundEnded)
        }
        hud.timeRemaining = 0
        let result = stats.makeResult(config: roundConfig)
        phase = .results(result)
        emit(.roundEnded(result))
    }

    private func resolveSlot(at time: TimeInterval) {
        guard var director else { return }
        director.targetResolved(at: time, rng: &rng)
        self.director = director
    }

    private func noteMultiplier(_ multiplier: Double) {
        guard multiplier != appliedMultiplier else { return }
        appliedMultiplier = multiplier
        hud.multiplier = multiplier
        emit(.comboChanged(multiplier))
    }

    private func breakStreak() {
        streak = 0
        noteMultiplier(1)
    }

    private func emit(_ event: GameEvent) {
        onEvent?(event)
    }

    private func reject(_ call: String) {
        #if DEBUG
        if strict { assertionFailure("Illegal PewPew call: \(call)") }
        #endif
    }
}
