import GameCore
import SwiftUI

@MainActor
@Observable
final class AppModel {
    enum ArenaState: Equatable {
        case closed
        case opening
        case open
    }

    var arenaState: ArenaState = .closed
    var launchError: String?
    let session: GameSession
    let arena: ArenaController
    let tracking: TrackingService
    let input: InputCoordinator
    #if DEBUG
    let autoplay = AutoplayBot()
    /// Debug-build tools stay hidden until the lobby's "Debug" button turns them on.
    var showDebug = false
    #endif

    init() {
        let session = GameSession()
        let arena = ArenaController()
        let tracking = TrackingService()
        session.arena = arena
        session.onEvent = { print("PewPew \($0)") }
        arena.bind(session)
        self.session = session
        self.arena = arena
        self.tracking = tracking
        self.input = InputCoordinator(session: session, arena: arena, tracking: tracking)
    }
}
