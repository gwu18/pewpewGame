import Foundation

public enum ScoreCalculator {
    public static func outcome(
        type: TargetType,
        rho: Float,
        reactionTime: TimeInterval,
        streakBefore: Int,
        tuning: Tuning = .default
    ) -> HitOutcome {
        let score = tuning.score
        let ring = ring(for: rho, score: score)
        let ringBonus = bonus(for: ring, score: score)
        let speed = speedBonus(reactionTime, score: score)
        let multiplier = multiplier(streakBefore: streakBefore, score: score)
        let raw = (Double(score.base.value(type) + ringBonus) + speed) * multiplier
        let points = Int((raw / Double(score.rounding)).rounded()) * score.rounding
        return HitOutcome(
            points: points,
            ring: ring,
            reactionTime: reactionTime,
            multiplier: multiplier,
            streak: streakBefore + 1
        )
    }

    /// ρ ≥ 1 is an assisted hit and earns no ring bonus.
    private static func ring(for rho: Float, score: Tuning.Score) -> Ring {
        if rho >= 1 { return .none }
        if rho <= score.goldRadius { return .gold }
        if rho <= score.redRadius { return .red }
        return .none
    }

    private static func bonus(for ring: Ring, score: Tuning.Score) -> Int {
        switch ring {
        case .gold: score.goldBonus
        case .red: score.redBonus
        case .none: 0
        }
    }

    private static func speedBonus(_ reactionTime: TimeInterval, score: Tuning.Score) -> Double {
        let span = score.speedZero - score.speedFull
        guard span > 0 else { return 0 }
        let fraction = 1 - (reactionTime - score.speedFull) / span
        return Double(score.speedBonusMax) * min(max(fraction, 0), 1)
    }

    private static func multiplier(streakBefore: Int, score: Tuning.Score) -> Double {
        if streakBefore >= score.comboStreakTier2 { return score.comboMultiplierTier2 }
        if streakBefore >= score.comboStreakTier1 { return score.comboMultiplierTier1 }
        return 1
    }
}
