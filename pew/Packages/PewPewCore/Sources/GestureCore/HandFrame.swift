import Foundation
import simd

public enum Chirality: String, Sendable, Codable, Equatable {
    case left, right
}

public enum Joint: String, Sendable, Codable, CaseIterable, Equatable {
    case wrist
    case thumbKnuckle
    case thumbIntermediateBase
    case thumbIntermediateTip
    case thumbTip
    case indexMetacarpal
    case indexKnuckle
    case indexIntermediateBase
    case indexIntermediateTip
    case indexTip
    case middleMetacarpal
    case middleKnuckle
    case middleIntermediateBase
    case middleIntermediateTip
    case middleTip
    case ringMetacarpal
    case ringKnuckle
    case ringIntermediateBase
    case ringIntermediateTip
    case ringTip
    case littleMetacarpal
    case littleKnuckle
    case littleIntermediateBase
    case littleIntermediateTip
    case littleTip
    case forearmWrist
}

public struct HandFrame: Sendable, Codable, Equatable {
    public var chirality: Chirality
    public var timestamp: TimeInterval
    public var joints: [Joint: SIMD3<Float>]

    public init(chirality: Chirality, timestamp: TimeInterval, joints: [Joint: SIMD3<Float>]) {
        self.chirality = chirality
        self.timestamp = timestamp
        self.joints = joints
    }
}
