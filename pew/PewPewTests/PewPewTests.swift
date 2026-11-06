import Testing
@testable import PewPew

@Test @MainActor func appModelStartsClosed() {
    let model = AppModel()
    #expect(model.arenaState == .closed)
}
