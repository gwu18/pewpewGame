import Foundation

public enum TutorialStep: Sendable, Equatable {
    case touch, gunPose, gunFire, done
}

public struct HUDState: Sendable, Equatable {
    public var timeRemaining: TimeInterval
    public var score: Int
    public var multiplier: Double
    public var hint: String?

    public init(timeRemaining: TimeInterval = 0, score: Int = 0, multiplier: Double = 1, hint: String? = nil) {
        self.timeRemaining = timeRemaining
        self.score = score
        self.multiplier = multiplier
        self.hint = hint
    }
}

public enum GamePhase: Equatable, Sendable {
    case lobby
    case tutorial(TutorialStep)
    case countdown(endsAt: TimeInterval)
    case playing(endsAt: TimeInterval)
    case results(RoundResult)
}
