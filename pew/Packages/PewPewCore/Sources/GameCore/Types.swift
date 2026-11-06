import Foundation

public struct TargetID: Hashable, Sendable {
    public let raw: Int
    public init(raw: Int) { self.raw = raw }
}

public enum TargetType: Sendable, Equatable {
    case normal, small, moving
}

public enum InputSource: Sendable, Equatable {
    case touch, blaster, lookPinch, debug
}

public enum Controls: Sendable, Equatable {
    case blaster, touch
}

public enum SpaceMode: Sendable, Equatable {
    case stayPut, roam
}

public enum Difficulty: Sendable, Equatable {
    case easy, normal, hard
}

public struct RoundConfig: Sendable, Equatable {
    public var length: TimeInterval
    public var controls: Controls
    public var space: SpaceMode
    public var difficulty: Difficulty
    public var bigTargets: Bool
    public var reduceMotion: Bool

    public init(
        length: TimeInterval = 30,
        controls: Controls = .touch,
        space: SpaceMode = .stayPut,
        difficulty: Difficulty = .normal,
        bigTargets: Bool = false,
        reduceMotion: Bool = false
    ) {
        self.length = length
        self.controls = controls
        self.space = space
        self.difficulty = difficulty
        self.bigTargets = bigTargets
        self.reduceMotion = reduceMotion
    }
}

public enum Motion: Sendable, Equatable {
    case none
    case strafe(amplitude: Float, period: TimeInterval)
}

public struct SpawnRequest: Sendable {
    public let id: TargetID
    public let type: TargetType
    public let diameter: Float
    public let lifetime: TimeInterval
    public let motion: Motion
    public let config: RoundConfig

    public init(
        id: TargetID,
        type: TargetType,
        diameter: Float,
        lifetime: TimeInterval,
        motion: Motion,
        config: RoundConfig
    ) {
        self.id = id
        self.type = type
        self.diameter = diameter
        self.lifetime = lifetime
        self.motion = motion
        self.config = config
    }
}
