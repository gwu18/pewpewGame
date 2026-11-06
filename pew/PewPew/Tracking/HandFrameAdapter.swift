import ARKit
import Foundation
import GestureCore
import simd

enum HandFrameAdapter {
    static func frame(from anchor: HandAnchor, timestamp: TimeInterval) -> HandFrame {
        var joints: [Joint: SIMD3<Float>] = [:]
        if let skeleton = anchor.handSkeleton {
            for joint in Joint.allCases {
                guard let name = arkitName(joint) else { continue }
                let handJoint = skeleton.joint(name)
                guard handJoint.isTracked else { continue }
                let transform = anchor.originFromAnchorTransform * handJoint.anchorFromJointTransform
                joints[joint] = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            }
        }
        let chirality: Chirality = anchor.chirality == .left ? .left : .right
        return HandFrame(chirality: chirality, timestamp: timestamp, joints: joints)
    }

    private static func arkitName(_ joint: Joint) -> HandSkeleton.JointName? {
        switch joint {
        case .wrist: .wrist
        case .thumbKnuckle: .thumbKnuckle
        case .thumbIntermediateBase: .thumbIntermediateBase
        case .thumbIntermediateTip: .thumbIntermediateTip
        case .thumbTip: .thumbTip
        case .indexMetacarpal: .indexFingerMetacarpal
        case .indexKnuckle: .indexFingerKnuckle
        case .indexIntermediateBase: .indexFingerIntermediateBase
        case .indexIntermediateTip: .indexFingerIntermediateTip
        case .indexTip: .indexFingerTip
        case .middleMetacarpal: .middleFingerMetacarpal
        case .middleKnuckle: .middleFingerKnuckle
        case .middleIntermediateBase: .middleFingerIntermediateBase
        case .middleIntermediateTip: .middleFingerIntermediateTip
        case .middleTip: .middleFingerTip
        case .ringMetacarpal: .ringFingerMetacarpal
        case .ringKnuckle: .ringFingerKnuckle
        case .ringIntermediateBase: .ringFingerIntermediateBase
        case .ringIntermediateTip: .ringFingerIntermediateTip
        case .ringTip: .ringFingerTip
        case .littleMetacarpal: .littleFingerMetacarpal
        case .littleKnuckle: .littleFingerKnuckle
        case .littleIntermediateBase: .littleFingerIntermediateBase
        case .littleIntermediateTip: .littleFingerIntermediateTip
        case .littleTip: .littleFingerTip
        case .forearmWrist: .forearmWrist
        }
    }
}
