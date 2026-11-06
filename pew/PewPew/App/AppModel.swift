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

    init() {
        let session = GameSession()
        let arena = ArenaController()
        let tracking = TrackingService()
        session.arena = arena
        arena.bind(session)
        self.session = session
        self.arena = arena
        self.tracking = tracking
        self.input = InputCoordinator(session: session, arena: arena, tracking: tracking)
    }
}
