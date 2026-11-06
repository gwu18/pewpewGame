import GameCore
import simd

public struct TargetSnapshot: Sendable {
    public var id: TargetID
    public var center: SIMD3<Float>
    public var normal: SIMD3<Float>
    public var radius: Float

    public init(id: TargetID, center: SIMD3<Float>, normal: SIMD3<Float>, radius: Float) {
        self.id = id
        self.center = center
        self.normal = normal
        self.radius = radius
    }
}

public struct TouchResult: Sendable, Equatable {
    public var id: TargetID
    public var normalizedRadius: Float

    public init(id: TargetID, normalizedRadius: Float) {
        self.id = id
        self.normalizedRadius = normalizedRadius
    }
}

public enum HitMath {
    public static func resolveTouch(
        prevTip: SIMD3<Float>,
        tip: SIMD3<Float>,
        targets: [TargetSnapshot],
        forgiveness: Float
    ) -> TouchResult? {
        var best: (distance: Float, result: TouchResult)?
        for target in targets {
            let hitRadius = target.radius + forgiveness
            guard hitRadius > 0, target.radius > 0 else { continue }
            let closest = closestPoint(on: prevTip, to: tip, near: target.center)
            let distance = simd_length(closest - target.center)
            guard distance <= hitRadius else { continue }
            let rho = inPlaneRadius(point: closest, center: target.center, normal: target.normal, radius: target.radius)
            if best == nil || distance < best!.distance {
                best = (distance, TouchResult(id: target.id, normalizedRadius: rho))
            }
        }
        return best?.result
    }

    private static func closestPoint(on start: SIMD3<Float>, to end: SIMD3<Float>, near point: SIMD3<Float>) -> SIMD3<Float> {
        let segment = end - start
        let lengthSquared = simd_length_squared(segment)
        if lengthSquared < 1e-12 { return start }
        let t = min(max(simd_dot(point - start, segment) / lengthSquared, 0), 1)
        return start + segment * t
    }

    private static func inPlaneRadius(
        point: SIMD3<Float>,
        center: SIMD3<Float>,
        normal: SIMD3<Float>,
        radius: Float
    ) -> Float {
        let n = simd_length(normal) > 1e-5 ? simd_normalize(normal) : SIMD3<Float>(0, 0, 1)
        let offset = point - center
        let inPlane = offset - n * simd_dot(offset, n)
        return max(0, simd_length(inPlane) / radius)
    }
}
