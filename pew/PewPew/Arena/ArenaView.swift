import GameCore
import QuartzCore
import RealityKit
import SwiftUI
import simd

struct ArenaView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RealityView { content, attachments in
            appModel.arena.reset()
            appModel.session.reset()
            appModel.arena.rootEntity.removeFromParent()
            content.add(appModel.arena.rootEntity)
            if let exit = attachments.entity(for: "exit") {
                exit.position = [0.4, 1.2, -1.2]
                appModel.arena.rootEntity.addChild(exit)
            }
            await appModel.tracking.start()
            appModel.arena.lookPinchEnabled = !appModel.tracking.handTrackingAvailable
            do {
                let materials = try await TargetTextures.load()
                await appModel.arena.prepare(materials: materials)
                let arena = appModel.arena
                let session = appModel.session
                let input = appModel.input
                let subscription = content.subscribe(to: SceneEvents.Update.self) { [weak arena, weak session, weak input] _ in
                    arena?.advance(now: CACurrentMediaTime(), input: input, session: session)
                }
                appModel.arena.retain(subscription)
            } catch {
                print("Target textures failed: \(error)")
                appModel.launchError = "Couldn't open the arena. Try again."
                appModel.arenaState = .closed
                await dismissImmersiveSpace()
            }
        } attachments: {
            Attachment(id: "exit") {
                Button("Exit Arena") {
                    Task { await dismissImmersiveSpace() }
                }
            }
        }
        .gesture(lookPinch)
        .onDisappear {
            appModel.tracking.stop()
            appModel.arena.reset()
            appModel.session.reset()
            appModel.arenaState = .closed
            openWindow(id: "launcher")
        }
    }

    private var lookPinch: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard !appModel.tracking.handTrackingAvailable else { return }
                guard let id = appModel.arena.targetID(for: value.entity) else { return }
                guard let root = appModel.arena.targetRoot(for: value.entity) else { return }
                let local = value.convert(value.location3D, from: .local, to: root)
                let rho = max(0, simd_length(SIMD2<Float>(local.x, local.y)) / 0.5)
                appModel.session.registerHit(
                    HitEvent(
                        target: id,
                        source: .lookPinch,
                        timestamp: CACurrentMediaTime(),
                        normalizedRadius: rho
                    )
                )
            }
    }
}
