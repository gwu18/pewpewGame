import Foundation

public enum Ring: Sendable, Equatable {
    case gold, red, none
}

public struct HitEvent: Sendable {
    public let target: TargetID
    public let source: InputSource
    public let timestamp: TimeInterval
    public let normalizedRadius: Float

    public init(target: TargetID, source: InputSource, timestamp: TimeInterval, normalizedRadius: Float) {
        self.target = target
        self.source = source
        self.timestamp = timestamp
        self.normalizedRadius = normalizedRadius
    }
}

public struct HitOutcome: Sendable, Equatable {
    public let points: Int
    public let ring: Ring
    public let reactionTime: TimeInterval
    public let multiplier: Double
    public let streak: Int

    public init(points: Int, ring: Ring, reactionTime: TimeInterval, multiplier: Double, streak: Int) {
        self.points = points
        self.ring = ring
        self.reactionTime = reactionTime
        self.multiplier = multiplier
        self.streak = streak
    }
}
