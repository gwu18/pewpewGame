import Foundation
import Testing
@testable import GameCore

private let countdownLength = Tuning.default.round.countdownStep * 3 + Tuning.default.round.goDuration

@MainActor
private final class FakeArena: ArenaRendering {
    var spawned: [SpawnRequest] = []
    var removals: [(TargetID, RemovalReason)] = []
    var cleared = false
    var acceptSpawns = true

    func spawnTarget(_ request: SpawnRequest, at time: TimeInterval) -> Bool {
        guard acceptSpawns else { return false }
        spawned.append(request)
        return true
    }

    func removeTarget(_ id: TargetID, reason: RemovalReason) {
        removals.append((id, reason))
    }

    func removeAllTargets() {
        cleared = true
        spawned.removeAll()
    }
}

@MainActor
private func harness(seed: UInt64 = 1, config: RoundConfig = RoundConfig()) -> (GameSession, FakeArena) {
    let session = GameSession(seed: seed)
    session.config = config
    let arena = FakeArena()
    session.arena = arena
    return (session, arena)
}

@MainActor
private func pump(_ session: GameSession, _ arena: FakeArena, from start: TimeInterval, until count: Int) -> TimeInterval {
    var time = start
    while arena.spawned.count < count, time < start + 10 {
        time += 0.05
        session.tick(now: time)
    }
    return time
}

private func roundResult(_ phase: GamePhase) -> RoundResult? {
    if case .results(let result) = phase { return result }
    return nil
}

@MainActor
@Test func roundStartsInTheLobby() {
    let (session, _) = harness()
    #expect(session.phase == .lobby)
    session.start(now: 2)
    #expect(session.phase == .countdown(endsAt: 2 + countdownLength))
}

@MainActor
@Test func oneLateTickPlaysTheWholeCountdown() {
    let (session, arena) = harness()
    var events: [GameEvent] = []
    session.onEvent = { events.append($0) }
    session.start(now: 0)
    session.tick(now: countdownLength)
    let opening = events.prefix(4)
    #expect(Array(opening) == [.countdownTick(3), .countdownTick(2), .countdownTick(1), .go])
    #expect(session.phase == .playing(endsAt: countdownLength + 30))
    #expect(arena.spawned.isEmpty)
}

@MainActor
@Test func countdownMarksArriveOnTheirSeconds() {
    let (session, _) = harness()
    var events: [GameEvent] = []
    session.onEvent = { events.append($0) }
    session.start(now: 0)
    session.tick(now: 0)
    session.tick(now: 1)
    session.tick(now: 2)
    session.tick(now: 3)
    #expect(session.phase == .countdown(endsAt: countdownLength))
    session.tick(now: countdownLength)
    #expect(events == [.countdownTick(3), .countdownTick(2), .countdownTick(1), .go])
    #expect(session.phase == .playing(endsAt: countdownLength + 30))
}

@MainActor
@Test func startDuringPlayDoesNothing() {
    let (session, _) = harness()
    session.start(now: 0)
    session.tick(now: countdownLength)
    session.start(now: 10)
    #expect(session.phase == .playing(endsAt: countdownLength + 30))
}

@MainActor
@Test func playAgainStartsAnotherCountdown() {
    let (session, _) = harness()
    session.start(now: 0)
    session.tick(now: countdownLength + 30)
    #expect(roundResult(session.phase) != nil)
    session.start(now: 100)
    #expect(session.phase == .countdown(endsAt: 100 + countdownLength))
}

@MainActor
@Test func tutorialAdvancesAndCanBeSkipped() {
    let (session, _) = harness()
    session.skipTutorial(now: 0)
    #expect(session.phase == .lobby)
    session.startTutorial(now: 1)
    #expect(session.phase == .tutorial(.touch))
    session.tutorialPoseDetected()
    #expect(session.phase == .tutorial(.gunPose))
    session.tutorialPoseDetected()
    #expect(session.phase == .tutorial(.gunFire))
    session.tutorialPoseDetected()
    #expect(session.phase == .tutorial(.done))
    session.tutorialPoseDetected()
    #expect(session.phase == .tutorial(.done))
    session.skipTutorial(now: 4)
    #expect(session.phase == .countdown(endsAt: 4 + countdownLength))
}

