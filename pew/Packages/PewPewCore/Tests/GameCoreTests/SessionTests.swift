import Foundation
import Testing
@testable import GameCore

@MainActor
private final class FakeArena: ArenaRendering {
    var spawned: [SpawnRequest] = []
    var removed: [TargetID] = []
    var acceptSpawns = true

    func spawnTarget(_ request: SpawnRequest, at time: TimeInterval) -> Bool {
        guard acceptSpawns else { return false }
        spawned.append(request)
        return true
    }

    func removeTarget(_ id: TargetID, reason: RemovalReason) {
        removed.append(id)
    }

    func removeAllTargets() {
        spawned.removeAll()
    }
}

@MainActor
@Test func hitOnLiveTargetScores() {
    let session = GameSession(seed: 1)
    let arena = FakeArena()
    session.arena = arena
    session.tick(now: 0)
    let id = arena.spawned[0].id
    let outcome = session.registerHit(
        HitEvent(target: id, source: .debug, timestamp: 0.2, normalizedRadius: 0.1)
    )
    #expect(outcome?.points == 100)
    #expect(arena.removed == [id])
}

@MainActor
@Test func secondHitOnSameTargetIsIgnored() {
    let session = GameSession(seed: 1)
    let arena = FakeArena()
    session.arena = arena
    session.tick(now: 0)
    let id = arena.spawned[0].id
    let hit = HitEvent(target: id, source: .touch, timestamp: 0.2, normalizedRadius: 0.5)
    #expect(session.registerHit(hit) != nil)
    #expect(session.registerHit(hit) == nil)
}

@MainActor
@Test func unknownTargetIsIgnored() {
    let session = GameSession(seed: 1)
    let arena = FakeArena()
    session.arena = arena
    session.tick(now: 0)
    let outcome = session.registerHit(
        HitEvent(target: TargetID(raw: 99), source: .touch, timestamp: 0.2, normalizedRadius: 0)
    )
    #expect(outcome == nil)
    #expect(arena.removed.isEmpty)
}

@MainActor
@Test func tickSpawnsExactlyOneTarget() {
    let session = GameSession(seed: 1)
    let arena = FakeArena()
    session.arena = arena
    session.tick(now: 0)
    session.tick(now: 0.5)
    #expect(arena.spawned.count == 1)
    #expect(arena.spawned[0].type == .normal)
    #expect(arena.spawned[0].diameter == Tuning.default.targets.diameterTouch.normal)
}

@MainActor
@Test func nextSpawnWaitsOneSecondAfterHit() {
    let session = GameSession(seed: 1)
    let arena = FakeArena()
    session.arena = arena
    session.tick(now: 0)
    let id = arena.spawned[0].id
    _ = session.registerHit(
        HitEvent(target: id, source: .debug, timestamp: 0.4, normalizedRadius: 0)
    )
    session.tick(now: 1.3)
    #expect(arena.spawned.count == 1)
    session.tick(now: 1.4)
    #expect(arena.spawned.count == 2)
}

@MainActor
@Test func resetStartsAFreshTarget() {
    let session = GameSession(seed: 1)
    let arena = FakeArena()
    session.arena = arena
    session.tick(now: 0)
    let first = arena.spawned[0].id
    _ = session.registerHit(
        HitEvent(target: first, source: .debug, timestamp: 0.2, normalizedRadius: 0.1)
    )
    session.reset()
    session.tick(now: 10)
    #expect(arena.spawned.count == 2)
    #expect(arena.spawned[1].id == TargetID(raw: 1))
    #expect(arena.spawned[1].type == .normal)
}
