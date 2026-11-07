import Foundation

public struct RoundResult: Sendable, Equatable {
    public var score: Int
    public var hits: Int
    public var missedShots: Int
    public var expired: Int
    public var targetsResolved: Int
    public var shotsFired: Int
    public var accuracy: Double?
    public var reactionTimes: [TimeInterval]
    public var avgReaction: TimeInterval?
    public var fastest: TimeInterval?
    public var bestStreak: Int
    public var bullseyes: Int
    public var config: RoundConfig

    public init(
        score: Int,
        hits: Int,
        missedShots: Int,
        expired: Int,
        targetsResolved: Int,
        shotsFired: Int,
        accuracy: Double?,
        reactionTimes: [TimeInterval],
        avgReaction: TimeInterval?,
        fastest: TimeInterval?,
        bestStreak: Int,
        bullseyes: Int,
        config: RoundConfig
    ) {
        self.score = score
        self.hits = hits
        self.missedShots = missedShots
        self.expired = expired
        self.targetsResolved = targetsResolved
        self.shotsFired = shotsFired
        self.accuracy = accuracy
        self.reactionTimes = reactionTimes
        self.avgReaction = avgReaction
        self.fastest = fastest
        self.bestStreak = bestStreak
        self.bullseyes = bullseyes
        self.config = config
    }
}

extension RoundResult: CustomStringConvertible {
    public var description: String {
        let accuracyText = accuracy.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
        return "score=\(score) hits=\(hits) misses=\(missedShots) expired=\(expired) resolved=\(targetsResolved) shots=\(shotsFired) accuracy=\(accuracyText) best=\(bestStreak) bullseyes=\(bullseyes)"
    }
}

public struct RoundStats: Sendable {
    public private(set) var score = 0
    public private(set) var hits = 0
    public private(set) var missedShots = 0
    public private(set) var expired = 0
    public private(set) var shotsFired = 0
    public private(set) var bestStreak = 0
    public private(set) var bullseyes = 0
    private var reactions: [TimeInterval] = []

    public init() {}

    public mutating func recordHit(_ outcome: HitOutcome, source: InputSource) {
        hits += 1
        score += outcome.points
        reactions.append(outcome.reactionTime)
        bestStreak = max(bestStreak, outcome.streak)
        if outcome.ring == .gold { bullseyes += 1 }
        if source == .blaster { shotsFired += 1 }
    }

    public mutating func recordMiss() {
        missedShots += 1
        shotsFired += 1
    }

    public mutating func recordExpired() {
        expired += 1
    }

    public func makeResult(config: RoundConfig) -> RoundResult {
        let attempts = hits + missedShots + expired
        let accuracy: Double? = attempts == 0 ? nil : Double(hits) / Double(attempts)
        let average: TimeInterval? = reactions.isEmpty ? nil : reactions.reduce(0, +) / Double(reactions.count)
        return RoundResult(
            score: score,
            hits: hits,
            missedShots: missedShots,
            expired: expired,
            targetsResolved: hits + expired,
            shotsFired: shotsFired,
            accuracy: accuracy,
            reactionTimes: reactions,
            avgReaction: average,
            fastest: reactions.min(),
            bestStreak: bestStreak,
            bullseyes: bullseyes,
            config: config
        )
    }
}
