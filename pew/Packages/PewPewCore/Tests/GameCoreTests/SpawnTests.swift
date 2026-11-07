import Foundation
import Testing
@testable import GameCore

private func director(_ config: RoundConfig = RoundConfig(), seed: UInt64 = 1, end: TimeInterval = 100) -> (SpawnDirector, SeededRandom) {
    var rng = SeededRandom(seed: seed)
    let director = SpawnDirector(config: config, roundStart: 0, roundEnd: end, rng: &rng)
    return (director, rng)
}

private func spawned(_ config: RoundConfig, at time: TimeInterval, seed: UInt64 = 1) -> SpawnRequest {
    var (spawn, rng) = director(config, seed: seed)
    return spawn.nextRequests(now: time, liveCount: 0, rng: &rng)[0]
}

@Test func firstSpawnWaitsInsideTheOpeningWindow() {
    var (spawn, rng) = director()
    #expect(spawn.nextRequests(now: 0.39, liveCount: 0, rng: &rng).isEmpty)
    #expect(spawn.nextRequests(now: 0.9, liveCount: 0, rng: &rng).count == 1)
}

@Test func theNextSpawnWaitsOutItsDelay() {
    var (spawn, rng) = director()
    #expect(spawn.nextRequests(now: 0.9, liveCount: 0, rng: &rng).count == 1)
    spawn.targetResolved(at: 2, rng: &rng)
    #expect(spawn.nextRequests(now: 2, liveCount: 0, rng: &rng).isEmpty)
    let upper = Tuning.default.spawn.delay.normal.upper
    #expect(spawn.nextRequests(now: 2 + upper, liveCount: 0, rng: &rng).count == 1)
}

@Test func spawnsStopInTheClosingTail() {
    var (spawn, rng) = director(end: 30)
    #expect(spawn.nextRequests(now: 29.3, liveCount: 0, rng: &rng).isEmpty)
}

@Test func hardKeepsTwoTargetsAlive() {
    var (spawn, rng) = director(RoundConfig(difficulty: .hard))
    #expect(spawn.nextRequests(now: 0.9, liveCount: 0, rng: &rng).count == 2)
    var (paced, pacedRNG) = director(RoundConfig(difficulty: .hard), seed: 2)
    #expect(paced.nextRequests(now: 0.9, liveCount: 1, rng: &pacedRNG).count == 1)
    #expect(paced.nextRequests(now: 0.9, liveCount: 1, rng: &pacedRNG).count == 1)
    #expect(paced.nextRequests(now: 0.9, liveCount: 2, rng: &pacedRNG).isEmpty)
}

@Test func warmupIsNormalAndMovingStaysOff() {
    var sawSmall = false
    for seed in UInt64(1)...80 {
        var rng = SeededRandom(seed: seed)
        var spawn = SpawnDirector(config: RoundConfig(), roundStart: 0, roundEnd: 100, rng: &rng)
        let early = spawn.nextRequests(now: 0.9, liveCount: 0, rng: &rng)
        #expect(early.count == 1)
        #expect(early[0].type == .normal)
        spawn.targetResolved(at: 6, rng: &rng)
        let later = spawn.nextRequests(now: 8, liveCount: 0, rng: &rng)
        #expect(later.count == 1)
        #expect(later[0].type != .moving)
        if later[0].type == .small { sawSmall = true }
    }
    #expect(sawSmall)
}

@Test func lifetimeAndDiameterFollowTheRound() {
    let targets = Tuning.default.targets
    let touch = spawned(RoundConfig(), at: 0.9)
    #expect(touch.type == .normal)
    #expect(touch.motion == .none)
    #expect(touch.diameter == targets.diameterTouch.normal)
    #expect(touch.lifetime == targets.lifetimeBlaster.normal + targets.touchLifetimeExtra)

    let easy = spawned(RoundConfig(difficulty: .easy), at: 0.9)
    #expect(easy.diameter == targets.diameterTouch.normal * targets.sizeMultiplier.easy)
    #expect(easy.lifetime == touch.lifetime * targets.lifetimeMultiplier.easy)

    let roam = spawned(RoundConfig(space: .roam), at: 0.9)
    #expect(roam.lifetime == touch.lifetime * targets.roamLifetimeMultiplier)

    let big = spawned(RoundConfig(bigTargets: true), at: 0.9)
    #expect(big.diameter == targets.diameterTouch.normal * targets.bigTargetsMultiplier)

    let blaster = spawned(RoundConfig(controls: .blaster, difficulty: .hard), at: 0.9)
    #expect(blaster.lifetime == targets.lifetimeBlaster.normal * targets.lifetimeMultiplier.hard)
    #expect(blaster.diameter == targets.diameterBlaster.normal * targets.sizeMultiplier.hard)
}
