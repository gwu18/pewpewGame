import Foundation
import GameCore
import RealityKit
import simd

@MainActor
final class HitFX {
    private let fx = Tuning.default.fx
    private let head = SIMD3<Float>(0, 1.5, 0)
    private var materials: TargetMaterials?
    private weak var root: Entity?
    private var shards: [Shard] = []
    private var spawns: [TargetID: SpawnAnim] = [:]
    private var hits: [TargetID: HitAnim] = [:]
    private var waves: [Wave] = []
    private var lastTime: TimeInterval?

    func prepare(root: Entity, materials: TargetMaterials) {
        self.root = root
        self.materials = materials
        shards = (0..<fx.shardPoolSize).map { _ in
            let entity = ModelEntity(mesh: .generateBox(size: 1), materials: [materials.shards[0]])
            entity.isEnabled = false
            root.addChild(entity)
            return Shard(entity: entity)
        }
    }

    func trackSpawn(id: TargetID, entity: Entity, diameter: Float, at time: TimeInterval) {
        guard let materials, let root else { return }
        let ping = ModelEntity(
            mesh: .generatePlane(width: 0.5, height: 0.5),
            materials: [materials.ping]
        )
        ping.name = "ping"
        ping.position.z = 0.004
        ping.components.set(OpacityComponent(opacity: 0.8))
        entity.addChild(ping)
        entity.scale = SIMD3(repeating: diameter * fx.spawnStartScale)
        spawns[id] = SpawnAnim(entity: entity, ping: ping, diameter: diameter, start: time)
        _ = root
    }

    func reset() {
        for shard in shards {
            shard.entity.removeFromParent()
        }
        shards.removeAll()
        for wave in waves {
            wave.entity.removeFromParent()
        }
        waves.removeAll()
        for spawn in spawns.values {
            spawn.ping?.removeFromParent()
        }
        spawns.removeAll()
        hits.removeAll()
        lastTime = nil
        materials = nil
        root = nil
    }

    @discardableResult
    func beginHit(id: TargetID, entity: Entity, diameter: Float, ring: Ring, at time: TimeInterval) -> Bool {
        spawns[id]?.ping?.removeFromParent()
        spawns[id] = nil
        guard let face = entity.findEntity(named: "face") as? ModelEntity, let materials else { return false }
        face.model?.materials = [materials.flash]
        hits[id] = HitAnim(
            entity: entity,
            face: face,
            diameter: diameter,
            ring: ring,
            start: time,
            shardsEmitted: false
        )
        return true
    }

    func update(now: TimeInterval) -> Set<TargetID> {
        let dt = min(max(now - (lastTime ?? now), 0), 0.05)
        lastTime = now
        updateSpawns(now: now)
        let finished = updateHits(now: now)
        updateShards(dt: Float(dt))
        updateWaves(now: now)
        return finished
    }

    private func updateSpawns(now: TimeInterval) {
        for (id, spawn) in spawns {
            let age = now - spawn.start
            let scale = spawnScale(age: age)
            spawn.entity.scale = SIMD3(repeating: spawn.diameter * scale)
            if let ping = spawn.ping {
                let duration = fx.spawnPingDuration
                if age >= duration {
                    ping.removeFromParent()
                    spawns[id]?.ping = nil
                } else {
                    let t = Float(age / duration)
                    ping.scale = SIMD3(repeating: 1 + (fx.spawnPingEndScale - 1) * t)
                    ping.components.set(OpacityComponent(opacity: 0.8 * (1 - t)))
                }
            }
        }
    }

    private func spawnScale(age: TimeInterval) -> Float {
        if age <= 0 { return fx.spawnStartScale }
        if age < fx.spawnOvershootTime {
            let t = Float(age / fx.spawnOvershootTime)
            let eased = 1 - pow(1 - t, 3)
            return fx.spawnStartScale + (fx.spawnOvershootScale - fx.spawnStartScale) * eased
        }
        let settleAge = age - fx.spawnOvershootTime
        if settleAge < fx.spawnSettleTime {
            let t = Float(settleAge / fx.spawnSettleTime)
            let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            return fx.spawnOvershootScale + (1 - fx.spawnOvershootScale) * eased
        }
        return 1
    }

    private func updateHits(now: TimeInterval) -> Set<TargetID> {
        var finished: Set<TargetID> = []
        for (id, hit) in hits {
            let age = now - hit.start
            guard let materials else { continue }
            if age < fx.hitFlash {
                hit.face.model?.materials = [materials.flash]
            } else if hit.ring == .gold && age < fx.hitFlash + fx.bullseyeGoldFlash {
                hit.face.model?.materials = [materials.flashGold]
            } else {
                hit.face.model?.materials = [materials.normal]
            }
            if age >= fx.hitFlash {
                let span = max(fx.hitRemoveAfter - fx.hitFlash, 0.001)
                let t = min(Float((age - fx.hitFlash) / span), 1)
                let pop = popScale(hit.ring)
                hit.entity.scale = SIMD3(repeating: hit.diameter * (1 + (pop - 1) * t))
                if !hit.shardsEmitted {
                    emitShards(for: hit)
                    if hit.ring == .gold { emitShockwave(for: hit, at: now) }
                    hits[id]?.shardsEmitted = true
                }
            }
            if age >= fx.hitRemoveAfter {
                finished.insert(id)
            }
        }
        for id in finished {
            hits.removeValue(forKey: id)
        }
        return finished
    }

    private func popScale(_ ring: Ring) -> Float {
        switch ring {
        case .gold: fx.hitPopScale.gold
        case .red: fx.hitPopScale.red
        case .none: fx.hitPopScale.outer
        }
    }

