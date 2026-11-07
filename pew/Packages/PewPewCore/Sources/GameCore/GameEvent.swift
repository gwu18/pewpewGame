import Foundation

public enum GameEvent: Sendable, Equatable {
    case countdownTick(Int)
    case go
    case finalSecondsTick(Int)
    case roundEnded(RoundResult)
    case targetSpawned(TargetID)
    case targetHit(HitOutcome, TargetID)
    case targetExpired(TargetID)
    case missedShot
    case comboChanged(Double)
    case tutorialAdvanced(TutorialStep)
}

extension GameEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .countdownTick(let number): "countdown \(number)"
        case .go: "GO"
        case .finalSecondsTick(let number): "final \(number)"
        case .roundEnded(let result): "roundEnded \(result)"
        case .targetSpawned(let id): "spawn \(id.raw)"
        case .targetHit(let outcome, let id): "hit \(id.raw) +\(outcome.points) x\(outcome.multiplier)"
        case .targetExpired(let id): "expired \(id.raw)"
        case .missedShot: "miss"
        case .comboChanged(let multiplier): "combo \(multiplier)"
        case .tutorialAdvanced(let step): "tutorial \(step)"
        }
    }
}
