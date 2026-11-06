import GameCore
import Testing
import simd
@testable import GestureCore

private func snapshot(_ id: Int, _ center: SIMD3<Float>, radius: Float) -> TargetSnapshot {
    TargetSnapshot(id: TargetID(raw: id), center: center, normal: SIMD3(0, 0, 1), radius: radius)
}

@Test func touchInsideCenter() {
    let result = HitMath.resolveTouch(
        prevTip: SIMD3(0, 0, 0.2),
        tip: SIMD3(0, 0, 0),
        targets: [snapshot(1, .zero, radius: 0.1)],
        forgiveness: 0
    )
    #expect(result?.id == TargetID(raw: 1))
    #expect(result!.normalizedRadius < 0.05)
}

@Test func touchOutsideMisses() {
    let result = HitMath.resolveTouch(
        prevTip: SIMD3(2, 0, 0),
        tip: SIMD3(2.2, 0, 0),
        targets: [snapshot(1, .zero, radius: 0.1)],
        forgiveness: 0.03
    )
    #expect(result == nil)
}

@Test func sweptPokeHitsWhenEndpointsMiss() {
    let result = HitMath.resolveTouch(
        prevTip: SIMD3(-1, 0, 0),
        tip: SIMD3(1, 0, 0),
        targets: [snapshot(1, .zero, radius: 0.1)],
        forgiveness: 0
    )
    #expect(result?.id == TargetID(raw: 1))
    #expect(result!.normalizedRadius < 0.01)
}

@Test func twoTargetsPicksNearest() {
    let targets = [
        snapshot(1, SIMD3(0, 0, 0), radius: 0.5),
        snapshot(2, SIMD3(0, 0.3, 0), radius: 0.5),
    ]
    let result = HitMath.resolveTouch(
        prevTip: SIMD3(0, 0.05, 0.2),
        tip: SIMD3(0, 0.05, 0),
        targets: targets,
        forgiveness: 0
    )
    #expect(result?.id == TargetID(raw: 1))
}

@Test func forgivenessExtendsTheSphere() {
    let result = HitMath.resolveTouch(
        prevTip: SIMD3(0.12, 0, 0),
        tip: SIMD3(0.12, 0, 0),
        targets: [snapshot(1, .zero, radius: 0.1)],
        forgiveness: 0.03
    )
    #expect(result?.id == TargetID(raw: 1))
    #expect(abs(result!.normalizedRadius - 1.2) < 0.02)
}
