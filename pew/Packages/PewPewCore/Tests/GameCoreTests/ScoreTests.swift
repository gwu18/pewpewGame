import Foundation
import Testing
@testable import GameCore

private func score(_ type: TargetType, _ rho: Float, _ reaction: TimeInterval, _ streak: Int) -> HitOutcome {
    ScoreCalculator.outcome(type: type, rho: rho, reactionTime: reaction, streakBefore: streak)
}

@Test func ringsAndSpeedMatchTheThresholds() {
    let bullseye = score(.normal, 0, 0, 0)
    #expect(bullseye.ring == .gold)
    #expect(bullseye.points == 250)
    #expect(score(.normal, 0.20, 0.45, 0).ring == .gold)
    #expect(score(.normal, 0.20, 0.45, 0).points == 250)

    #expect(score(.normal, 0.21, 0.45, 0).ring == .red)
    #expect(score(.normal, 0.40, 0.45, 0).points == 200)
    #expect(score(.normal, 0.41, 0, 0).ring == .none)
    #expect(score(.normal, 0.41, 0, 0).points == 150)

    #expect(score(.normal, 0.5, 1.5, 0).points == 100)
    #expect(score(.normal, 0.5, 3, 0).points == 100)
}

@Test func assistedHitsGetNoRing() {
    #expect(score(.normal, 1, 0, 0).ring == .none)
    #expect(score(.normal, 1, 0, 0).points == 150)
    #expect(score(.normal, 2, 0, 0).points == 150)
}

@Test func comboTiersApplyBeforeTheHit() {
    #expect(score(.normal, 0.3, 0, 4).multiplier == 1)
    #expect(score(.normal, 0.3, 0, 4).points == 200)
    #expect(score(.normal, 0.3, 0, 4).streak == 5)

    #expect(score(.normal, 0.3, 0, 5).multiplier == 1.5)
    #expect(score(.normal, 0.3, 0, 5).points == 300)
    #expect(score(.normal, 0.3, 0, 9).multiplier == 1.5)

    #expect(score(.normal, 0, 0, 10).multiplier == 2)
    #expect(score(.normal, 0, 0, 10).points == 500)
    #expect(score(.normal, 0, 0, 10).streak == 11)
}

@Test func pointsRoundToTheNearestTen() {
    // (100 + 50 ring + 0 speed) × 1.5 = 225 → 230
    #expect(score(.normal, 0.3, 2, 5).points == 230)
}

@Test func smallAndMovingUseTheirOwnBase() {
    #expect(score(.small, 0, 0, 0).points == 300)
    #expect(score(.moving, 0.5, 2, 0).points == 200)
}
