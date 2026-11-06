import ARKit
import GestureCore
import QuartzCore

@MainActor
final class TrackingService {
    private let session = ARKitSession()
    private var handTracking: HandTrackingProvider?
    private var updatesTask: Task<Void, Never>?
    private(set) var latestLeft: HandFrame?
    private(set) var latestRight: HandFrame?
    private(set) var handTrackingAvailable = false

    func start() async {
        let results = await session.requestAuthorization(for: [.handTracking, .worldSensing])
        print("ARKit authorization: \(results)")
        guard HandTrackingProvider.isSupported else { return }
        guard results[.handTracking] == .allowed else { return }
        let provider = HandTrackingProvider()
        handTracking = provider
        do {
            try await session.run([provider])
        } catch {
            print("Hand tracking failed to start: \(error)")
            return
        }
        handTrackingAvailable = true
        updatesTask = Task { @MainActor in
            for await update in provider.anchorUpdates {
                let anchor = update.anchor
                guard anchor.isTracked else { continue }
                let frame = HandFrameAdapter.frame(from: anchor, timestamp: CACurrentMediaTime())
                switch anchor.chirality {
                case .left: latestLeft = frame
                case .right: latestRight = frame
                }
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        session.stop()
        latestLeft = nil
        latestRight = nil
        handTrackingAvailable = false
    }
}
