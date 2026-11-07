import GameCore
import QuartzCore
import RealityKit
import SwiftUI
import simd

struct ArenaView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    private let head = SIMD3<Float>(0, 1.5, 0)

    var body: some View {
        RealityView { content, attachments in
            appModel.arena.reset()
            appModel.session.reset()
            appModel.arena.rootEntity.removeFromParent()
            content.add(appModel.arena.rootEntity)
            place(attachments)
            updateVisibility(attachments)
            await appModel.tracking.start()
            appModel.arena.lookPinchEnabled = !appModel.tracking.handTrackingAvailable
            do {
                let materials = try await TargetTextures.load()
                await appModel.arena.prepare(materials: materials)
                let arena = appModel.arena
                let session = appModel.session
                let input = appModel.input
                #if DEBUG
                let autoplay = appModel.autoplay
                let subscription = content.subscribe(to: SceneEvents.Update.self) { [weak arena, weak session, weak input, weak autoplay] _ in
                    let now = CACurrentMediaTime()
                    arena?.advance(now: now, input: input, session: session)
                    if let session, let arena {
                        autoplay?.update(now: now, session: session, arena: arena)
                    }
                }
                #else
                let subscription = content.subscribe(to: SceneEvents.Update.self) { [weak arena, weak session, weak input] _ in
                    arena?.advance(now: CACurrentMediaTime(), input: input, session: session)
                }
                #endif
                appModel.arena.retain(subscription)
                #if DEBUG
                appModel.showDebug = LaunchFlags.showDebug
                if LaunchFlags.roam { session.config.space = .roam }
                if LaunchFlags.popupDemo { arena.showPopupDemo(now: CACurrentMediaTime()) }
                if LaunchFlags.autoplay {
                    autoplay.reset()
                    autoplay.enabled = true
                    session.start(now: CACurrentMediaTime())
                }
                #endif
            } catch {
                print("Target textures failed: \(error)")
                appModel.launchError = "Couldn't open the arena. Try again."
                appModel.arenaState = .closed
                await dismissImmersiveSpace()
            }
        } update: { _, attachments in
            updateVisibility(attachments)
        } attachments: {
            Attachment(id: Panel.menu) {
                switch appModel.session.phase {
                case .results(let result):
                    ResultsPanel(result: result)
                default:
                    LobbyPanel()
                }
            }
            Attachment(id: Panel.countdown) {
                if case .countdown(let endsAt) = appModel.session.phase {
                    CountdownView(endsAt: endsAt)
                }
            }
            Attachment(id: Panel.hud) {
                PlayHUD()
            }
            #if DEBUG
            Attachment(id: Panel.debug) {
                DebugPanel()
            }
            #endif
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

    private enum Panel {
        static let menu = "menu"
        static let countdown = "countdown"
        static let hud = "hud"
        static let debug = "debug"
    }

    /// Fixed head pose until head tracking lands: menu 1.2 m ahead, 8° below eye line (plan §1.1).
    /// The HUD sits 10° *above* eye line because Touch targets fill the band below it.
    private func place(_ attachments: RealityViewAttachments) {
        let panels = appModel.session.tuning.panels
        let root = appModel.arena.rootEntity
        if let menu = attachments.entity(for: Panel.menu) {
            placeFacingHead(menu, distance: panels.lobbyDistance, pitchDegrees: panels.lobbyPitchDegrees)
            root.addChild(menu)
        }
        if let countdown = attachments.entity(for: Panel.countdown) {
            placeFacingHead(countdown, distance: panels.countdownDistance, pitchDegrees: 0)
            root.addChild(countdown)
        }
        if let hud = attachments.entity(for: Panel.hud) {
            placeFacingHead(hud, distance: 1.3, pitchDegrees: 10)
            root.addChild(hud)
        }
        if let debug = attachments.entity(for: Panel.debug) {
            debug.position = [0.62, 1.25, -1.0]
            let dx = head.x - debug.position.x
            let dz = head.z - debug.position.z
            debug.orientation = simd_quatf(angle: atan2(dx, dz), axis: [0, 1, 0])
            root.addChild(debug)
        }
    }

    private func placeFacingHead(_ entity: Entity, distance: Float, pitchDegrees: Float) {
        let pitch = pitchDegrees * .pi / 180
        entity.position = head + SIMD3(0, sin(pitch) * distance, -cos(pitch) * distance)
        entity.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
    }

    private func updateVisibility(_ attachments: RealityViewAttachments) {
        let phase = appModel.session.phase
        var inMenu = false, counting = false, playing = false
        switch phase {
        case .lobby, .results: inMenu = true
        case .countdown: counting = true
        case .playing: playing = true
        case .tutorial: break
        }
        attachments.entity(for: Panel.menu)?.isEnabled = inMenu
        attachments.entity(for: Panel.countdown)?.isEnabled = counting
        attachments.entity(for: Panel.hud)?.isEnabled = playing || counting
        #if DEBUG
        attachments.entity(for: Panel.debug)?.isEnabled = appModel.showDebug
        #endif
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
