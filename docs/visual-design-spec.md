# PewPew — Visual Design Spec (v1)

**Owner:** aesthetics / visual design · **Implements:** Sonnet, Gary (Arena/FX), Kevin (UI) · **Written:** Fri Nov 6, 2026
**Builds on:** `docs/sonnet-build-plan.md` (the source of truth for gameplay and architecture; this doc refines plan §2.6, §5, §7, §11 FX rows) and `docs/opus-design-brief.md` §7.
**Locked and unchanged here:** Apple Vision Pro, Swift + RealityKit + SwiftUI, mixed `ImmersiveSpace`, 8-bit archery targets, arcade-leaning, kids + adults, timed 30/60 s rounds, touch first and then the finger-gun "blaster". No gameplay rules or architecture change in this doc. Where it changes a §5 visual decision, §1.3 lists the change and the reason.

> **Repo layout.** Code lives at [github.com/gwu18/pewpewGame](https://github.com/gwu18/pewpewGame). **The Xcode project is in `pew/`, not at the repo root.** Every code path in this doc is written from the repo root. The build plan's §8.1 paths like `PewPew/UI/Theme.swift` mean **`pew/PewPew/UI/Theme.swift`**, and `Packages/PewPewCore/...` means **`pew/Packages/PewPewCore/...`**. The repo-root `docs/` folder holds docs: this file sits next to `docs/sonnet-build-plan.md`.

**Mockups** (in [`docs/visual/`](visual/), rendered from code with exact palette values):

| File | Shows |
| --- | --- |
| [`target-design-sheet.png`](visual/target-design-sheet.png) | All target variants, 3D build, states, ring-to-score map, reading distances, color-vision check, palette |
| [`lobby-panel.png`](visual/lobby-panel.png) | Lobby panel with redlines |
| [`hud-in-room.png`](visual/hud-in-room.png) | In-round HUD, hovered target, beam, and bullseye burst over a passthrough room, plus the HUD at 1:1 |
| [`results-panel.png`](visual/results-panel.png) | Results panel with redlines |
| [`countdown-and-tutorial.png`](visual/countdown-and-tutorial.png) | Countdown and the tutorial card |
| [`vfx-storyboard.png`](visual/vfx-storyboard.png) | Frame-by-frame spawn, hit (outer, red, bullseye), expire, miss, fire/tracer |
| [`sprites/*.png`](visual/sprites/) | Source sprites (16× nearest upscales): faces, reticles, brackets, chevron, muzzle star, rings, hand frames |

The room backdrop is AI-generated. Inter stands in for SF Pro in the mockups.

**Image location:** the mockups and sprites live in [`docs/visual/`](visual/) and [`docs/visual/sprites/`](visual/sprites/), next to this doc. The Sonnet prompts in §9 refer to them as `docs/visual/...`. They are reference images and are not app resources.

**Changelog**
- **Fri Nov 6, 2026 (evening) — menus + score popups after Gary's device test.** Launcher and in-Arena lobby rebuilt to §5.3 (the old Arena "menu" was the debug panel). Added results panel, countdown disc and HUD. Score popups (§4.4) now specified in full, including a combo line, and shipped. New §5.5: debug controls are hidden in player-facing builds. HUD moved above eye line while Touch is the only mode (§5.3). Primary buttons draw their own Button Red fill (§5.4). Press Start 2P is bundled.
- Fri Nov 6, 2026 — v1.

The Swift snippets in §3 and §8 weren't compiled here (no Swift toolchain in this environment). `PixelTargetMap` follows the reference generator that produced the golden map exactly, so treat compile errors as typos, not design changes.

---

## 1. Art direction

### 1.1 In a few sentences
**"Native shell, arcade soul."** Everything you *operate* (panels, pickers, buttons) is honest visionOS: glass, system controls, gaze and pinch hover. Everything you *play with* is a chunky 8-bit object that physically sits in your room: a pixel-art archery face on a real slab with thickness, a soft floor shadow, and stair-stepped edges you can see. Juice comes from timing, pixel shards, flashes, and sound, never from glow, bloom, gradients, or purple neon. Each color has one job, and anything that has to read on a white wall gets an Ink outline.

### 1.2 Three reference moods
1. **Summer-fair archery booth.** Painted plywood targets, warm off-white paper, saturated primaries, a satisfying *thock* and *ding*. This mood sets the palette and the sound.
2. **NES-era sprite clarity (Duck Hunt, Excitebike title cards).** One-pixel outlines, two-frame animation, hard drop shadows, chunky type. This mood sets pixel rules, Press Start 2P, and 2-frame tutorial sprites.
3. **Toy-box physicality (vinyl toys, LEGO, Nintendo Labo).** Objects with real depth that catch room light and cast shadows, so it feels like a toy on your coffee table rather than a sticker on your eyes. This mood sets the voxel body, PBR sides, and grounding shadow.

### 1.3 Changes to build plan §5 (and §2.6), with reasons

| # | Plan says | This spec says | Why |
| --- | --- | --- | --- |
| 1 | Face = `generateCylinder` cap + rim cylinder r×1.04 | Face = **square plane with alpha cutout** + **extruded pixel-silhouette body** (`MeshDescriptor`), depth 0.075·D. Plan version is the fallback. | A smooth cylinder fights a stair-step texture at the edge. Cutout + extrusion makes the *silhouette itself* pixel art ("pixel target, physical object"). Plane UVs are guaranteed; cylinder cap UVs aren't documented. |
| 2 | "5 rings + 1-px Ink outline" (ambiguous) | Outline on the **outer edge only**, plus **one Ink separator on the red/blue edge**. Cosmetic bands fixed at blue 0.40–0.66, ink 0.66–0.79, paper 0.79–1.0. | Bands are only 3.2 px on a 32 grid, so outlining every ring eats a third of each. Red vs. blue luminance contrast is only 1.20:1, and that edge is the scoring "bonus" boundary, so it gets the separator. Gold (≤0.20) and red (≤0.40) edges match scoring exactly. |
| 3 | Hover = mint halo disc behind target | Hover = **mint pixel lock-on brackets** (4 L-shapes) + scale 1.06 | A disc behind the target reads as a glow, which §5.1 bans. Brackets read "locked on" instantly and don't change the target's silhouette. |
| 4 | Reticle ring, filled vs. hollow | **Pixel sprite reticle with an Ink outline**. Cocked = solid ring + center dot. Uncocked = **ring broken into 4 arcs**. Miss = gray for 120 ms. | Mint on a white wall is 1.22:1 and mint on gold is 1.03:1, so without an outline the reticle vanishes over the bullseye. A shape change (not just fill) survives color-vision deficiency. |
| 5 | 8 mm mint sphere armed indicator | **8 mm mint cube**, slow spin | Matches the pixel/voxel language (shards are cubes too). |
| 6 | Beam 2 mm × 0.6 m at 35 % | Beam **2.5 mm, 3 × 0.2 m segments at 60 / 35 / 15 %** | 35 % mint disappears on bright walls. A fading beam points without drawing a hard line to infinity. |
| 7 | Tracer 1.5 mm, 70 ms | Tracer **4 mm, 90 ms**, thins to 25 % width while fading | 1.5 mm at 2.5 m is about one display pixel, so it's invisible. |
| 8 | Popup "+150" Gold 3D text for all | **Press Start 2P 3D text on an Ink "score tag" plate**. Color by ring: none = Paper, red = Target Red, bullseye = Gold (+ Gold tag border, "BULLSEYE" line). Combo hits add a small "×1.5" / "×2" line. Sized by angle, not meters. | One color for all wastes the ring signal. The storyboard showed light text on a white wall needs a plate; a drop shadow alone failed. |
| 9 | Shards via `Entity.move(to:)` | Shards via **per-frame physics in `ArenaController.updateFX(now:)`** (velocity + gravity + spin + shrink), counts by ring (10 / 14 / 20) | `move(to:)` gives straight lines. A tiny integrator gives arcade arcs, costs nothing for ≤ 48 entities, and the frame driver already exists (plan §6.4). |
| 10 | Spawn scale 0 → 1.1 → 1.0 | Spawn **0.6 → 1.12 → 1.0** + **Paper ping ring** | Plan §3.4 counts reaction time from the frame the target is visible at 60 % scale, so the animation must start at 0.6. The ping ring helps peripheral spotting (Roam). |
| 11 | Expire: tint gray + shrink | Adds an **expire warning**: last 0.6 s swaps gray/normal every 150 ms | Visual only, no rule change. It's fairer and very arcade; kids learn "hurry". Kept under 3.3 Hz for photosensitivity. |
| 12 | Variants differ only in size and motion | **Small: 1-px gold trim** inside the outline. **Moving: pixel chevron fins** on the strafe axis. | Points differ (100/150/200). First-timers and kids need a visual "worth more" cue and a "this one moves" cue. |
| 13 | Primary button tint Target Red | Primary button fill **Button Red `#C8321E`** | White on `#E8402A` is 4.04:1 (fails AA). On `#C8321E` it's 5.34:1. Target Red stays on the target and logo. |
| 14 | HUD numbers SF Pro Rounded | HUD **time and score in Press Start 2P** (64 / 32 pt). Results stat grid stays SF Pro Rounded. | The HUD is the arcade cabinet; pixel digits at ≥ 32 pt are fully legible at 1.1 m. Dense stats stay in SF for readability. |
| 15 | HUD ~360×140, lobby ~600×560, results 640×520 | HUD **460×128**, lobby **600×700**, results **640×600** | Measured in the mockups: 5-digit score + combo chip needs 460 pt. Five lobby rows at 20 pt plus a footer need 700 pt. |
| 16 | Countdown digits floating | Countdown digits on a **300 pt glass disc** | Gold on a white wall is about 1.2:1. Glass guarantees contrast in any room. |
| 17 | 16-bit 44.1 kHz WAV | **48 kHz** 16-bit mono WAV, **hybrid** chiptune + foley layers, loudness targets (§6) | 48 kHz is the device's native rate (no resample). Pure chiptune sounds thin through the Vision Pro's speakers; a real transient adds physicality and helps you place the sound. |

Everything else in plan §5 stands: unlit face, `GroundingShadowComponent`, idle bob ±1 cm / 2 s, no particle emitter for MVP, no glow, Press Start 2P for display type.

---

## 2. Palette

All values are sRGB. Each color has one job; don't borrow colors across roles.

| Token | Hex | sRGB 0–1 | Role |
| --- | --- | --- | --- |
| `paper` | `#F4F1E8` | 0.957, 0.945, 0.910 | Target outer ring; pixel text on glass/tags; ×1.5 chip fill; spawn ping |
| `ink` | `#1B1B1F` | 0.106, 0.106, 0.122 | All outlines, ring 4, voxel body, score-tag plates, hard shadows, chip text |
| `ringBlue` | `#2B6FD6` | 0.169, 0.435, 0.839 | Ring 3 only |
| `targetRed` | `#E8402A` | 0.910, 0.251, 0.165 | Ring 2, logo wordmark, red-ring popup text. **Never body text on glass** (2.25:1 worst case). |
| `bullseyeGold` | `#FFC93C` | 1.000, 0.788, 0.235 | Bullseye, BULLSEYE popup, results hero score, countdown digits, last-5 s timer, ×2 chip, Small trim |
| `goldShine` | `#FFF1B8` | 1.000, 0.945, 0.722 | 2 shine pixels on the gold; bullseye second flash frame |
| `blasterMint` | `#3EE6C1` | 0.243, 0.902, 0.757 | **Blaster only**: armed cube, beam, tracer, reticle, lock-on brackets. Always with an Ink outline when it's a sprite. |
| `missGray` | `#9AA0A6` | 0.604, 0.627, 0.651 | Miss puff, reticle miss flash, expired tint |
| `grayRampLo` / `grayRampHi` | `#5F6368` / `#C9CDD1` | — | Expired face: luminance of each face color mapped onto this ramp |
| `buttonRed` | `#C8321E` | 0.784, 0.196, 0.118 | Primary button fill (START, PLAY AGAIN) |
| `flashWhite` | `#FFFFFF` | 1, 1, 1 | Hit flash (Ink outline kept), muzzle star core |
| System `.primary` / `.secondary` | (vibrancy) | — | All SF Pro text on glass. Let visionOS handle legibility. |

No red for misses and no buzzers. "Danger" doesn't exist in this game; misses are gray and quiet.

### 2.1 Contrast checks (WCAG ratio)
Assumptions: visionOS glass behaves like `#26262A` (dim room) to `#48484C` (bright room, worst case). Passthrough "white wall" is `#E6E2DA` and "dark wall" is `#3A3631`.

| Pair | Ratio | Verdict / rule |
| --- | --- | --- |
| Paper / Ink | 15.2 | Outline vs. outer ring: the target reads on **any** wall (Ink on a white wall 13.3, Paper on a dark wall 10.6) |
| Gold / Red | 2.63 | Fine for adjacent rings (large areas + hue) |
| Red / Blue | **1.20** | Too low on luminance, so the **Ink separator** on this edge is mandatory |
| Blue / Ink | 3.55 | OK for ring areas |
| Mint / white wall | **1.22** | Mint sprites need an Ink outline. Beam is segmented and accepted as a hint (not load-bearing). |
| Mint / Gold | **1.03** | Reticle needs an Ink outline (it sits on the bullseye) |
| Mint / Ink | 10.9 | The outline works |
| White / glass (worst) | 9.1 | SF text OK |
| Gold / glass (worst) | 5.93 | Gold pixel text OK at any allowed size |
| Paper / glass (worst) | 8.06 | OK |
| Red / glass (worst) | **2.25** | Red only for the ≥ 48 pt logo with a 4 pt Ink hard shadow, never for text |
| White / Target Red | 4.04 | Fails AA, hence `buttonRed` |
| White / Button Red | 5.34 | Passes AA |
| Gray / glass (dark) | 5.71 | OK |

Color-vision simulation (Machado 2009) is on the target sheet. Deutan/protan see red as olive and blue stays blue, so rings stay distinct with the separator. Under tritan, blue and mint both go cyan-teal, which is why the reticle and brackets rely on shape plus outline, never hue alone.

---

## 3. The 8-bit target

### 3.1 Grid and pixel map
- **One 32×32 map for every variant and size.** One texture is cached and reused; Big Targets and difficulty only scale the entity.
- Baked into a **512×512 CGImage** (each pixel = a 16×16 block, nearest by construction), as in plan §5.1.
- Ring bands as a fraction of radius ρ (pixel center, 4×4 supersampled, majority vote, ties go to the inner ring): **gold ≤ 0.20, red ≤ 0.40** (scoring-exact), blue ≤ 0.66, ink ≤ 0.79, paper ≤ 1.00. Outside = transparent.
- **Outline:** any filled pixel with a 4-neighbor outside the disc becomes Ink.
- **Bonus separator:** any blue pixel with a red 4-neighbor becomes Ink (drawn on the blue side so the red zone keeps its full size).
- **Shine:** pixels (x 14, y 13) and (x 13, y 14) become `goldShine`.
- **Golden map, Normal** (`.` clear, `K` ink, `P` paper, `B` blue, `R` red, `G` gold, `g` shine; row 0 is the top):

```
............KKKKKKKK............
.........KKKPPPPPPPPKKK.........
.......KKPPPPPPPPPPPPPPKK.......
......KPPPPPPPKKKKPPPPPPPK......
.....KPPPPPKKKKKKKKKKPPPPPK.....
....KPPPPKKKKKBBBBKKKKKPPPPK....
...KPPPPKKKBBBBBBBBBBKKKPPPPK...
..KPPPPKKKBBBBBBBBBBBBKKKPPPPK..
..KPPPKKKBBBBBBBBBBBBBBKKKPPPK..
.KPPPKKKBBBBBKKKKKKBBBBBKKKPPPK.
.KPPPKKBBBBKKRRRRRRKKBBBBKKPPPK.
.KPPKKBBBBKRRRRRRRRRRKBBBBKKPPK.
KPPPKKBBBBKRRRRRRRRRRKBBBBKKPPPK
KPPPKKBBBKRRRRgGGGRRRRKBBBKKPPPK
KPPKKBBBBKRRRgGGGGGRRRKBBBBKKPPK
KPPKKBBBBKRRRGGGGGGRRRKBBBBKKPPK
KPPKKBBBBKRRRGGGGGGRRRKBBBBKKPPK
KPPKKBBBBKRRRGGGGGGRRRKBBBBKKPPK
KPPPKKBBBKRRRRGGGGRRRRKBBBKKPPPK
KPPPKKBBBBKRRRRRRRRRRKBBBBKKPPPK
.KPPKKBBBBKRRRRRRRRRRKBBBBKKPPK.
.KPPPKKBBBBKKRRRRRRKKBBBBKKPPPK.
.KPPPKKKBBBBBKKKKKKBBBBBKKKPPPK.
..KPPPKKKBBBBBBBBBBBBBBKKKPPPK..
..KPPPPKKKBBBBBBBBBBBBKKKPPPPK..
...KPPPPKKKBBBBBBBBBBKKKPPPPK...
....KPPPPKKKKKBBBBKKKKKPPPPK....
.....KPPPPPKKKKKKKKKKPPPPPK.....
......KPPPPPPPKKKKPPPPPPPK......
.......KKPPPPPPPPPPPPPPKK.......
.........KKKPPPPPPPPKKK.........
............KKKKKKKK............
```

- **Small variant map** = Normal map, then every non-outline pixel that is 4-adjacent to an outline pixel becomes Gold (a 1-px gold trim; first rows `............KKKKKKKK............` / `.........KKKGGGGGGGGKKK.........` / `.......KKGGGPPPPPPPPGGGKK.......`).
- **Expired map** = the Normal (or Small) map with each color replaced by `lerp(grayRampLo, grayRampHi, relativeLuminance(color))`.
- **Flash map** = the outline pixels stay Ink and every other filled pixel is `flashWhite` (bullseye's second frame uses `goldShine`). Keeping the outline means the flash still reads on a white wall.

Paste-ready generator (pure Swift; put it in `pew/PewPew/Arena/PixelTargetTexture.swift`; it reproduces the golden map exactly):

```swift
enum FacePixel: UInt8 { case clear, gold, shine, red, blue, ink, paper }

enum PixelTargetMap {
    static let grid = 32
    static let ringEdges: [(Float, FacePixel)] = [(0.20, .gold), (0.40, .red), (0.66, .blue), (0.79, .ink), (1.00, .paper)]
    private static let tiePriority: [FacePixel: Int] = [.clear: 0, .paper: 1, .ink: 2, .blue: 3, .red: 4, .gold: 5]

    static func normal() -> [[FacePixel]] {
        let n = grid, r = Float(n) / 2
        func ring(_ px: Float, _ py: Float) -> FacePixel {
            let d = ((px - r) * (px - r) + (py - r) * (py - r)).squareRoot() / r
            if d > 1 { return .clear }
            return ringEdges.first { d <= $0.0 }!.1
        }
        var base = Array(repeating: Array(repeating: FacePixel.clear, count: n), count: n)
        for y in 0..<n { for x in 0..<n {
            var votes: [FacePixel: Int] = [:]
            for sy in 0..<4 { for sx in 0..<4 {
                votes[ring(Float(x) + (Float(sx) + 0.5) / 4, Float(y) + (Float(sy) + 0.5) / 4), default: 0] += 1
            } }
            base[y][x] = votes.max { ($0.value, tiePriority[$0.key]!) < ($1.value, tiePriority[$1.key]!) }!.key
        } }
        func at(_ m: [[FacePixel]], _ x: Int, _ y: Int) -> FacePixel { (0..<n).contains(x) && (0..<n).contains(y) ? m[y][x] : .clear }
        var out = base
        for y in 0..<n { for x in 0..<n where base[y][x] != .clear {
            let ns = [at(base, x + 1, y), at(base, x - 1, y), at(base, x, y + 1), at(base, x, y - 1)]
            if ns.contains(.clear) { out[y][x] = .ink }
            else if base[y][x] == .blue && ns.contains(.red) { out[y][x] = .ink }
        } }
        out[13][14] = .shine; out[14][13] = .shine
        return out
    }

    static func isOutline(_ m: [[FacePixel]], _ x: Int, _ y: Int) -> Bool {
        let n = m.count
        guard m[y][x] != .clear else { return false }
        return [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
            let xx = x + dx, yy = y + dy
            return !(0..<n).contains(xx) || !(0..<n).contains(yy) || m[yy][xx] == .clear
        }
    }

    static func small() -> [[FacePixel]] {
        let m = normal(), n = m.count
        var out = m
        for y in 0..<n { for x in 0..<n where m[y][x] != .clear && !isOutline(m, x, y) {
            let touchesOutline = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
                (0..<n).contains(x + dx) && (0..<n).contains(y + dy) && isOutline(m, x + dx, y + dy)
            }
            if touchesOutline { out[y][x] = .gold }
        } }
        return out
    }

    static func ascii(_ m: [[FacePixel]]) -> String {
        let ch: [FacePixel: Character] = [.clear: ".", .gold: "G", .shine: "g", .red: "R", .blue: "B", .ink: "K", .paper: "P"]
        return m.map { String($0.map { ch[$0]! }) }.joined(separator: "\n")
    }
}
```
In DEBUG, `assert(PixelTargetMap.ascii(PixelTargetMap.normal()) == goldenNormal)` once at texture creation (paste the golden map above as a string literal). Draw into the CGImage with `y` flipped (CG origin is bottom-left), then **check on device that the shine sits at the upper-left**. If it's mirrored, flip the plane's UVs, not the map.

### 3.2 Building the 3D object
Per target, a parent `Entity` (facing +Z) with:

| Part | Build | Material |
| --- | --- | --- |
| **Face** | `MeshResource.generatePlane(width: D, height: D)` (XY plane, faces +Z) at z = 0 | `UnlitMaterial` with the face texture; `opacityThreshold = 0.5` (alpha cutout, no transparency sorting). Flag: if `opacityThreshold` isn't on `UnlitMaterial` in the SDK, use `blending = .transparent(opacity: 1)` and say so. |
| **Body** | Extruded silhouette of the same 32² map (§3.3) from z = −0.0005 to z = −0.075·D | `PhysicallyBasedMaterial`: baseColor Ink, roughness 0.55, metallic 0, `faceCulling = .none` (guards against winding mistakes) |
| **Shadow** | `GroundingShadowComponent(castsShadow: true)` on the body | — |
| **Fins** (Moving only) | Two planes, 0.16·D square, chevron sprite (Paper + Ink outline), at x = ±(D/2 + 0.12·D), z = 0, the left one mirrored | `UnlitMaterial` + cutout |
| **Brackets** (hover, blaster) | One plane 1.25·D square with the brackets sprite at z = +0.004, hidden by default | `UnlitMaterial` + cutout |

- **Thickness:** 0.075·D, which is 3.0 cm on Normal Blaster (same as plan `rimDepth`), 1.95 cm on Small, and 1.5 cm on Touch. From the front only the face shows; at an angle (Roam, walls) you see the solid Ink slab with pixel stair-steps.
- **Glow:** none. No emissive, no bloom, no halo. The unlit face already "glows" in dim rooms, which is enough.
- **Lighting:** the face ignores room light (always readable); the body picks it up (feels physical). That split *is* the art direction.
- **Textures to cache (4):** `normal`, `small`, `normalGray`, `smallGray`. Flash = swap the face material to a cached `UnlitMaterial` using the **flash texture** (white + Ink outline, alpha-identical), plus `flashGold` for bullseye frame 2. Build all six at Arena open.
- **Fallback:** if `MeshDescriptor` gives trouble, use plan §5.1's cylinder rim behind the cutout plane (rim radius 0.5·D, depth 0.075·D, Ink PBR).

### 3.3 Body extrusion (paste-ready sketch)
```swift
static func bodyMesh(_ m: [[FacePixel]], diameter D: Float, depth: Float) throws -> MeshResource {
    let n = m.count, t = D / Float(n)
    func filled(_ x: Int, _ y: Int) -> Bool { (0..<n).contains(x) && (0..<n).contains(y) && m[y][x] != .clear }
    var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], idx: [UInt32] = []
    func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>, _ nn: SIMD3<Float>) {
        let i = UInt32(pos.count); pos += [a, b, c, d]; nor += [nn, nn, nn, nn]; idx += [i, i + 1, i + 2, i, i + 2, i + 3]
    }
    let zf: Float = -0.0005, zb = -depth
    for y in 0..<n { for x in 0..<n where filled(x, y) {
        let x0 = (Float(x) / Float(n) - 0.5) * D, x1 = x0 + t
        let y1 = (0.5 - Float(y) / Float(n)) * D, y0 = y1 - t
        quad([x0, y0, zb], [x0, y1, zb], [x1, y1, zb], [x1, y0, zb], [0, 0, -1])                          // back
        if !filled(x - 1, y) { quad([x0, y0, zf], [x0, y1, zf], [x0, y1, zb], [x0, y0, zb], [-1, 0, 0]) } // left
        if !filled(x + 1, y) { quad([x1, y0, zb], [x1, y1, zb], [x1, y1, zf], [x1, y0, zf], [1, 0, 0]) }  // right
        if !filled(x, y - 1) { quad([x0, y1, zb], [x0, y1, zf], [x1, y1, zf], [x1, y1, zb], [0, 1, 0]) }  // top
        if !filled(x, y + 1) { quad([x0, y0, zf], [x0, y0, zb], [x1, y0, zb], [x1, y0, zf], [0, -1, 0]) } // bottom
    } }
    var desc = MeshDescriptor(name: "targetBody")
    desc.positions = MeshBuffers.Positions(pos)
    desc.normals = MeshBuffers.Normals(nor)
    desc.primitives = .triangles(idx)
    return try MeshResource.generate(from: [desc])
}
```
About 800 back quads plus about 120 side quads; build **once per map** at unit diameter and scale the entity (D is applied via `scale`, depth scales with it).

### 3.4 Size variants

| Variant | Map | Blaster D | Touch D | Extras | Pts |
| --- | --- | --- | --- | --- | --- |
| Normal | normal | 0.40 m | 0.20 m | — | 100 |
| Small | small (gold trim) | 0.26 m | 0.14 m | — | 150 |
| Moving | normal | 0.40 m | 0.20 m | chevron fins on the strafe axis | 200 |

The difficulty multiplier (×1.15 / ×0.85) and Big Targets (×1.4) scale the whole entity, including fins and brackets.

### 3.5 How it reads (Vision Pro ≈ 34 display px per degree; an approximation)

| Case | Angular size | Display px per map pixel | Read |
| --- | --- | --- | --- |
| Touch Normal 0.20 m at 0.5 m | 22.6° | ~24 | Very chunky and toy-like; stair-steps are obvious, which is the charm. Ring edges are 1 pixel = 6 mm, easy to aim a fingertip. |
| Blaster Normal at 1.8 m | 12.7° | ~13.5 | Crisp, iconic |
| Blaster Normal at 3.2 m | 7.2° | ~7.6 | Crisp; outline ≈ 0.22°. Bullseye ≈ 1.4° wide. |
| Small at 3.2 m | 4.7° | ~5 | Gold trim still visible |
| Small, Hard (×0.85) at 3.2 m | 4.0° | ~4.2 | Worst case; still above the 1-px-outline legibility floor (~3 px) |

Rule: **never draw a pixel smaller than ~3 display px.** That holds for every configured case. If someone adds a size below 0.18 m at 3.2 m, switch that variant to a 24-grid map.

---

## 4. VFX

### 4.1 Aim visuals (Blaster)

| Element | Spec | Build |
| --- | --- | --- |
| Armed cube | 8 mm, `blasterMint` unlit, at the index tip, rotated 45° about the aim axis, spins 90°/s (static under Reduce Motion). Shown only while armed. | `generateBox(size: 0.008)` |
| Beam | 2.5 mm thick, 3 segments × 0.2 m from the tip, opacity **0.60 / 0.35 / 0.15** (Increase Contrast: 0.9 / 0.7 / 0.5) | 3 `generateBox` children + `OpacityComponent` |
| Reticle | Pixel sprite (`reticle_cocked` / `reticle_uncocked`), constant **1.2°** (Big Targets 1.6°): size = 2·d·tan(0.6°). On the hovered target at the impact point (+2 mm along the normal), else 3 m along the ray. Always faces the head. | Plane + cutout, `BillboardComponent` (visionOS 2; fallback: `look(at:)` each frame) |
| Lock-on | Hovered target scales to 1.06 over 60 ms; brackets pop 1.2→1.0 in 80 ms (fade only under Reduce Motion) | Brackets plane (§3.2) |
| Miss flash | Reticle swaps to `reticle_miss` (gray) for 120 ms | Texture swap |

### 4.2 Event table (all times in ms; all values in `Tuning.FX`, §8.2)

| Event | Sequence | Particles | Audio |
| --- | --- | --- | --- |
| **Spawn** | Scale **0.6 → 1.12** (90, ease-out cubic) **→ 1.0** (60, ease-in-out). Paper ping ring (0.5 D plane, ring sprite) scales 1.0 → 1.6 while opacity 0.8 → 0 over 300. Reduce Motion: no overshoot (0.6 → 1.0 over 150), ping fades without growing. | — | `spawn` at target |
| **Hit, outer** (ρ > 0.40) | 0–40 face shows the **flash** texture; 40–80 target scales 1.0 → 1.15 then is removed at 80. Shards emit at 40. Popup "+N" (Paper on Ink tag) appears at 40. | **10** shards, life 350 | `hit` |
| **Hit, red** (0.20 < ρ ≤ 0.40) | Same as outer; popup text Target Red, tag scale ×1.15 | **14** shards, life 420, speed ×1.1 | `hit_red` (or `hit` +3 semitones) |
| **Hit, bullseye** (ρ ≤ 0.20) | 0–40 flash white, 40–80 `flashGold`, scale 1.0 → 1.2, removed at 80. **Gold shockwave** ring sprite (plane at the face) scales 1.0 → 2.2·D, opacity 1 → 0, 260, ease-out. Popup two lines "BULLSEYE" / "+N" Gold on an Ink tag with a Gold border. HUD score digits flash Gold for 200. | **20** shards (6 are Gold/Shine "sparkles" with life ×1.5), life 520, speed ×1.3 | `bullseye` |
| **Expire warning** | From `expiresAt − 600`: face swaps gray/normal every 150 (2 full cycles). Reduce Motion: switch to gray once at −600, no blinking. | — | — |
| **Expire** | Face gray; scale 1 → 0 (ease-in quad) while dropping 3 cm, 200 | 4 gray shards, gravity only, life 250 | `expire` at target |
| **Round end** | Remaining targets scale 1 → 0 in 120, no shards, no sound per target | — | `end` (HUD) |
| **Fire** | Muzzle star (2.4 cm, Paper/Gold sprite) at the tip, 0–30 scale 1.0, 30–60 scale 0.6, then hidden. Tracer: box from tip to impact (or ray end), **4 mm**, opacity 1 → 0, thickness ×1 → ×0.25 over 90. Reticle kick 1.4 → 1.0 over 120. | — | `pew` at hand |
| **Missed shot** | At the ray end (impact distance or 3 m): gray puff ring scales 1.0 → 1.8 over 180; reticle miss flash 120 | **6** gray shards, size 0.004·distance, life 220, radial spread only | `miss` at ray end |
| **Combo up** | HUD chip appears/changes, scale 1.3 → 1.0, 200 (spring); ×2 chip turns Gold | — | `combo` |
| **Final 5 s** | Time digits turn Gold and pulse scale 1.0 → 1.08 → 1.0 over 300 on each tick (color only under Reduce Motion) | — | `tick` |

### 4.3 Shards: build and physics
- **Pool:** 48 `ModelEntity` cubes (unit box, scaled), one cached `UnlitMaterial` per palette color, all created at Arena open (prewarm: add them disabled to the root). Two simultaneous bullseyes (Hard) need 40 at most.
- **Emit:** count from the table. Colors are drawn from that ring's mix: outer = Paper ×2, Ink, Blue ×3, Red, Gold; red = Red ×3, Blue ×2, Paper, Gold, Ink; gold = Gold ×2, Shine, Gold, Red ×2, Blue, Paper. Size = **0.05·D**. Start position is a random point on the face disc at radius 0.6·r.
- **Velocity:** in-plane direction from the center × `0.8·(D/0.4)` m/s × U(0.8, 1.3) × ring multiplier (1.0 / 1.1 / 1.3), + world up `0.5·(D/0.4)` m/s, + toward the viewer `U(0, 0.2)` m/s. **Comfort clamp: the toward-viewer component is 0 when the target is < 1 m from the head** (no shards flying at a kid's face in Touch mode).
- **Per frame** (in `ArenaController.updateFX(now:)`, which plan §6.4 already calls): `v.y -= 3.0·dt` (soft arcade gravity); `p += v·dt`; spin about a random axis at 720°/s; `scale = size·(1 − (age/life)²)` (holds, then shrinks); disable and return to the pool at `age ≥ life`.
- **Reduce Motion:** shards don't move or spin; they appear in place and shrink over half the life.
- `ParticleEmitterComponent` is **not** used for MVP. Stretch only: a bullseye sparkle burst using a 2×2-pixel square image, `isLightingEnabled = false`, burst 24, if the team wants extra polish after M7.

### 4.4 Popups ("score tags") — shipped in `pew/PewPew/Arena/ScorePopups.swift`
**Source of truth:** the `HitOutcome` returned by `GameSession.registerHit`. The session passes it to `ArenaRendering.removeTarget(_:reason: .hit(outcome))`, and `ArenaController` spawns the tag there from the target's world position. No other code path creates popups, so look-pinch, touch, debug and autoplay hits all get the same tag.

**Variants** (lines top to bottom; `em` = the base size below):

| Variant | When | Lines | Text color | Plate |
| --- | --- | --- | --- | --- |
| Outer | ring `.none` (ρ > 0.40, and assisted hits ρ ≥ 1) | "+N" at 1.0 em | Paper | Ink 90 % |
| Red | ring `.red` (0.20 < ρ ≤ 0.40) | "+N" at 1.15 em | Target Red | Ink 90 % |
| Bullseye | ring `.gold` (ρ ≤ 0.20) | "BULLSEYE" at 0.73 em, "+N" at 1.33 em (= 1.6° / 1.2°) | Gold, both lines | **Opaque** Ink (at 90 % the Gold border tinted it olive) + **Gold border plate** 0.15 × line scale larger on each side |
| Combo (adds to any of the above) | `outcome.multiplier > 1` | extra bottom line "×1.5" or "×2" at 0.55 × the "+N" size | Paper for ×1.5, Gold for ×2 (same colors as the HUD chip) | — |

Examples: a plain outer hit reads `+100`; a red hit on a ×2 streak reads `+340` / `×2`; a bullseye on ×1.5 reads `BULLSEYE` / `+270` / `×1.5`.

- **Text:** `MeshResource.generateText(text, extrusionDepth: 0.03, font: UIFont(name: "PressStart2P-Regular", size: 1) ?? .systemFont(ofSize: 1, weight: .heavy))`, built at **unit em** and centered via `mesh.bounds`; `UnlitMaterial` in the line color. The whole tag is scaled by `em`, so one mesh serves every distance.
- **Plate:** `generatePlane(width: maxLineW + 0.6, height: linesH + 0.5, cornerRadius: 0.12)` (× the "+N" line scale), Ink `UnlitMaterial` with `.transparent(opacity: 0.9)`, text 0.01 em in front. Line gap 0.35 em.
- **Size by angle:** `em = 2·d·tan(θ/2)`, θ = **1.2°** (`Tuning.FX.popupAngleDeg`), d = head-to-target distance. At 3 m, em is 6.3 cm; at 0.5 m (Touch), 1.0 cm.
- **Timing** (all from `Tuning.FX`): hidden for the first 40 ms (`hitFlash`, so the target flash reads first) → visible at the target center + 3 cm toward the head. Scale 0.6 → 1.1 (60 ms, ease-out) → 1.0 (60 ms). Rises **0.04·d** (2 cm at 0.5 m, 12 cm at 3 m) over `popupLife` 600 ms with ease-out cubic. Opacity 1 → 0 over the last `popupFadeOut` 150 ms. `BillboardComponent` keeps it facing the viewer.
- **Reduce Motion:** no pop and no rise; life `popupReducedMotionLife` 400 ms, still fading over the last 150 ms.
- **Budget:** a pool of `popupPoolSize` = 4 slots (root + plate + border + 3 line entities each), built at Arena open. A fifth simultaneous hit recycles the oldest slot. Text and plate meshes are cached per string / layout, so a repeat score allocates nothing; the per-frame update only writes transforms and an `OpacityComponent` when opacity moves by > 1 %.

---

## 5. UI

### 5.1 Panel style
- **Glass, not custom.** Lobby, results, tutorial card, HUD, hint capsule, and countdown disc all use `.glassBackgroundEffect()` (the HUD with `in: .rect(cornerRadius: 40)`). Native glass adapts to the room, stays legible, and makes this feel like an Apple app. Personality comes from type, color, and pixel ornaments, not from re-skinning controls.
- **Native controls:** `Picker(.segmented)`, `Toggle`, `.borderedProminent` / `.bordered` buttons. They give gaze hover, pinch, and accessibility for free. Don't write custom `ButtonStyle`s that drop `.hoverEffect`.
- **Pixel ornaments (the only custom decoration):** the face sprite as an icon (`Image(uiImage:).interpolation(.none)`), a 4 pt pixel-dash divider (8 on / 8 off, white 22 %), 12 pt square step pips, and 4–10 pt **hard** Ink shadows (`.shadow(color: ink, radius: 0, x: s, y: s)`) on display numbers.
- **Scale assumption:** RealityView attachments render at about **1360 pt per meter** (1 pt ≈ 0.735 mm). **Verify on device** with `@Environment(\.physicalMetrics)` (`convert(_:from: .meters)`). If the ratio differs, scale the attachment *entities* so the physical sizes below hold. Don't change point sizes.

### 5.2 Typography rules

| Use | Font | Sizes (pt) |
| --- | --- | --- |
| Logo wordmark | Press Start 2P, Target Red, 4 pt hard Ink shadow | 48 (lobby), 56 (launcher) |
| Countdown digits / GO! | Press Start 2P, Gold, 10 pt hard Ink shadow | 160 |
| HUD time | Press Start 2P, Paper (Gold in the last 5 s) | 64 |
| HUD score | Press Start 2P, Paper, thousands separator | 32 |
| Results hero score | Press Start 2P, Gold, 5 pt hard Ink shadow | 64 |
| Panel headers ("ROUND OVER") | Press Start 2P, Paper | 24 |
| Primary button labels (START, PLAY AGAIN) | Press Start 2P, white | 24 |
| Combo chip | Press Start 2P, Ink on Paper (×1.5) / on Gold (×2) | 24 |
| 3D score tags | Press Start 2P 3D text | angular (§4.4) |
| Labels, captions, rows, secondary buttons, hint | SF Pro | 17–22 |
| Stat numbers | SF Pro Rounded heavy, `.monospacedDigit()` | 34 (units 20) |
| Tutorial copy | SF Pro Rounded heavy | 28 |

**Press Start 2P rules:** sizes are multiples of 8 pt; ≥ 24 pt everywhere; UPPERCASE words or numbers only; ≤ 12 characters per line; never sentences, captions, or any text a kid must *read* rather than *recognize*. Tracking stays at 0 (the font is already monospaced); line height 1.25. The glyphs "×", "·", ",", "!", "+", "%" and "★" all exist in the font. Fallback when the font fails to load: `.system(size:, weight: .black, design: .monospaced)`.
**SF Pro rules:** minimum 17 pt; body and rows 20 pt semibold; `.primary`/`.secondary` vibrancy only on glass (no palette colors for SF text except Gold stat highlights).

**Angular check** (em height at the panel's distance; target ≥ 0.6° for any text, ≥ 0.75° for body text):

| Panel (distance) | Smallest text | Body | Display |
| --- | --- | --- | --- |
| Lobby / Results (1.2 m) | 17 pt = 0.60° | 20 pt = 0.70° | 64 pt = 2.2° |
| HUD (1.1 m) | 17 pt = 0.65° | hint 22 pt = 0.84° | 64 pt = 2.4° |
| Tutorial (0.9 m) | 17 pt = 0.80° | 28 pt = 1.3° | — |
| Countdown (1.6 m) | — | — | 160 pt = 4.2° |

### 5.3 Layouts (see the mockups for the exact look)

Screens are attachments inside the Arena (plan §1.1): `menu` (lobby or results, by phase), `countdown`, `hud`, and the DEBUG-only `debug`. `ArenaView` enables exactly one of menu / countdown+HUD / HUD per phase. Implemented in `pew/PewPew/UI/{LauncherView,LobbyPanel,ResultsPanel,PlayHUD,PixelViews}.swift`. Simulator screenshots of the shipped screens (visionOS 26.1 simulator, Debug build) are in [`docs/visual/screenshots/`](visual/screenshots/) (1280 px copies; full-size originals in the Project store's `media/visual/screenshots/`): `launcher-window.png`, `start-menu-lobby.png`, `start-menu-how-to-play.png`, `hud-in-round.png`, `results-panel.png`, `score-popups-all-variants.png`, `score-popups-closeup.png`, `debug-panel-shown.png`.

**Launcher window** (520×380 pt, system window glass) — the only 2D window; it closes when the Arena opens:
1. Wordmark row centered: 56 pt face icon + "PEWPEW" Press Start 2P 56 pt, Target Red, 4 pt hard Ink shadow, gap 18.
2. Tagline "Hit the targets. Beat the clock." SF 20 semibold, secondary, 16 below.
3. Flexible space (≥ 24).
4. **ENTER ARENA** primary (full width minus 48 pt, 68 pt). While opening it reads "OPENING" and is disabled at 50 % opacity.
5. Footnote 17 pt, 16 below: `hand.raised.fill` + "Uses hand tracking. Best in a clear, well-lit space." in secondary. If opening fails, this slot shows `exclamationmark.triangle.fill` + "Couldn't open the arena. Try again." in system red instead (one line, never both).

**Lobby / start menu** (600 pt wide, height hugs content, 1.2 m, −8°, corner radius 46, padding 36/40) — `lobby-panel.png`. Only the rows whose features exist are shown; the rest join as their milestones land:
1. Header row: 52 pt face icon + "PEWPEW" wordmark 48 pt, gap 18.
2. Tagline 20 pt secondary, 12 below.
3. Banner (only without hand tracking, e.g. the simulator), 24 below: black-18 % rounded rect (radius 22), `info.circle` + "Hand tracking is off, so you're using Look & Pinch: look at a target and pinch to hit it." 17 pt.
4. Settings rows, 32 below, gap 14: label column 130 pt (SF semibold 20) + segmented picker filling the rest (`.controlSize(.large)`). Shipped rows: **Round** `30 s | 60 s` and **Space** `Stay Put | Roam Room`, with the plan §3.7 caption under the picker ("Stay in one spot" / "Walk around — clear some space first"), 17 pt secondary. To come: Controls `Blaster | Touch` (M4), Difficulty (M5), Big Targets toggle (M7b), Music toggle (M7a), in the mockup's order.
5. Pixel divider, 24 above and below.
6. **START** primary, full width, 68 pt.
7. Footer, 16 below: **How to Play** (`.bordered` capsule, 60 pt) left, **Exit Arena** (`.borderless`, secondary, 20 pt) right. DEBUG builds only: a "Debug" / "Hide Debug" borderless button, 17 pt tertiary, centered (§5.5).
8. **How to Play** swaps the panel content in place (no new window): face icon 40 + "HOW TO PLAY" pixel 24 Paper; four rows, SF Symbol 22 pt + SF 20 copy, 24 apart (poke a target / aim for the middle / combos / look & pinch); pixel divider; full-width **Back** `.bordered` with `chevron.left`. It's the static card from plan §7 until the M8 tutorial replaces it.

Sounds: `ui_tap` on START, PLAY AGAIN, ENTER ARENA, How to Play and a Round pick; `ui_toggle_on`/`off` on the Space picker (Roam = on) and the Debug toggle; `ui_back` on Back, Menu and Exit Arena (`pew/PewPew/UI/UISound.swift`, `AVAudioPlayer`, until the M7a AudioBank takes over).

**Countdown** (1.6 m, eye height, arena forward) — `countdown-and-tutorial.png`: a 300 pt glass disc with a 160 pt Gold digit (10 pt Ink hard shadow). Each digit scales 1.3 → 1.0 over 200 with `count`. GO! uses a 360×200 pt capsule (96 pt pixel text) for 0.5 s, scaling 1.0 → 1.25 and fading over the last 150, with `go`. Shipped: disc, digits and GO! capsule; the pop, fade and sounds are M7.

**HUD placement while Touch is the only mode:** 1.3 m ahead, **10° above** eye line, facing the head. Touch targets fill the band 5–40° below eye line at 0.5 m, so the spec's −18° slot sat directly behind them. Move it back to the lazy-follow −18° slot below once Blaster mode ships (its targets are at −10°…+15°).

**HUD** (460×128 pt, radius 40, padding 0/30, lazy-follow 1.1 m, −18°, `allowsHitTesting(false)`) — `hud-in-room.png`: left is TIME (SF bold 17, tracking 1.5, secondary) over a 64 pt pixel time, two digits zero-padded ("04"). Then a 2 pt white-18 % divider, 80 pt tall. Right is SCORE label + combo chip (right-aligned on the label row) over the 32 pt pixel score. The hint is a **separate** glass capsule 16 pt below the HUD (SF semibold 22) so the HUD never resizes. The hint fades in/out over 200.

**Results** (640×600 pt, 1.2 m, −8°, radius 46) — `results-panel.png`: header 30 pt face icon + "ROUND OVER" 24 pt pixel. Hero: "SCORE" label (SF bold 17, tracking 2) above a 64 pt Gold pixel score. Chips row: length · controls · space · difficulty (SF semibold 17 in white-12 % capsules). Stat grid 3×2, gap 12, tiles black-20 % with radius 22 and padding 14/16: Hits "14 / 17", Accuracy "74 %", Avg reaction "612 ms", Fastest "431 ms", Best streak, Bullseyes (number in Gold, mini face icon). "Shots fired: N" (Blaster only) is 17 pt secondary. Buttons: **PLAY AGAIN** primary (flex 1.4) and **Menu** `.bordered` (flex 1), both 68 pt. Tally: numbers count up over 800 with `tally` ticks (≤ 12 ticks, evenly spaced); static under Reduce Motion. Panel appear: opacity 0 → 1, scale 0.94 → 1.0 over 200 (opacity only under Reduce Motion). Shipped: header, hero score, a length · space chip, the 3×2 grid and both buttons (Menu is 170 pt wide). Still to do: controls/difficulty chips, the bullseye mini icon, tally and appear animations.

**Tutorial card** (460×200 pt, 0.9 m, −20°, radius 36, padding 22/26) — `countdown-and-tutorial.png`: on the left, a 96 pt two-frame pixel hand sprite (`hand_a` thumb up / `hand_b` thumb down + gold flash) swapping every 500 (static frame A under Reduce Motion; step 1 uses the face icon instead). On the right: 3 step pips (12 pt squares; done = Paper, current = Gold, todo = white-28 %), copy from plan §7 in SF Pro Rounded heavy 28, then "Step n of 3" 17 pt secondary + **Skip** `.bordered` 17 pt, 44 pt tall. On success, a 300 ms check: the card's pips fill, then the next step.

### 5.4 Button styles
Primary (START, PLAY AGAIN, ENTER ARENA) uses `PrimaryPixelButtonStyle` in `pew/PewPew/UI/PixelViews.swift`, applied with `.primaryPixelButton()`: a solid `buttonRed` capsule, 68 pt tall, white Press Start 2P 24 pt label, a 2 pt white-18 % inner stroke, 0.97 press scale, 50 % opacity when disabled, and the system `.hoverEffect(.highlight)` on a capsule content shape (so gaze hover still works).
```swift
Button(action: start) { Text("START").frame(maxWidth: .infinity, minHeight: 44) }
    .primaryPixelButton()
```
Why not `.borderedProminent` + `.tint(buttonRed)`: on visionOS glass the system lightens the tint to a washed-out salmon (seen in the visionOS 26 simulator), which loses the palette's red. This is the one allowed custom `ButtonStyle`; it keeps the hover effect, per §5.1.
Secondary: `.secondaryButton()` = `.buttonStyle(.bordered)`, capsule, `.controlSize(.large)`, SF 20 semibold, minimum height 60. Tertiary (Exit Arena): `.buttonStyle(.borderless)`, `.foregroundStyle(.secondary)`. Hit areas are ≥ 60 pt everywhere (plan M3).

### 5.5 Debug controls are never player-facing
- Test tools (the debug panel, autoplay, hit injectors, launch flags) live in `pew/PewPew/Debug/` and are wrapped in `#if DEBUG`, so **Release and TestFlight builds don't contain them at all**.
- In DEBUG builds (what Xcode installs on a device) they are **hidden by default**. The only entry point is the small tertiary "Debug" button in the lobby footer. It shows a separate `debug` panel to the right of the play area (0.62 m right, 1.0 m ahead), which has its own **Hide** button so it can be dismissed mid-round.
- Debug panel buttons and what they do: **Autoplay: on/off** (a bot hits about 75 % of targets after 0.45–1.3 s at random ρ 0–0.8 and fires an occasional miss), **Expire all** (times out every live target), **Hit outer** (hits the nearest target at ρ 0.5: no ring bonus), **Hit bullseye** (nearest target at ρ 0.1: gold ring), **Miss shot** (a missed shot, which breaks the combo). They only act during a round. The status line shows phase, time, score and multiplier.
- Never put a debug control, debug label or test copy into the lobby, results, HUD or launcher layouts. Player-visible screens use only the elements in §5.3.
- Simulator screenshot flags (DEBUG only, `pew/PewPew/Debug/LaunchFlags.swift`): `-PewEnterArena`, `-PewHowToPlay`, `-PewAutoplay`, `-PewShowDebug`, `-PewRoam`, `-PewPopupDemo` (holds one tag per variant above the lobby for 60 s).

### 5.6 Fonts
Press Start 2P (SIL OFL 1.1) ships at `pew/PewPew/Resources/Fonts/PressStart2P-Regular.ttf` with its license `PressStart2P-OFL.txt`, registered via `UIAppFonts` in `pew/PewPew/Info.plist`. `Theme.Fonts.pixel` falls back to SF Mono black if it fails to load.

---

## 6. Audio direction

**Hybrid.** Each SFX = a sfxr/jsfxr chiptune core (square or pulse wave, the identity) + a short real foley transient (the physicality: a wooden *thock* or a cardboard *tap*). Mix the foley 6–10 dB under the chip. Format: **48 kHz, 16-bit, mono WAV**, trimmed tight (no leading silence > 5 ms), each < 0.5 s except `end` and `results`. High-pass at 150 Hz (the headset speakers can't reproduce sub-bass, and it wastes headroom). Peaks at −1 dBFS.

| File | Sound | Length | Loudness (short-term LUFS) | Where |
| --- | --- | --- | --- | --- |
| `pew.wav` | Downward square laser blip (~1.2 kHz → 400 Hz) + finger-snap tick | 120 ms | −16 | Gun hand, spatial |
| `hit.wav` | Wood *thock* + rising 2-note ding (C6–E6) | 250 ms | −14 | Target, spatial |
| `hit_red.wav` | Same as `hit`, +3 semitones (or pitch `hit` in code) | 250 ms | −14 | Target, spatial |
| `bullseye.wav` | Thock + 3-note arpeggio (C6–E6–G6) + short shimmer | 400 ms | −12 | Target, spatial |
| `spawn.wav` | Soft rising blip (600 → 1.4 kHz) with a **bright 20–40 ms attack** and 2–6 kHz content, for localization | 150 ms | −18 | Target, spatial (critical in Roam) |
| `expire.wav` | Downward "fwip" + soft cardboard tap | 200 ms | −20 | Target, spatial |
| `miss.wav` | Quiet dry tick (no tone) | 60 ms | −26 | Ray end, spatial |
| `count.wav` / `go.wav` | Square beep A5 / A6, GO with a quick octave slide | 150 / 300 ms | −16 / −14 | Countdown, UI |
| `tick.wav` | Short wood-block tick (last 5 s) | 50 ms | −22 | HUD, UI |
| `combo.wav` | Two-step power-up chirp; at ×2, play pitched +5 semitones | 200 ms | −16 | HUD, UI |
| `end.wav` | Referee whistle (real) layered with a descending chip triad | 700 ms | −14 | HUD, UI |
| `tally.wav` | Very short coin tick for the results count-up | 40 ms | −26 | Results, UI |

**Spatialization:** target and hand sounds use `SpatialAudioComponent(gain: −6)` on the emitting entity (plan §5.5), plus `distanceAttenuation: .rolloff(factor: 0.6)` so 5 m Roam spawns stay audible (flag: verify the initializer parameters in the SDK; if absent, keep the default and raise `spawn` gain by 3 dB). Leave directivity omni. Play `miss` from a temporary entity at the ray end, `pew` from an entity parented to the index tip, and UI sounds from the HUD entity with `ChannelAudioComponent`. **Voice cap:** at most 6 simultaneous SFX; drop new `tick`/`tally` if one is still playing. Never play `spawn` and `hit` from the same frame at the same spot (the spawn of the next target is already ≥ 0.25 s later per plan §3.2). **No music bed** (plan stretch).

---

## 7. Accessibility

| Setting | Visual behavior |
| --- | --- |
| **Big Targets** (lobby toggle) | Entity scale ×1.4 (plan); aim assist ×1.5 (plan); reticle 1.6°; popup θ ×1.25; brackets scale with the target. No other visual change; the map is identical. |
| **Reduce Motion** (`accessibilityReduceMotion`) | No idle bob; spawn 0.6 → 1.0 without overshoot and the ping fades without growing; hover scale and bracket pop become fades; shards don't travel or spin (shrink in place over half the life); no shockwave growth (fade only); popups don't rise or pop; no expire blink (single gray swap at −600); no HUD pulse (color only); no countdown pop; no results tally; tutorial hand stays on frame A; armed cube doesn't spin; Moving targets at ×0.5 speed (plan). |
| **Increase Contrast** (`colorSchemeContrast == .increased`) | Beam opacities 0.9 / 0.7 / 0.5; HUD, hint, and countdown get an Ink 70 % fill under the glass; 2-px outlines on the reticle, brackets, and chevrons (generate the alternate sprites with outline width 2). |
| **Differentiate Without Color** | Already covered: reticle cocked vs. uncocked differs by *shape*; ring bonus also shows as popup *size* and a second line; the last 5 s also *pulse* and *tick*; combo shows as text. |
| **Photosensitivity** | No full-field flashes. The white flash covers only the target (≈ 7° for Blaster, up to 22° for a Touch target at 0.5 m) and happens once per hit for 40 ms, never repeated. The expire blink is ≤ 3.3 Hz, small area, and low luminance delta (gray ↔ color, not white). Nothing strobes. |
| **Text** | Nothing below 17 pt / 0.6°; Dynamic Type at default only for the demo (plan M3); VoiceOver labels on every button ("Start round", "Play again", "Return to menu", "Exit arena"). |
| **Handedness** | Both hands and visuals are symmetric; dual wield shows two cubes and beams (plan). |

The palette's contrast audit is in §2.1.

---

## 8. Constants

### 8.1 `Theme.swift` (paste-ready; app target, `pew/PewPew/UI/Theme.swift`, readable by `Arena/` too)
```swift
import SwiftUI
import UIKit

struct PewColor: Sendable {
    let hex: UInt32
    init(_ hex: UInt32) { self.hex = hex }
    private var r: CGFloat { CGFloat((hex >> 16) & 0xFF) / 255 }
    private var g: CGFloat { CGFloat((hex >> 8) & 0xFF) / 255 }
    private var b: CGFloat { CGFloat(hex & 0xFF) / 255 }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}

enum Theme {
    enum Palette {
        static let paper        = PewColor(0xF4F1E8)
        static let ink          = PewColor(0x1B1B1F)
        static let ringBlue     = PewColor(0x2B6FD6)
        static let targetRed    = PewColor(0xE8402A)
        static let bullseyeGold = PewColor(0xFFC93C)
        static let goldShine    = PewColor(0xFFF1B8)
        static let blasterMint  = PewColor(0x3EE6C1)
        static let missGray     = PewColor(0x9AA0A6)
        static let grayRampLo   = PewColor(0x5F6368)
        static let grayRampHi   = PewColor(0xC9CDD1)
        static let buttonRed    = PewColor(0xC8321E)
        static let flashWhite   = PewColor(0xFFFFFF)
    }

    enum Fonts {
        static let pixelName = "PressStart2P-Regular"
        static let pixelAvailable = UIFont(name: pixelName, size: 24) != nil
        /// Press Start 2P: multiples of 8 pt, >= 24 pt, UPPERCASE / numbers only.
        static func pixel(_ size: CGFloat) -> Font {
            pixelAvailable ? .custom(pixelName, fixedSize: size)
                           : .system(size: size, weight: .black, design: .monospaced)
        }
        static func pixelUIFont(_ size: CGFloat) -> UIFont {
            UIFont(name: pixelName, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .black)
        }
        static func number(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
        }
        static let row      = Font.system(size: 20, weight: .semibold)
        static let body     = Font.system(size: 20)
        static let caption  = Font.system(size: 17)
        static let hudLabel = Font.system(size: 17, weight: .bold)
        static let hint     = Font.system(size: 22, weight: .semibold)
        static let tutorial = Font.system(size: 28, weight: .heavy, design: .rounded)
    }

    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16
        static let xl: CGFloat = 24, xxl: CGFloat = 32, panelH: CGFloat = 40, panelV: CGFloat = 36
    }

    enum Radius {
        static let panel: CGFloat = 46, hud: CGFloat = 40, tutorial: CGFloat = 36
        static let tile: CGFloat = 22, chip: CGFloat = 10
    }

    enum Metrics {
        static let launcher = CGSize(width: 520, height: 380)
        static let lobby    = CGSize(width: 600, height: 700)
        static let results  = CGSize(width: 640, height: 600)
        static let hud      = CGSize(width: 460, height: 128)
        static let tutorial = CGSize(width: 460, height: 200)
        static let countdownDisc: CGFloat = 300
        static let goCapsule = CGSize(width: 360, height: 200)
        static let primaryButtonHeight: CGFloat = 68
        static let secondaryButtonHeight: CGFloat = 60
        static let pickerWidth: CGFloat = 370
        static let rowLabelWidth: CGFloat = 130
        static let pointsPerMeter: CGFloat = 1360   // verify with PhysicalMetrics on device
    }

    enum TypeSize {   // display sizes, pt
        static let logo: CGFloat = 48, launcherLogo: CGFloat = 56, countdown: CGFloat = 160
        static let hudTime: CGFloat = 64, hudScore: CGFloat = 32, resultsScore: CGFloat = 64
        static let header: CGFloat = 24, button: CGFloat = 24, chip: CGFloat = 24, stat: CGFloat = 34
    }

    enum Shadow {   // hard pixel shadows (radius 0)
        static let logo: CGFloat = 4, hero: CGFloat = 5, countdown: CGFloat = 10
    }
}

extension View {
    func pixelShadow(_ offset: CGFloat) -> some View {
        shadow(color: Theme.Palette.ink.color, radius: 0, x: offset, y: offset)
    }
}
```

### 8.2 FX tunables (replace `Tuning.FX` in `pew/Packages/PewPewCore/Sources/GameCore/Tuning.swift`; pure values, no UI imports)
```swift
public struct PerRing<T: Sendable>: Sendable {
    public var outer: T, red: T, gold: T
    public init(outer: T, red: T, gold: T) { self.outer = outer; self.red = red; self.gold = gold }
}

public struct FX: Sendable {
    // Target build
    public var bodyDepthRatio: Float = 0.075          // × diameter
    public var finSizeRatio: Float = 0.16             // moving chevrons, × diameter
    public var finOffsetRatio: Float = 0.12           // beyond the rim, × diameter
    // Spawn
    public var spawnStartScale: Float = 0.6
    public var spawnOvershootScale: Float = 1.12
    public var spawnOvershootTime: TimeInterval = 0.09
    public var spawnSettleTime: TimeInterval = 0.06
    public var spawnPingEndScale: Float = 1.6
    public var spawnPingDuration: TimeInterval = 0.30
    // Hit
    public var hitFlash: TimeInterval = 0.04
    public var bullseyeGoldFlash: TimeInterval = 0.04
    public var hitRemoveAfter: TimeInterval = 0.08
    public var hitPopScale = PerRing<Float>(outer: 1.15, red: 1.15, gold: 1.2)
    public var shardCount = PerRing<Int>(outer: 10, red: 14, gold: 20)
    public var shardLife = PerRing<TimeInterval>(outer: 0.35, red: 0.42, gold: 0.52)
    public var shardSpeedMult = PerRing<Float>(outer: 1.0, red: 1.1, gold: 1.3)
    public var goldSparkleCount = 6
    public var goldSparkleLifeMult: Double = 1.5
    public var shardSizeRatio: Float = 0.05           // × diameter
    public var shardSpeedPerDiameter: Float = 2.0     // m/s per m of diameter (0.8 m/s at 0.40 m)
    public var shardUpPerDiameter: Float = 1.25       // m/s per m of diameter
    public var shardTowardViewerMax: Float = 0.2      // m/s; 0 when target < shardComfortDistance
    public var shardComfortDistance: Float = 1.0      // m
    public var shardGravity: Float = 3.0              // m/s²
    public var shardSpinDegPerSec: Float = 720
    public var shardPoolSize = 48
    public var shockwaveEndScale: Float = 2.2
    public var shockwaveDuration: TimeInterval = 0.26
    // Score tags
    public var popupAngleDeg: Float = 1.2
    public var popupBullseyeAngleDeg: Float = 1.6
    public var popupRisePerMeter: Float = 0.04        // × distance (0.12 m at 3 m)
    public var popupLife: TimeInterval = 0.6
    public var popupFadeOut: TimeInterval = 0.15
    public var popupReducedMotionLife: TimeInterval = 0.4
    public var popupPoolSize = 4
    // Expire
    public var expireWarnLead: TimeInterval = 0.6
    public var expireBlinkHalfPeriod: TimeInterval = 0.15
    public var expireDuration: TimeInterval = 0.2
    public var expireDrop: Float = 0.03
    public var expireShardCount = 4
    public var roundEndVanish: TimeInterval = 0.12
    // Blaster aim
    public var armedCubeSize: Float = 0.008
    public var armedCubeSpinDegPerSec: Float = 90
    public var beamThickness: Float = 0.0025
    public var beamSegmentLength: Float = 0.2
    public var beamOpacities: [Float] = [0.60, 0.35, 0.15]
    public var beamOpacitiesHighContrast: [Float] = [0.9, 0.7, 0.5]
    public var reticleAngleDeg: Float = 1.2
    public var reticleAngleBigTargetsDeg: Float = 1.6
    public var reticleKickScale: Float = 1.4
    public var reticleKickDuration: TimeInterval = 0.12
    public var reticleMissTint: TimeInterval = 0.12
    public var hoverScale: Float = 1.06
    public var hoverScaleTime: TimeInterval = 0.06
    public var bracketsSizeRatio: Float = 1.25
    public var bracketsPopScale: Float = 1.2
    public var bracketsPopTime: TimeInterval = 0.08
    // Fire / miss
    public var muzzleSize: Float = 0.024
    public var muzzleDuration: TimeInterval = 0.06
    public var muzzleSecondFrameScale: Float = 0.6
    public var tracerThickness: Float = 0.004
    public var tracerDuration: TimeInterval = 0.09
    public var tracerEndThicknessScale: Float = 0.25
    public var missShardCount = 6
    public var missShardSizePerMeter: Float = 0.004
    public var missShardLife: TimeInterval = 0.22
    public var missPuffEndScale: Float = 1.8
    public var missPuffDuration: TimeInterval = 0.18
    // HUD / panels
    public var comboPopScale: Float = 1.3
    public var comboPopDuration: TimeInterval = 0.2
    public var finalSecondsPulseScale: Float = 1.08
    public var finalSecondsPulseDuration: TimeInterval = 0.3
    public var countdownPopScale: Float = 1.3
    public var countdownPopDuration: TimeInterval = 0.2
    public var goEndScale: Float = 1.25
    public var goFadeOut: TimeInterval = 0.15
    public var panelAppearScale: Float = 0.94
    public var panelAppearDuration: TimeInterval = 0.2
    public var resultsTally: TimeInterval = 0.8
    public var resultsTallyMaxTicks = 12
    public var tutorialSpriteFrame: TimeInterval = 0.5
    public var hintFade: TimeInterval = 0.2
    public init() {}
}
```
These supersede plan §11 rows `FX spawnPop / hitFlash / shards / popup / expire`, `muzzle / tracer / reticleKick / reticleAngle`, and `beam`. Update §11 in the plan when this lands. `Targets.rimDepth/rimScale/faceThickness` become unused once the voxel body ships (keep them for the fallback).

---

## 9. Sonnet "visual polish" prompts

Paste the plan's shared preamble first, then the milestone's main block, then the matching block below. Each block assumes `docs/visual-design-spec.md` is in the repo and **the Xcode project is in `pew/`**.

### M1 — target look
```text
Visual polish for M1. Read docs/visual-design-spec.md §2, §3, §4.2 (Spawn, Hit rows), §4.3, §8.
The Xcode project lives in pew/ (not the repo root): app files are under pew/PewPew/, the package under
pew/Packages/PewPewCore/.

1. pew/PewPew/UI/Theme.swift: paste spec §8.1 verbatim (Arena code reads Theme.Palette.*.uiColor).
2. pew/PewPew/Arena/PixelTargetTexture.swift: paste PixelTargetMap from spec §3.1. Build 512×512 CGImages
   (16×16 blocks, y flipped) for: normal, small, normalGray, smallGray, flash (outline Ink, rest white),
   flashGold (outline Ink, rest goldShine). Gray = lerp(grayRampLo, grayRampHi, relative luminance).
   DEBUG-assert ascii(normal()) equals the golden map string from §3.1. Cache all six TextureResources
   at Arena open.
3. pew/PewPew/Arena/TargetFactory.swift: build per §3.2 — face = generatePlane(width: 1, height: 1)
   with UnlitMaterial(texture) and opacityThreshold 0.5 (if that property is missing, use
   .transparent blending and tell me); body = bodyMesh() from §3.3 built once per map at unit size,
   PhysicallyBasedMaterial Ink roughness 0.55, faceCulling .none; GroundingShadowComponent. Apply
   diameter via entity scale. Keep the plan's cylinder version as a fallback function. Verify on
   device that the shine pixels are upper-left; if mirrored, flip UVs, not the map.
4. pew/PewPew/Arena/HitFX.swift: spawn = scale 0.6→1.12 (90 ms ease-out)→1.0 (60 ms) + Paper ping ring;
   hit = flash texture 40 ms (+ flashGold 40 ms on gold), target scale to hitPopScale, removed at
   80 ms; shards from a prewarmed pool of 48 cubes driven per frame in ArenaController.updateFX(now:)
   using the physics in §4.3 (gravity 3 m/s², shrink 1−(age/life)², comfort clamp < 1 m). Ring from ρ:
   ≤0.20 gold, ≤0.40 red, else outer — counts/lives from Tuning.FX (§8.2; add those fields to
   Tuning.swift now). Gold also gets the shockwave ring.
   M1 popups are not required (M7).
Done when: on the simulator the target looks like docs/visual/target-design-sheet.png (crisp pixels
at 30 cm, stair-step silhouette, Ink slab visible at an angle) and a hit matches the vfx-storyboard
rows. Do not add audio, popups, HUD or aim visuals.
```

### M3 — panels
```text
Visual polish for M3 (UI half). Read docs/visual-design-spec.md §5 (all) and §8.1. Mockups:
docs/visual/lobby-panel.png, results-panel.png, hud-in-room.png, countdown-and-tutorial.png.
The Xcode project lives in pew/: views go in pew/PewPew/UI/, font file in
pew/PewPew/Resources/Fonts/PressStart2P-Regular.ttf (UIAppFonts in pew/PewPew/Info.plist).

1. Use Theme.swift (spec §8.1) for every color, font, size, radius. No literal colors or sizes in views.
2. LauncherView 520×380, LobbyPanel 600×700, ResultsPanel 640×600, PlayHUD 460×128, CountdownView
   (300 pt glass disc + 360×200 GO capsule) — layouts exactly as spec §5.3. All panels use
   .glassBackgroundEffect(); controls are native (segmented Picker, Toggle, borderedProminent/bordered).
3. Typography per §5.2: Press Start 2P only for logo, countdown, HUD time/score, results hero score,
   headers, primary button labels, combo chip — multiples of 8 pt, ≥24 pt, uppercase/numbers.
   Everything else SF Pro ≥17 pt; stat numbers Theme.Fonts.number(34).
4. Primary buttons: .primaryPixelButton() from PixelViews.swift (spec §5.4: solid buttonRed capsule,
   pixel 24 pt label, 68 pt tall, system hover kept). Never tint buttons with targetRed.
5. Hard shadows via .pixelShadow(): logo 4, results score 5, countdown 10.
6. HUD: time zero-padded 2 digits; in final 5 s color bullseyeGold + pulse 1.0→1.08→1.0 (300 ms) on
   each tick; combo chip hidden at ×1, Paper chip ×1.5, Gold chip ×2, pop 1.3→1.0 (200 ms); hint is a
   separate glass capsule 16 pt below (attach as part of the same "hud" attachment, VStack). HUD stays
   allowsHitTesting(false).
7. Panel appear: opacity 0→1 + scale 0.94→1.0 over 0.2 s (opacity only if accessibilityReduceMotion).
8. Face icon: Image(uiImage: PixelTargetTexture normal UIImage).interpolation(.none).resizable().
Done when: the simulator screens match the mockups within reason and Kevin's checklist passes (no text
<17 pt, buttons ≥60 pt). Do not build the tutorial card yet.
```

### M4 (M4a + M4b) — blaster visuals
```text
Visual polish for M4a/M4b. Read docs/visual-design-spec.md §4.1, §4.2 (Fire, Missed shot rows), §7
(Increase Contrast), §8.2. Sprites: docs/visual/sprites/reticle_*.png, brackets.png, muzzle_star.png,
ring_gray.png — regenerate them in code as small pixel maps (nearest-upscaled CGImages) rather than
shipping PNGs, or add the PNGs to pew/PewPew/Resources/Assets.xcassets with "Preserve Vector Data"
off and filtering nearest. The Xcode project lives in pew/; files are pew/PewPew/Arena/AimVisuals.swift
and pew/PewPew/Arena/HitFX.swift.

M4a (AimVisuals):
- Armed cube 8 mm blasterMint, rotated 45° about the aim axis, spin 90°/s (none under reduce motion).
- Beam: 3 boxes 2.5 mm × 0.2 m, OpacityComponent 0.60/0.35/0.15 (0.9/0.7/0.5 if
  colorSchemeContrast == .increased).
- Reticle: plane + cutout sprite, size = 2·d·tan(reticleAngle/2) (1.2°, Big Targets 1.6°),
  BillboardComponent (fallback look(at:) each frame); reticle_cocked when ARMED_COCKED,
  reticle_uncocked (4-gap ring) when ARMED_UNCOCKED; on the hovered target 2 mm in front of the impact
  point, else 3 m along the ray.
- Hover: target scale → 1.06 (60 ms) and its brackets plane (1.25·D, built in TargetFactory, hidden
  by default) pops 1.2→1.0 in 80 ms. Remove any halo disc.
M4b (HitFX):
- Muzzle star 2.4 cm at index tip: 30 ms at 1.0, 30 ms at 0.6, hide.
- Tracer: box tip→impact (or ray end), 4 mm, opacity 1→0 and thickness ×1→×0.25 over 90 ms.
- Reticle kick 1.4→1.0 over 120 ms on every fire.
- Missed shot: reticle_miss for 120 ms; 6 gray shards (size 0.004·distance, 220 ms, radial only) and a
  gray puff ring 1.0→1.8 over 180 ms at the ray end. No red, no shake.
All values from Tuning.FX. Done when: on device the reticle is visible over the bullseye and on a
white wall, filled/gapped state reads at 3 m, and the tracer is visible at 3 m.
```

### M7 — juice, popups, tutorial, audio, accessibility
```text
Visual polish for M7. Read docs/visual-design-spec.md §4.2 (Expire, Combo, Final 5 s), §4.4, §5.3
(Results tally, Tutorial card), §6, §7. Mockups: vfx-storyboard.png, countdown-and-tutorial.png.
The Xcode project lives in pew/: pew/PewPew/Arena/HitFX.swift, AudioBank.swift,
pew/PewPew/UI/TutorialCard.swift, ResultsPanel.swift, pew/PewPew/Resources/Audio/*.wav.

1. Score tags (§4.4): generateText with UIFont(name: "PressStart2P-Regular", size: em) (fallback heavy
   system), em = 2·d·tan(θ/2), θ 1.2° (gold line 1.6°, "BULLSEYE" line 0.55×); color Paper / targetRed /
   bullseyeGold by ring; Ink 90% plate behind (Gold border plate for bullseye); pop 0.6→1.1→1.0, rise
   0.04·d over 0.6 s ease-out, fade last 0.15 s; billboard; pool 4; reduce motion = static 0.4 s.
2. Expire warning: from expiresAt − 0.6 s swap face texture gray/normal every 0.15 s; reduce motion =
   single swap to gray. Expire itself: gray, scale 1→0 ease-in + drop 3 cm over 0.2 s, 4 gray shards.
   (GameSession already knows expiresAt; ArenaController reads it from its registry — no core change.)
3. Bullseye: HUD score digits flash Gold 0.2 s (via the existing .targetHit event).
4. Tutorial card exactly per §5.3: 460×200, 96 pt two-frame pixel hand (hand_a/hand_b maps; draw them
   in code from the 16×16 grids in docs/visual/sprites or ship the PNGs, nearest filtering), pips,
   SF Pro Rounded heavy 28 pt copy, Skip. Frame swap 0.5 s; static frame A under reduce motion.
5. Results tally: count up over 0.8 s with ≤12 tally.wav ticks; static under reduce motion.
6. AudioBank: file list, routing, and gains per §6 (spatial gain −6, rolloff 0.6 if the
   SpatialAudioComponent initializer supports distanceAttenuation; say which you used). Max 6
   simultaneous SFX; skip tick/tally if one is playing. WAVs are 48 kHz 16-bit mono.
7. Accessibility per §7 table: Big Targets visual extras, every Reduce Motion row, Increase Contrast
   (Ink 70% fill under HUD/hint/countdown glass, 2-px sprite outlines, stronger beam).
Done when: every row of the vfx-storyboard is reproducible on device, popups read on a white wall,
and toggling Reduce Motion / Increase Contrast changes exactly the listed behaviors.
```

---

## 10. Open flags (verify on device; use the fallback if the API isn't there)

| Item | Assumption | Fallback |
| --- | --- | --- |
| `UnlitMaterial.opacityThreshold` | Exists (alpha cutout) | `blending = .transparent(opacity: 1)` |
| `generatePlane` UV orientation | Shine pixels appear upper-left | Flip the plane's UVs / mirror the image draw |
| `MeshDescriptor` winding | CCW front faces | `faceCulling = .none` already set |
| Attachment scale | ≈ 1360 pt/m | Scale attachment entities to hit §5.2's angular sizes |
| `BillboardComponent` | visionOS 2 | `look(at: head)` each frame in `updateFX` |
| `SpatialAudioComponent` `distanceAttenuation` | Available | Default attenuation + 3 dB on `spawn` |
| Vision Pro ≈ 34 px/deg | Approximate, used only for §3.5 legibility estimates | — |
