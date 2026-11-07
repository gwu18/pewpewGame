import Foundation
import Testing
@testable import GameCore

@Test func anUntouchedRoundHasNoAccuracy() {
    let result = RoundStats().makeResult(config: RoundConfig())
    #expect(result.accuracy == nil)
    #expect(result.avgReaction == nil)
    #expect(result.fastest == nil)
    #expect(result.hits == 0)
    #expect(result.targetsResolved == 0)
}

@Test func statsKeepHitsMissesAndReactionTimes() {
    var stats = RoundStats()
    stats.recordHit(HitOutcome(points: 250, ring: .gold, reactionTime: 0.4, multiplier: 1, streak: 1), source: .blaster)
    stats.recordHit(HitOutcome(points: 100, ring: .none, reactionTime: 0.8, multiplier: 1, streak: 2), source: .debug)
    stats.recordMiss()
    stats.recordExpired()
    let result = stats.makeResult(config: RoundConfig(length: 60, controls: .blaster))
    #expect(result.score == 350)
    #expect(result.hits == 2)
    #expect(result.missedShots == 1)
    #expect(result.expired == 1)
    #expect(result.targetsResolved == 3)
    #expect(result.shotsFired == 2)
    #expect(result.accuracy == 0.5)
    #expect(result.reactionTimes == [0.4, 0.8])
    #expect(result.avgReaction == (0.4 + 0.8) / 2)
    #expect(result.fastest == 0.4)
    #expect(result.bestStreak == 2)
    #expect(result.bullseyes == 1)
    #expect(result.config == RoundConfig(length: 60, controls: .blaster))
}
