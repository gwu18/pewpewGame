import Foundation

public enum RemovalReason: Sendable {
    case hit(HitOutcome)
    case expired
    case roundEnded
}

@MainActor
public protocol ArenaRendering: AnyObject {
    func spawnTarget(_ request: SpawnRequest, at time: TimeInterval) -> Bool
    func removeTarget(_ id: TargetID, reason: RemovalReason)
    func removeAllTargets()
}