@MainActor
@Test func leavingMidRoundHasNoResult() {
    let (session, arena) = harness()
    var events: [GameEvent] = []
    session.onEvent = { events.append($0) }
    session.start(now: 0)
    session.tick(now: countdownLength)
    session.returnToLobby()
    #expect(session.phase == .lobby)
    #expect(arena.cleared)
    #expect(events.allSatisfy { if case .roundEnded = $0 { false } else { true } })
}

@MainActor
@Test func resetReturnsToTheLobby() {
    let (session, arena) = harness()
    session.start(now: 0)
    session.tick(now: countdownLength + 0.9)
    #expect(!arena.spawned.isEmpty)
    session.reset()
    session.tick(now: 100)
    #expect(session.phase == .lobby)
    #expect(arena.cleared)
}

@MainActor
@Test func configIsFixedWhenTheRoundStarts() {
    let (session, _) = harness()
    session.config.length = 30
    session.start(now: 0)
    session.config.length = 60
    session.tick(now: countdownLength)
    #expect(session.phase == .playing(endsAt: countdownLength + 30))
}

@MainActor
@Test func hitUsesTheScoringFormula() {
    let (session, arena) = harness()
    session.start(now: 0)
    let spawnedAt = pump(session, arena, from: countdownLength, until: 1)
    let id = arena.spawned[0].id
    let outcome = session.registerHit(
        HitEvent(target: id, source: .debug, timestamp: spawnedAt + 0.2, normalizedRadius: 0.1)
    )
    #expect(outcome?.points == 250)
    #expect(outcome?.ring == .gold)
    #expect(outcome?.streak == 1)
    #expect(session.hud.score == 250)
    #expect(arena.removals.map(\.0) == [id])
}

@MainActor
@Test func secondHitAndUnknownTargetAreIgnored() {
    let (session, arena) = harness()
    session.start(now: 0)
    let spawnedAt = pump(session, arena, from: countdownLength, until: 1)
    let id = arena.spawned[0].id
    let hit = HitEvent(target: id, source: .touch, timestamp: spawnedAt, normalizedRadius: 0.5)
    #expect(session.registerHit(hit) != nil)
    #expect(session.registerHit(hit) == nil)
    let missing = HitEvent(target: TargetID(raw: 99), source: .touch, timestamp: spawnedAt, normalizedRadius: 0)
    #expect(session.registerHit(missing) == nil)
}

@MainActor
@Test func hitAtTheDeadlineBeatsExpiry() {
    let (session, arena) = harness()
    session.start(now: 0)
    let spawnedAt = pump(session, arena, from: countdownLength, until: 1)
    let target = arena.spawned[0]
    let deadline = spawnedAt + target.lifetime
    let outcome = session.registerHit(
        HitEvent(target: target.id, source: .debug, timestamp: deadline, normalizedRadius: 0.5)
    )
    session.tick(now: deadline)
    #expect(outcome != nil)
    if let outcome {
        #expect(arena.removals.count == 1)
        #expect(arena.removals[0].0 == target.id)
        #expect(arena.removals[0].1 == .hit(outcome))
    }
}

@MainActor
@Test func targetExpiresOnlyAfterItsDeadline() {
    let (session, arena) = harness()
    session.start(now: 0)
    let spawnedAt = pump(session, arena, from: countdownLength, until: 1)
    let target = arena.spawned[0]
    let deadline = spawnedAt + target.lifetime
    session.tick(now: deadline)
    #expect(arena.removals.isEmpty)
    session.tick(now: deadline + 0.01)
    #expect(arena.removals.count == 1)
    #expect(arena.removals[0].0 == target.id)
    #expect(arena.removals[0].1 == .expired)
    let late = HitEvent(target: target.id, source: .debug, timestamp: deadline + 0.01, normalizedRadius: 0)
    #expect(session.registerHit(late) == nil)
}

