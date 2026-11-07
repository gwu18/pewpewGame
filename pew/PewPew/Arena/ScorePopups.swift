import Foundation
import GameCore
import RealityKit
import UIKit
import simd

/// Floating "+N" score tags (visual spec §4.4). A fixed pool of entities is built at Arena open;
/// text and plate meshes are cached per string, so a hit only swaps meshes and moves a slot.
@MainActor
final class ScorePopups {
    private let fx = Tuning.default.fx
    private let head = SIMD3<Float>(0, 1.5, 0)
    private let lineGap: Float = 0.35
    private let towardViewer: Float = 0.03
    private var slots: [Slot] = []
    private var layouts: [String: Layout] = [:]
    private var textMeshes: [String: MeshResource] = [:]
    private var colors: [Tint: UnlitMaterial] = [:]
    private var plateMaterial: UnlitMaterial?
    /// Bordered (bullseye) tags use an opaque plate so the Gold border doesn't tint it through.
    private var solidPlateMaterial: UnlitMaterial?

    func prepare(root: Entity) {
        colors = [
            .paper: UnlitMaterial(color: Theme.Palette.paper.uiColor),
            .red: UnlitMaterial(color: Theme.Palette.targetRed.uiColor),
            .gold: UnlitMaterial(color: Theme.Palette.bullseyeGold.uiColor),
        ]
        var plate = UnlitMaterial(color: Theme.Palette.ink.uiColor)
        plate.blending = .transparent(opacity: 0.9)
        plateMaterial = plate
        solidPlateMaterial = UnlitMaterial(color: Theme.Palette.ink.uiColor)
        slots = (0..<max(fx.popupPoolSize, 1)).map { _ in
            let slot = Slot()
            root.addChild(slot.root)
            return slot
        }
    }

    func reset() {
        for slot in slots {
            slot.root.removeFromParent()
        }
        slots.removeAll()
        colors.removeAll()
        plateMaterial = nil
        solidPlateMaterial = nil
    }

    func stopAll() {
        for index in slots.indices {
            slots[index].active = false
            slots[index].root.isEnabled = false
        }
    }

    func spawn(_ outcome: HitOutcome, at center: SIMD3<Float>, hitTime: TimeInterval, life: TimeInterval? = nil) {
        guard !slots.isEmpty, let layout = layout(for: outcome) else { return }
        let index = slots.firstIndex { !$0.active }
            ?? slots.indices.min { slots[$0].start < slots[$1].start }!
        let toHead = head - center
        let distance = max(simd_length(toHead), 0.1)
        let origin = center + toHead / distance * towardViewer
        let em = 2 * distance * tan(fx.popupAngleDeg * .pi / 360)
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        var slot = slots[index]
        slot.active = true
        slot.start = hitTime + fx.hitFlash
        slot.origin = origin
        slot.em = em
        slot.rise = reduceMotion ? 0 : fx.popupRisePerMeter * distance
        slot.life = life ?? (reduceMotion ? fx.popupReducedMotionLife : fx.popupLife)
        slot.pop = !reduceMotion
        slot.lastOpacity = -1
        slot.apply(layout, plate: layout.border == nil ? plateMaterial : solidPlateMaterial, colors: colors)
        slot.root.position = origin
        slot.root.scale = SIMD3(repeating: em * (slot.pop ? 0.6 : 1))
        slot.root.isEnabled = false
        slots[index] = slot
    }

    func update(now: TimeInterval) {
        for index in slots.indices where slots[index].active {
            let slot = slots[index]
            let age = now - slot.start
            guard age >= 0 else { continue }
            if age >= slot.life {
                slots[index].active = false
                slot.root.isEnabled = false
                continue
            }
            slot.root.isEnabled = true
            let t = Float(age / slot.life)
            let eased = 1 - pow(1 - t, 3)
            slot.root.position = slot.origin + SIMD3(0, slot.rise * eased, 0)
            slot.root.scale = SIMD3(repeating: slot.em * (slot.pop ? popScale(age) : 1))
            let fadeStart = slot.life - fx.popupFadeOut
            let opacity = age > fadeStart ? Float(1 - (age - fadeStart) / fx.popupFadeOut) : 1
            if abs(opacity - slot.lastOpacity) > 0.01 {
                slot.root.components.set(OpacityComponent(opacity: opacity))
                slots[index].lastOpacity = opacity
            }
        }
    }

    /// 0.6 → 1.1 over 60 ms (ease-out), then 1.1 → 1.0 over 60 ms.
    private func popScale(_ age: TimeInterval) -> Float {
        let step = 0.06
        if age < step {
            let t = Float(age / step)
            return 0.6 + 0.5 * (1 - (1 - t) * (1 - t))
        }
        if age < step * 2 {
            return 1.1 - 0.1 * Float((age - step) / step)
        }
        return 1
    }

    // MARK: Layout

