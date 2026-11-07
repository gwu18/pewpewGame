import Foundation
import GameCore
import GestureCore
import QuartzCore
import RealityKit
import simd

@MainActor
final class ArenaController: ArenaRendering {
    private let head = SIMD3<Float>(0, 1.5, 0)
    private let bands = Tuning.default.bands
    private let root = Entity()
    private let fx = HitFX()
    private weak var session: GameSession?
    private var materials: TargetMaterials?
    private var bodyMesh: MeshResource?
    private var records: [TargetID: Record] = [:]
    private var entityIDs: [ObjectIdentifier: TargetID] = [:]
    var lookPinchEnabled = true
    private var updateSubscription: EventSubscription?

    var rootEntity: Entity { root }

    func bind(_ session: GameSession) {
        self.session = session
    }

    func prepare(materials: TargetMaterials) async {
        self.materials = materials
        root.name = "ArenaRoot"
        bodyMesh = try? await TargetFactory.bodyMesh(
            PixelTargetMap.normal(),
            diameter: 1,
            depth: Tuning.default.fx.bodyDepthRatio
        )
        fx.prepare(root: root, materials: materials)
    }

    func retain(_ subscription: EventSubscription) {
        updateSubscription = subscription
    }

    /// Drops every target, shard, and attachment so the next visit starts empty.
    func reset() {
        removeAllTargets()
        fx.reset()
        updateSubscription = nil
        for child in Array(root.children) {
            child.removeFromParent()
        }
    }

    func targetRoot(for entity: Entity) -> Entity? {
        guard let id = targetID(for: entity) else { return nil }
        return records[id]?.entity
    }

    func advance(now: TimeInterval, input: InputCoordinator?, session: GameSession?) {
        input?.update(now: now)
        session?.tick(now: now)
        for id in fx.update(now: now) {
            destroy(id)
        }
    }

    func spawnTarget(_ request: SpawnRequest, at time: TimeInterval) -> Bool {
        guard let materials else { return false }
        let entity = TargetFactory.make(
            type: request.type,
            diameter: request.diameter,
            materials: materials,
            lookPinch: lookPinchEnabled,
            bodyMesh: bodyMesh
        )
        entity.position = position()
        faceHead(entity)
        root.addChild(entity)
        fx.trackSpawn(id: request.id, entity: entity, diameter: request.diameter, at: time)
        records[request.id] = Record(
            entity: entity,
            type: request.type,
            diameter: request.diameter,
            radius: request.diameter / 2
        )
        remember(entity, id: request.id)
        return true
    }

    func removeTarget(_ id: TargetID, reason: RemovalReason) {
        guard var record = records[id], !record.removing else { return }
        record.removing = true
        records[id] = record
        let now = CACurrentMediaTime()
        switch reason {
        case .hit(let outcome):
            let started = fx.beginHit(
                id: id,
                entity: record.entity,
                diameter: record.diameter,
                ring: outcome.ring,
                at: now
            )
            if !started { destroy(id) }
        case .expired:
            let gray = record.type == .small ? materials?.smallGray : materials?.normalGray
            let started = gray.map {
                fx.beginExpire(id: id, entity: record.entity, diameter: record.diameter, gray: $0, at: now)
            } ?? false
            if !started { destroy(id) }
        case .roundEnded:
            if !fx.beginVanish(id: id, entity: record.entity, diameter: record.diameter, at: now) {
                destroy(id)
            }
        }
    }

    func removeAllTargets() {
        fx.stopAnimations()
        for id in Array(records.keys) {
            destroy(id)
        }
    }

    func snapshots() -> [TargetSnapshot] {
        records.compactMap { id, record in
            guard !record.removing else { return nil }
            let center = record.entity.position(relativeTo: nil)
            let normal = record.entity.convert(direction: [0, 0, 1], to: nil)
            return TargetSnapshot(id: id, center: center, normal: normal, radius: record.radius)
        }
    }

    func targetID(for entity: Entity) -> TargetID? {
        var current: Entity? = entity
        while let node = current {
            if let id = entityIDs[ObjectIdentifier(node)] { return id }
            current = node.parent
        }
        return nil
    }

    func nearestTargetID() -> TargetID? {
        snapshots().min { simd_length($0.center - head) < simd_length($1.center - head) }?.id
    }

    private func position() -> SIMD3<Float> {
        let forward = session?.nextFloat(in: bands.stayPutTouchForward.lower...bands.stayPutTouchForward.upper) ?? 0.5
        let lateral = session?.nextFloat(in: -bands.stayPutTouchLateral...bands.stayPutTouchLateral) ?? 0
        let vertical = session?.nextFloat(in: bands.stayPutTouchVertical.lower...bands.stayPutTouchVertical.upper) ?? -0.2
        return SIMD3(head.x + lateral, head.y + vertical, head.z - forward)
    }

    private func faceHead(_ entity: Entity) {
        let dx = head.x - entity.position.x
        let dz = head.z - entity.position.z
        entity.orientation = simd_quatf(angle: atan2(dx, dz), axis: [0, 1, 0])
    }

    private func remember(_ entity: Entity, id: TargetID) {
        entityIDs[ObjectIdentifier(entity)] = id
        for child in entity.children {
            remember(child, id: id)
        }
    }

    private func destroy(_ id: TargetID) {
        guard let record = records.removeValue(forKey: id) else { return }
        forget(record.entity)
        record.entity.removeFromParent()
    }

    private func forget(_ entity: Entity) {
        entityIDs[ObjectIdentifier(entity)] = nil
        for child in entity.children {
            forget(child)
        }
    }

    private struct Record {
        var entity: Entity
        var type: TargetType
        var diameter: Float
        var radius: Float
        var removing = false
    }
}
