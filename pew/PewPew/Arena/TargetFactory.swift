import GameCore
import RealityKit
import simd

enum TargetFactory {
    @MainActor
    static func make(
        type: TargetType,
        diameter: Float,
        materials: TargetMaterials,
        lookPinch: Bool,
        bodyMesh: MeshResource?
    ) -> Entity {
        let root = Entity()
        root.name = "target"
        let faceMaterial: UnlitMaterial = type == .small ? materials.small : materials.normal
        let face = ModelEntity(
            mesh: .generatePlane(width: 1, height: 1),
            materials: [faceMaterial]
        )
        face.name = "face"
        root.addChild(face)

        let depth = Tuning.default.fx.bodyDepthRatio
        let body: ModelEntity
        if let bodyMesh {
            body = ModelEntity(mesh: bodyMesh, materials: [materials.inkBody])
        } else {
            body = cylinderRim(depth: depth, material: materials.inkBody)
        }
        body.name = "body"
        body.components.set(GroundingShadowComponent(castsShadow: true))
        root.addChild(body)

        root.scale = SIMD3(repeating: diameter)
        if lookPinch {
            root.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.5)]))
            root.components.set(InputTargetComponent())
        }
        return root
    }

    /// Plan §5.1 fallback. Used only when the extruded slab mesh cannot be built.
    @MainActor
    static func cylinderRim(depth: Float, material: PhysicallyBasedMaterial) -> ModelEntity {
        let rim = ModelEntity(
            mesh: .generateCylinder(height: depth, radius: 0.5),
            materials: [material]
        )
        rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        rim.position = [0, 0, -depth / 2]
        return rim
    }

    @MainActor
    static func bodyMesh(_ m: [[FacePixel]], diameter D: Float, depth: Float) async throws -> MeshResource {
        let n = m.count, t = D / Float(n)
        func filled(_ x: Int, _ y: Int) -> Bool {
            (0..<n).contains(x) && (0..<n).contains(y) && m[y][x] != .clear
        }
        var pos: [SIMD3<Float>] = []
        var nor: [SIMD3<Float>] = []
        var idx: [UInt32] = []
        func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>, _ nn: SIMD3<Float>) {
            let i = UInt32(pos.count)
            pos += [a, b, c, d]
            nor += [nn, nn, nn, nn]
            idx += [i, i + 1, i + 2, i, i + 2, i + 3]
        }
        let zf: Float = -0.0005, zb = -depth
        for y in 0..<n {
            for x in 0..<n where filled(x, y) {
                let x0 = (Float(x) / Float(n) - 0.5) * D, x1 = x0 + t
                let y1 = (0.5 - Float(y) / Float(n)) * D, y0 = y1 - t
                quad([x0, y0, zb], [x0, y1, zb], [x1, y1, zb], [x1, y0, zb], [0, 0, -1])
                if !filled(x - 1, y) { quad([x0, y0, zf], [x0, y1, zf], [x0, y1, zb], [x0, y0, zb], [-1, 0, 0]) }
                if !filled(x + 1, y) { quad([x1, y0, zb], [x1, y1, zb], [x1, y1, zf], [x1, y0, zf], [1, 0, 0]) }
                if !filled(x, y - 1) { quad([x0, y1, zb], [x0, y1, zf], [x1, y1, zf], [x1, y1, zb], [0, 1, 0]) }
                if !filled(x, y + 1) { quad([x0, y0, zf], [x0, y0, zb], [x1, y0, zb], [x1, y0, zf], [0, -1, 0]) }
            }
        }
        var desc = MeshDescriptor(name: "targetBody")
        desc.positions = MeshBuffers.Positions(pos)
        desc.normals = MeshBuffers.Normals(nor)
        desc.primitives = .triangles(idx)
        return try await MeshResource(from: [desc])
    }
}