    private func layout(for outcome: HitOutcome) -> Layout? {
        let combo = comboLabel(outcome.multiplier)
        let key = "\(outcome.ring)|\(outcome.points)|\(combo?.text ?? "")"
        if let cached = layouts[key] { return cached }

        let numberScale: Float
        let numberTint: Tint
        switch outcome.ring {
        case .gold:
            numberScale = fx.popupBullseyeAngleDeg / fx.popupAngleDeg
            numberTint = .gold
        case .red:
            numberScale = 1.15
            numberTint = .red
        case .none:
            numberScale = 1
            numberTint = .paper
        }

        var specs: [(String, Float, Tint)] = []
        if outcome.ring == .gold { specs.append(("BULLSEYE", numberScale * 0.55, .gold)) }
        specs.append(("+\(outcome.points)", numberScale, numberTint))
        if let combo { specs.append((combo.text, numberScale * 0.55, combo.tint)) }

        var lines: [Line] = []
        var width: Float = 0
        var height: Float = 0
        for (text, scale, tint) in specs {
            guard let mesh = textMesh(text) else { return nil }
            let size = mesh.bounds.extents * scale
            lines.append(Line(mesh: mesh, scale: scale, tint: tint, center: mesh.bounds.center * scale, height: size.y))
            width = max(width, size.x)
            height += size.y
        }
        height += lineGap * numberScale * Float(lines.count - 1)

        var y = height / 2
        for index in lines.indices {
            let lineHeight = lines[index].height
            lines[index].offset = SIMD3(-lines[index].center.x, y - lineHeight / 2 - lines[index].center.y, 0.01)
            y -= lineHeight + lineGap * numberScale
        }

        let plateW = width + 0.6 * numberScale
        let plateH = height + 0.5 * numberScale
        let radius = 0.12 * numberScale
        let plate = MeshResource.generatePlane(width: plateW, height: plateH, cornerRadius: radius)
        let border = outcome.ring == .gold
            ? MeshResource.generatePlane(width: plateW + 0.3 * numberScale, height: plateH + 0.3 * numberScale, cornerRadius: radius * 1.5)
            : nil
        let layout = Layout(lines: lines, plate: plate, border: border)
        layouts[key] = layout
        return layout
    }

    private func textMesh(_ text: String) -> MeshResource? {
        if let cached = textMeshes[text] { return cached }
        let font = UIFont(name: Theme.Fonts.pixelName, size: 1) ?? .systemFont(ofSize: 1, weight: .heavy)
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.03,
            font: font,
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        textMeshes[text] = mesh
        return mesh
    }

    private func comboLabel(_ multiplier: Double) -> (text: String, tint: Tint)? {
        guard multiplier > 1 else { return nil }
        let value = multiplier == multiplier.rounded() ? String(Int(multiplier)) : String(format: "%.1f", multiplier)
        return ("×\(value)", multiplier >= 2 ? .gold : .paper)
    }

    // MARK: Types

    fileprivate enum Tint: Hashable { case paper, red, gold }

    private struct Line {
        var mesh: MeshResource
        var scale: Float
        var tint: Tint
        var center: SIMD3<Float>
        var height: Float
        var offset = SIMD3<Float>(repeating: 0)
    }

    private struct Layout {
        var lines: [Line]
        var plate: MeshResource
        var border: MeshResource?
    }

    private struct Slot {
        static let maxLines = 3
        let root = Entity()
        let plate = ModelEntity()
        let border = ModelEntity()
        let lines: [ModelEntity] = (0..<maxLines).map { _ in ModelEntity() }
        var active = false
        var start: TimeInterval = 0
        var life: TimeInterval = 0
        var origin = SIMD3<Float>(repeating: 0)
        var em: Float = 0
        var rise: Float = 0
        var pop = true
        var lastOpacity: Float = -1

        init() {
            root.name = "scorePopup"
            root.isEnabled = false
            root.components.set(BillboardComponent())
            border.position.z = -0.01
            root.addChild(border)
            root.addChild(plate)
            for line in lines { root.addChild(line) }
        }

        func apply(_ layout: Layout, plate material: UnlitMaterial?, colors: [Tint: UnlitMaterial]) {
            plate.model = material.map { ModelComponent(mesh: layout.plate, materials: [$0]) }
            if let mesh = layout.border, let gold = colors[.gold] {
                border.model = ModelComponent(mesh: mesh, materials: [gold])
                border.isEnabled = true
            } else {
                border.isEnabled = false
            }
            for (index, entity) in lines.enumerated() {
                guard index < layout.lines.count, let color = colors[layout.lines[index].tint] else {
                    entity.isEnabled = false
                    continue
                }
                let line = layout.lines[index]
                entity.model = ModelComponent(mesh: line.mesh, materials: [color])
                entity.position = line.offset
                entity.scale = SIMD3(repeating: line.scale)
                entity.isEnabled = true
            }
        }
    }
}