@MainActor
@Test func expiryBreaksTheCombo() {
    let (session, arena) = harness()
    var combos: [Double] = []
    session.onEvent = { if case .comboChanged(let multiplier) = $0 { combos.append(multiplier) } }
    session.start(now: 0)
    var time = countdownLength
    for _ in 0..<6 {
        time = pump(session, arena, from: time, until: arena.spawned.count + 1)
        let id = arena.spawned.last!.id
        _ = session.registerHit(HitEvent(target: id, source: .debug, timestamp: time, normalizedRadius: 0.5))
    }
    time = pump(session, arena, from: time, until: arena.spawned.count + 1)
    let spawnedAt = time
    let life = arena.spawned.last!.lifetime
    session.tick(now: spawnedAt + life + 0.01)
    #expect(combos == [1.5, 1])
}

@MainActor
@Test func roundEndDoesNotCountAsExpired() {
    let (session, arena) = harness()
    var events: [GameEvent] = []
    session.onEvent = { events.append($0) }
    session.start(now: 0)
    let end = countdownLength + 30
    session.tick(now: end - 1)
    session.tick(now: end)
    let finals = events.compactMap { if case .finalSecondsTick(let number) = $0 { number } else { nil } }
    #expect(finals == Array((1...10).reversed()))
    #expect(events.contains { if case .targetExpired = $0 { true } else { false } } == false)
    #expect(arena.removals.map(\.1) == [.roundEnded])
    #expect(roundResult(session.phase)?.expired == 0)
    #expect(roundResult(session.phase)?.targetsResolved == 0)
}

@MainActor
@Test func nothingSpawnsInTheFinalMoment() {
    let (session, arena) = harness()
    session.start(now: 0)
    session.tick(now: countdownLength + 30 - 0.5)
    #expect(arena.spawned.isEmpty)
    #expect(session.phase == .playing(endsAt: countdownLength + 30))
}

@MainActor
@Test func aFailedPlacementRetries() {
    let (session, arena) = harness()
    arena.acceptSpawns = false
    session.start(now: 0)
    session.tick(now: countdownLength + 0.9)
    #expect(arena.spawned.isEmpty)
    arena.acceptSpawns = true
    session.tick(now: countdownLength + 0.9 + Tuning.default.spawn.placementRetry)
    #expect(arena.spawned.count == 1)
    #expect(arena.spawned[0].type == .normal)
}

@MainActor
@Test func missedShotsCountOnlyWhilePlaying() {
    let (session, _) = harness()
    var events: [GameEvent] = []
    session.onEvent = { events.append($0) }
    session.registerMissedShot(at: 0, source: .blaster)
    session.start(now: 0)
    session.registerMissedShot(at: 1, source: .blaster)
    session.tick(now: countdownLength)
    session.registerMissedShot(at: countdownLength, source: .blaster)
    #expect(events.filter { if case .missedShot = $0 { true } else { false } }.count == 1)
}

@MainActor
@Test func onlyBlasterHitsAndMissesCountAsShots() {
    let (session, arena) = harness()
    session.start(now: 0)
    var time = pump(session, arena, from: countdownLength, until: 1)
    let first = arena.spawned[0].id
    _ = session.registerHit(HitEvent(target: first, source: .blaster, timestamp: time, normalizedRadius: 0.5))
    session.registerMissedShot(at: time, source: .blaster)
    time = pump(session, arena, from: time, until: 2)
    let second = arena.spawned[1].id
    _ = session.registerHit(HitEvent(target: second, source: .debug, timestamp: time, normalizedRadius: 0.5))
    session.tick(now: countdownLength + 30)
    let result = roundResult(session.phase)
    #expect(result?.hits == 2)
    #expect(result?.missedShots == 1)
    #expect(result?.shotsFired == 2)
}
