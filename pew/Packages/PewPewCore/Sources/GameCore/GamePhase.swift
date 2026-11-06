import Foundation

public enum GamePhase: Equatable, Sendable {
    // M1-TEMP: lobby, countdown, tutorial, and results arrive in M2.
    case playing(endsAt: TimeInterval)
}