    private func emitShards(for hit: HitAnim) {
        guard let materials else { return }
        let count: Int
        let life: TimeInterval
        let speedMult: Float
        let mix: [Int]
        switch hit.ring {
        case .gold:
            count = fx.shardCount.gold
            life = fx.shardLife.gold
            speedMult = fx.shardSpeedMult.gold
            mix = [4, 4, 5, 4, 3, 3, 2, 0]
        case .red:
            count = fx.shardCount.red
            life = fx.shardLife.red
            speedMult = fx.shardSpeedMult.red
            mix = [3, 3, 3, 2, 2, 0, 4, 1]
        case .none:
            count = fx.shardCount.outer
            life = fx.shardLife.outer
            speedMult = fx.shardSpeedMult.outer
            mix = [0, 0, 1, 2, 2, 2, 3, 4]
        }
        let diameter = hit.diameter
        let center = hit.entity.position(relativeTo: nil)
        let distance = simd_length(center - head)
        let toward = simd_normalize(hit.entity.convert(direction: [0, 0, 1], to: nil))
        var sparklesRemaining = hit.ring == .gold ? fx.goldSparkleCount : 0
        for index in 0..<count {
            guard let slot = shards.firstIndex(where: { !$0.active }) else { return }
            let angle = Float.random(in: 0..<(2 * .pi))
            let local = SIMD3<Float>(cos(angle) * 0.3, sin(angle) * 0.3, 0.01)
            let world = hit.entity.convert(position: local, to: nil)
            var direction = hit.entity.convert(direction: SIMD3(cos(angle), sin(angle), 0), to: nil)
            if simd_length(direction) > 1e-4 { direction = simd_normalize(direction) }
            let jitter = Float.random(in: 0.8...1.3)
            let speed = fx.shardSpeedPerDiameter * diameter * jitter * speedMult
            var velocity = direction * speed
            velocity.y += fx.shardUpPerDiameter * diameter
            if distance >= fx.shardComfortDistance {
                velocity += toward * Float.random(in: 0...fx.shardTowardViewerMax)
            }
            let colorIndex = mix[index % mix.count]
            let sparkle = sparklesRemaining > 0 && (colorIndex == 4 || colorIndex == 5)
            if sparkle { sparklesRemaining -= 1 }
            let shardLife = sparkle ? life * fx.goldSparkleLifeMult : life
            let size = fx.shardSizeRatio * diameter
            shards[slot].active = true
            shards[slot].velocity = velocity
            shards[slot].axis = randomAxis()
            shards[slot].age = 0
            shards[slot].life = shardLife
            shards[slot].size = size
            let entity = shards[slot].entity
            entity.model?.materials = [materials.shards[colorIndex]]
            entity.position = world
            entity.scale = SIMD3(repeating: size)
            entity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            entity.isEnabled = true
        }
    }

    private func emitShockwave(for hit: HitAnim, at time: TimeInterval) {
        guard let materials, let root else { return }
        let wave = ModelEntity(
            mesh: .generatePlane(width: 1, height: 1),
            materials: [materials.shockwave]
        )
        wave.position = hit.entity.position
        wave.orientation = hit.entity.orientation
        wave.scale = SIMD3(repeating: hit.diameter)
        wave.components.set(OpacityComponent(opacity: 1))
        root.addChild(wave)
        waves.append(Wave(entity: wave, start: time, diameter: hit.diameter))
    }

    private func updateShards(dt: Float) {
        guard dt > 0 else { return }
        let spin = fx.shardSpinDegPerSec * .pi / 180 * dt
        for index in shards.indices where shards[index].active {
            shards[index].age += TimeInterval(dt)
            shards[index].velocity.y -= fx.shardGravity * dt
            shards[index].entity.position += shards[index].velocity * dt
            shards[index].entity.orientation *= simd_quatf(angle: spin, axis: shards[index].axis)
            let t = Float(shards[index].age / shards[index].life)
            let shrink = max(0, 1 - t * t)
            shards[index].entity.scale = SIMD3(repeating: shards[index].size * shrink)
            if shards[index].age >= shards[index].life {
                shards[index].active = false
                shards[index].entity.isEnabled = false
            }
        }
    }

    private func updateWaves(now: TimeInterval) {
        waves.removeAll { wave in
            let age = now - wave.start
            if age >= fx.shockwaveDuration {
                wave.entity.removeFromParent()
                return true
            }
            let t = Float(age / fx.shockwaveDuration)
            let eased = 1 - pow(1 - t, 3)
            wave.entity.scale = SIMD3(repeating: wave.diameter * (1 + (fx.shockwaveEndScale - 1) * eased))
            wave.entity.components.set(OpacityComponent(opacity: 1 - eased))
            return false
        }
    }

    private func randomAxis() -> SIMD3<Float> {
        let axis = SIMD3<Float>(
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: -1...1)
        )
        return simd_length(axis) > 1e-3 ? simd_normalize(axis) : SIMD3(0, 1, 0)
    }

    private struct Shard {
        var entity: ModelEntity
        var velocity = SIMD3<Float>(repeating: 0)
        var axis = SIMD3<Float>(0, 1, 0)
        var age: TimeInterval = 0
        var life: TimeInterval = 0
        var size: Float = 0
        var active = false
    }

    private struct SpawnAnim {
        var entity: Entity
        var ping: Entity?
        var diameter: Float
        var start: TimeInterval
    }

    private struct HitAnim {
        var entity: Entity
        var face: ModelEntity
        var diameter: Float
        var ring: Ring
        var start: TimeInterval
        var shardsEmitted: Bool
    }

    private struct Wave {
        var entity: Entity
        var start: TimeInterval
        var diameter: Float
    }
}
