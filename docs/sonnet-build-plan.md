# PewPew — Executable Build Plan (for Claude Sonnet)

**Author role:** senior designer (Opus) · **Executor:** Claude Sonnet, driven by Gary/Kevin · **Written:** Thu Nov 5, 2026
**Demo:** 1st week of December 2026 → plan treats **Mon Nov 30** as "must be demo-ready" (demo could be as early as Tue Dec 1).
**Repo:** [github.com/gwu18/pewpewGame](https://github.com/gwu18/pewpewGame) (local clone on Gary's Mac). **The Xcode project is in `pew/`**: plan paths like `PewPew/...` mean `pew/PewPew/...` and `Packages/PewPewCore/...` means `pew/Packages/PewPewCore/...`. Design assets live in the repo at **`docs/visual/`** (mockups, sprites) and **`docs/audio/`** (`sfx/`, `music/`). · **Stack (locked):** Swift + RealityKit + SwiftUI + ARKit, Xcode, visionOS · **No** backend, ML, DB, Unity.
**Device:** Gary's **personal** Apple Vision Pro, personal signing (see §M0).
**Companion docs:** `docs/visual-design-spec.md` (refines §2.6, §5, §11 FX) and `docs/sound-design.md` (supersedes §5.5 audio; adds music).

## Changelog
- **Fri Nov 6, 2026 — priorities revision.** Added the strict **Priority order** section (core loop → finger-gun; nothing below may delay them) and the tier ladder. Tutorial moved out of M7 into a new post-core **M8 Tutorial & demo** milestone (outline level; attract mode is Stretch). M7 is now the **Polish & feedback** tier (M7a Audio & music system, M7b Feedback moments & accessibility), covering the features implied by `docs/sound-design.md`. The freeze milestone is renamed **M8 → M9**. §5.5 now points to the sound doc (music is in scope; the earlier "no music" lines are gone). `.finalSecondsTick` fires for n = 10…1. Calendar (§9), cut order (§12.2), Stretch list (§12.3), checklist and ownership updated. Repo/asset paths noted above.
- Thu Nov 5, 2026 — initial plan.

## Priority order (strict — read before anything else)
1. **Core gameplay loop — MUST-1, Sun Nov 15 (M0–M3):** timed round → spawn → touch hit → score → results → play again.
2. **Hand tracking + finger-gun detection and firing — MUST-2 gate, Thu Nov 19 (M4a, M4b).**

**Nothing below these may delay them.** No Goal, Polish, Tutorial or Stretch work starts while a Must gate is red, and Gary does no post-gate work until MUST-2 passes. If a Must slips, later tiers slip or get cut (§12.2); the Must scope never shrinks to make room. The one allowed overlap: Kevin may start M5 core-side work (SpawnDirector, tests) once his M3 and M4b tasks are merged.

| Tier | Contents | Milestones | Window |
| --- | --- | --- | --- |
| **Must** | Core loop; finger-gun | M0–M4b | Nov 5 – Nov 19 |
| **Goal** | Variety/difficulty/movement · surface placement · **Polish & feedback** | M5, M6, M7a, M7b | Nov 20 – Nov 25 |
| **Tutorial & demo** | First-run tutorial + How to Play | M8 | Nov 24 – Nov 26 |
| **Stretch** | Attract (self-playing) demo mode + §12.3 | — | Only if everything is green Wed Nov 25; else post-demo |

Feature freeze **Fri Nov 27** (M9). Demo **Dec 1–4**. Everything after the Nov 19 gate is cuttable, in the order in §12.2.

How to use this doc:
1. §1–§7 are **decisions**. They are final unless device testing proves one wrong; change them here, not in code comments.
2. §8 is the **architecture** Sonnet must follow.
3. §9 is the **calendar**; §10 the **milestones**, each with a paste-ready **Sonnet instructions** block.
4. §11 is the **single tunables table** — every number in code must come from `Tuning.swift`, mirroring this table.
5. §12–§14: risks + cut list, device test checklist, ownership.

Copy this file into the repo at `docs/sonnet-build-plan.md` during M0 so Sonnet can read it in-workspace.

---

## 0. Executive summary (what this plan changes vs. the brief)

- **One Immersive Space, one coordinate system.** A tiny launcher window opens a **mixed `ImmersiveSpace` ("Arena")**; *everything* in the game — lobby, countdown, HUD, results — lives inside the Arena as RealityView attachments. The launcher hides while the Arena is open. ARKit hand data only flows in a Full Space anyway, so this is the native shape.
- **Fire gesture = "thumb hammer".** Finger-gun with thumb up = *cocked*; snap thumb down onto the side of the index finger = *bang*. Re-cock by lifting the thumb. It doesn't collide with the system pinch (thumb tip → index tip), resting hands don't fire it, and it reads "gun" instantly to kids.
- **Aim fairness:** aim ray uses the hand pose ~45 ms *before* the thumb started dropping (kills the "hammer yank" that drags aim down) + a small **3.5° aim-assist cone**. Apps can't read eye gaze, so this is the only assist.
- **One target at a time** (two on Hard). Clean reaction-time numbers and clear "find it, hit it" arcade rhythm (~15–17 targets per 30 s).
- **Archery rings matter:** Gold = BULLSEYE bonus, Red = small bonus. Gives the 8-bit archery target a gameplay reason to exist and gives skilled players depth.
- **Both inputs are always live; distance decides.** Touch-mode targets spawn within arm's reach, Blaster-mode targets spawn 1.8–3.2 m away. No mode-lock logic needed.
- **Placement is air-first.** Air-spawn in a comfort band always works; walls/tables via `PlaneDetectionProvider` are an add-on (Goal tier) with automatic fallback. Scene reconstruction is Stretch.
- **Testability built in:** game rules live in a pure Swift package (`PewPewCore`) tested with `swift test`/Swift Testing; simulator uses **Look & Pinch** on targets + a DEBUG hit injector/autoplay bot; finger-gun classifier is unit-tested against **recorded hand-joint fixtures** from the device.
- **Schedule:** full touch game by **Sun Nov 15**, finger-gun **gate Thu Nov 19**. After the gate: Goal tier incl. Polish & feedback (Nov 20–25), then Tutorial & demo (Nov 24–26), freeze Nov 27. All post-gate work is cuttable (§12.2).

---

## 1. visionOS space layout (brief §3)

### 1.1 Scene map

| Step | Container | Where it sits | Notes |
| --- | --- | --- | --- |
| Launch | `WindowGroup(id: "launcher")` plain window, ~520×380 pt, `.windowResizability(.contentSize)` | Wherever visionOS puts it | Logo, one-line pitch ("Hit the targets. Beat the clock."), **Enter Arena** button, small "Uses hand tracking" note. |
| Enter | `openImmersiveSpace(id: "arena")` → on `.opened` → `dismissWindow(id: "launcher")` | — | Then request ARKit authorization (§6.5). On `.userCancelled`/`.error`, stay in launcher and show inline error text. |
| Lobby | Attachment `"lobby"` in Arena | World-locked, placed **1.2 m ahead, 8° below eye line**, facing user, at the moment the lobby is shown | Round length (30s default / 60s), Controls (Blaster / Touch), Space (Stay Put / Roam Room), Difficulty (M5), Big Targets toggle (M7b), Music toggle (M7a), **Start**, How to Play (M8), Exit Arena. Standard glass panel. |
| Tutorial | Attachment `"tutorial"` (small card) + practice targets | Card 0.9 m ahead, 20° below eye line | §7 (M8) |
| Countdown | Attachment `"countdown"` | World-locked at **arena forward**, 1.6 m ahead, eye height | "3 · 2 · 1 · GO!" — Press Start 2P font, 1 s per number, GO 0.5 s, beep each. |
| Play | Attachment `"hud"` | **Lazy-follow**, 1.1 m ahead, 18° below eye line (§1.3) | Time left (big), score, combo badge. `allowsHitTesting(false)` — HUD is never tappable. |
| Results | Attachment `"results"` | Same placement rule as lobby (re-placed in front of the user's current heading) | Score hero + stat grid + **Play Again** (primary) + **Menu**. |
| Exit | Lobby "Exit Arena" → `dismissImmersiveSpace()` → `openWindow(id: "launcher")` | — | Also handle system dismissal (Digital Crown) — see §8.4. |

Immersion: `ImmersiveSpace(id: "arena") { ArenaView() }.immersionStyle(selection: .constant(.mixed), in: .mixed)`. Mixed (passthrough) is mandatory: the real room is the play space and walking requires seeing furniture. Do **not** offer progressive/full immersion.

Optional polish: `.persistentSystemOverlays(.hidden)` on the Arena during `.playing` only (flag: verify it applies to immersive content on device; if not, skip).

### 1.2 Why not windows/ornaments/volumes for menus
- A SwiftUI window coexisting with the Arena drifts away when the user walks (Roam mode) and lives in a different coordinate space from targets → harder placement math and "where did my menu go?" moments.
- Attachments are real SwiftUI (glass, buttons, gaze+pinch, system typography) — they *are* the Apple-native panel; they just live where we put them.
- Ornaments need a window; volumes can't receive ARKit data. Rejected.

### 1.3 HUD lazy-follow (comfort rule)
Each frame during `.playing`: get head pose (§6.4). Target HUD pose = head position + yaw-only forward × 1.1 m, pitched down 18°. If the HUD's current yaw offset from head forward > **25°** *or* its position error > **0.4 m**, start moving it toward the target with exponential smoothing (time constant 0.25 s) until error < 5°/0.05 m. Face the user (yaw only). This keeps the HUD out of the target band (targets spawn −10°…+15° elevation) and never forces neck tilt.
Fallback if head pose unavailable (simulator): world-locked HUD at (0, 1.25, −1.1) in arena space.

### 1.4 Enter / exit without losing orientation
- **Arena forward** is captured once, at the moment the user presses Start: head yaw + head position. Countdown and in-place spawns use it. Lobby/results re-anchor to *current* heading each time they appear.
- If the user is lost: visionOS long-press Digital Crown recenters; we additionally re-place the lobby on every return to lobby.

---

## 2. Input & interaction (brief §4)

### 2.1 Input sources (all feed one entry point)

| Source | Available | Trigger | Range |
| --- | --- | --- | --- |
| `touch` | device, hand tracking authorized | Index fingertip (either hand) enters target hit sphere | Arm's reach |
| `blaster` | device, hand tracking authorized, M4+ | Thumb hammer while finger-gun pose held | 0–8 m ray |
| `lookPinch` | simulator **always**; device when hand tracking denied | System gaze + pinch on target (`SpatialTapGesture().targetedToAnyEntity()`) | any |
| `debug` | DEBUG builds | Debug panel / autoplay bot | — |

**Coexistence rule (final):** every enabled source is always live; the **Controls** setting only changes spawn distances/sizes/lifetimes. Touch-mode targets are within reach, Blaster-mode targets are not, so in practice each mode uses its natural input. A kid poking a target in Blaster mode? Can't reach it — no conflict. `lookPinch` is only enabled when hand tracking is unavailable (otherwise an accidental look+pinch would steal a hit).

### 2.2 Finger-gun pose (per hand, both hands independently — dual wield allowed)

Joint names are `HandSkeleton.JointName` (visionOS 1+). World position of joint *j* = `handAnchor.originFromAnchorTransform * skeleton.joint(j).anchorFromJointTransform` (column 3). Ignore frames where any used joint has `isTracked == false`.

Hand scale `s = |indexFingerKnuckle − wrist|` (≈0.09 m adult, ≈0.07 m child). All distance thresholds are divided by `s` so kids work.

1. **Index extended:** straightness `= |indexTip − indexKnuckle| / (|indexIntermediateBase − indexKnuckle| + |indexIntermediateTip − indexIntermediateBase| + |indexTip − indexIntermediateTip|)` ≥ **0.90** to arm, stays armed while ≥ **0.82** (hysteresis).
2. **Other fingers curled:** for middle, ring, little: `curl = |fingerTip − wrist| / |fingerKnuckle − wrist|` ≤ **1.25** → curled. Require **≥ 2 of 3** curled (forgiving for ring/little occlusion).
3. **Index pointing away from body:** `dot(aimDir, headForward) > 0.2` (prevents arming while scratching your face / pointing at yourself).

Pose = (1 ∧ 2 ∧ 3). Hand becomes **armed** after pose holds **4 consecutive frames** (~45 ms at 90 Hz). Pose loss tolerated for **0.15 s grace** (the hammer motion can briefly break the curl check) before disarm.

### 2.3 Fire gesture: thumb hammer (recommended)

Thumb metric `t = |thumbTip − indexFingerIntermediateBase| / s`.
- **Cocked:** `t ≥ 0.45`.
- **Fire:** from cocked, `t ≤ 0.27`, and the drop from ≥0.40 to ≤0.27 happened within **0.25 s** (a deliberate snap, not a slow drift).
- **Fire onset** = timestamp when `t` first dropped below 0.40 on this stroke → used for aim lookback (§2.4).
- After fire: **0.22 s cooldown**, and thumb must return to cocked (`t ≥ 0.45`) before the next shot (single-shot handgun semantics; no auto-fire by holding thumb down).

Alternatives considered:

| Gesture | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| **Thumb hammer** | Iconic "bang"; no system conflict; resting hands rarely produce cocked→snap | Thumb partly occluded by index from headset cameras at some angles; hammer yanks aim | **Ship.** Aim lookback fixes the yank; fixtures verify occlusion early. |
| Pinch (thumb tip → index tip) | Most reliably tracked gesture on AVP | Collides with system pinch (UI clicks); breaks the gun silhouette | Reject. |
| Dwell (hold aim on target 0.35 s) | Zero false fires, accessible | Not "shooting"; reaction stats inflated | **Plan B** (toggle "Auto-trigger"), see §12. |
| Wrist flick / recoil | Fun | Moves aim; false fires on any gesture | Reject. |
| Voice "pew" | Fun | Latency, noisy demo room | Stretch only. |

### 2.4 Aim ray
- Origin: `indexFingerTip`.
- Direction: `normalize(0.6·normalize(indexTip − indexKnuckle) + 0.4·normalize(indexKnuckle − wrist))` — the knuckle-wrist component stabilises the short finger segment.
- Smoothing: exponential on direction, α = **0.45** per frame (render rate), re-normalize.
- Ring buffer of the last 24 aim samples (timestamp, origin, dir). On fire, use the sample at `fireOnset − 0.045 s` (nearest).
- **Resolution** (pure function, `GestureCore/HitMath.swift`): for each live target (center **c**, facing normal **n**, radius **r**): angle between ray and (c − origin); intersect ray with target plane for impact point **p** → normalized radius `ρ = |p − c| / r`.
  - Direct hit if `ρ ≤ 1`. Else assisted hit if angle ≤ **3.5°** (Easy 5°; Big Targets ×1.5) — then `ρ` is reported as 1.0 (no ring bonus).
  - Pick the target with smallest angle. Max range 8 m. No hit → `registerMissedShot`.
- We do the math ourselves (few targets, deterministic, unit-testable). Do not use `scene.raycast` for shots.

### 2.5 Touch hit
- Per hand, per frame: segment from previous to current `indexFingerTip` (swept test catches fast pokes) vs. sphere at target center radius `r + 0.03 m`.
- `ρ` = distance from center projected onto target plane / r (ring bonus applies to touch too).
- Per-hand touch cooldown **0.15 s**. A target can be resolved only once (session guards double hits).

### 2.6 Aim feedback (arcade but quiet)
| Element | Spec |
| --- | --- |
| Armed indicator | 8 mm mint sphere at index tip, only while armed. |
| Beam | 2 mm-thick mint box from index tip, 0.6 m long, 35 % opacity (`OpacityComponent`). Hidden when not armed. |
| Reticle | Mint ring, constant angular size **1.2°** (scale with distance), at impact point on hovered target, else at 3 m along ray. **Filled** when cocked (ready), **hollow** when thumb down (needs re-cock). |
| Hover | Hovered target scales to 1.06 and shows a mint halo disc (radius ×1.08) behind it. |
| Fire | Muzzle flash (white square sprite, 60 ms) at tip, tracer box tip→impact 70 ms, reticle kick 1.4→1.0 over 120 ms, "pew" spatial at hand. |
| Miss | Small gray puff at ray end (3 m or 8 m cap), soft "tick". No red, no buzzer. |

No haptics exist on Vision Pro; audio + visual carry all feedback.

### 2.7 Interaction state machine (per hand)

```
            tracking lost (any state, >0.15s)
   ┌──────────────────────────────────────────────┐
   ▼                                              │
UNTRACKED ──joints tracked──► IDLE ──pose 4 frames──► ARMED_UNCOCKED
                               ▲                      │  t ≥ 0.45
                               │ pose lost > 0.15 s   ▼
                               └──────────────── ARMED_COCKED
                                                      │ t: ≥0.40 → ≤0.27 within 0.25 s
                                                      ▼
                                                    FIRE (emit ShotEvent with lookback aim)
                                                      │
                                                      ▼
                                              COOLDOWN (0.22 s) ──► ARMED_UNCOCKED
```
Touch detection runs in every state except UNTRACKED (it doesn't care about pose).

### 2.8 Failure modes & recovery
| Failure | Behavior |
| --- | --- |
| Hand tracking lost / hands out of view | Hand FSM → UNTRACKED; beam/reticle hide. If **no** hand tracked for **3 s** during `.playing`, HUD shows "Hands up! Keep them in view" until a hand returns. Round keeps running. |
| Hand tracking denied | `lookPinch` enabled, lobby banner: "Hand tracking is off — using Look & Pinch. Turn it on in Settings › Privacy & Security › Hand Tracking." Blaster/Touch picker disabled. |
| World sensing denied | Roam Room still works with air-spawn only; lobby note "Room scan off — targets float in the air." |
| Accidental UI pinch | HUD is non-interactive; during `.playing` no other attachments exist. |
| User presses Digital Crown / space dismissed | Abort round (no results), reset to `.lobby`, reopen launcher (§8.4). |
| App backgrounded (`scenePhase != .active`) | Same as above. |
| Tracking "pop" fires a ghost shot | Snap-time window + cocked prerequisite; if still seen on device, raise `fireSnapWindow` strictness (§11). |

---

## 3. Gameplay systems sheet (brief §5)

### 3.1 Round
- Lengths 30 s (default) / 60 s. Countdown 3·2·1·GO (3.5 s total). Timer starts at GO.
- Last 5 s: time text turns Gold and pulses, tick sound each second. `.finalSecondsTick(n)` is emitted for n = 10…1; at 10 s left the music crossfades to the intense loop (M7a, `docs/sound-design.md` §2).
- At 0: all live targets vanish (`.roundEnded`, *not* counted as expired), "whistle", results after 0.6 s.

### 3.2 Spawn / pacing
- **Concurrency:** Easy 1, Normal 1, Hard 2.
- **First spawn:** random 0.4–0.9 s after GO.
- **Next spawn:** when a target resolves (hit or expire), schedule the next one after a uniform random delay — Normal 0.35–1.10 s, Easy 0.6–1.4 s, Hard 0.25–0.80 s. With concurrency 2, each slot schedules independently.
- **No spawn** if remaining round time < 0.8 s (avoids unfair end-of-round expiries).
- **Warm-up:** first 5 s only spawn Normal type.
- **Placement failure:** if the arena can't place, retry after 0.1 s.
- Expected throughput: ~15–17 targets / 30 s on Normal.

### 3.3 Lifetime / misses
- Lifetimes (Blaster): Normal 2.6 s, Small 2.4 s, Moving 3.0 s. Touch: +0.6 s. Room mode ×1.5. Easy ×1.3, Hard ×0.8.
- Expire = target counts as **expired** (affects accuracy, breaks combo). Hit vs. expire on the same frame: hit wins if `hit.timestamp ≤ expiresAt`.

### 3.4 Scoring
```
ringBonus   = ρ ≤ 0.20 ? 100 (BULLSEYE) : ρ ≤ 0.40 ? 50 : 0
speedBonus  = 50 × clamp(1 − (rt − 0.45) / (1.50 − 0.45), 0, 1)       // rt = reaction time (s)
multiplier  = streak ≥ 10 ? 2.0 : streak ≥ 5 ? 1.5 : 1.0                // streak counted BEFORE this hit
points      = roundToNearest10((base + ringBonus + speedBonus) × multiplier)
base        = Normal 100 · Small 150 · Moving 200
```
- `streak` = consecutive hits; resets to 0 on a **missed shot** or an **expired** target.
- Reaction time `rt` = hit timestamp − spawn timestamp (spawn timestamp = the tick time when the entity was added; it's visible that frame at 60 % scale of a 0.15 s pop-in).

### 3.5 Accuracy & stats (results)
```
accuracy        = hits / (hits + missedShots + expired)     // "—" if denominator is 0
targetsHitRate  = hits / targetsResolved                    // shown as "Targets: 14 / 17"
avgReaction     = mean(rt of hits)        fastest = min(rt of hits)   // shown in ms
```
Results layout (glass panel, 640×520 pt):
- Hero: **SCORE** (Press Start 2P, 64 pt, Gold) + round length + mode chips ("30s · Blaster · Stay Put").
- 2×3 grid (SF Pro Rounded heavy, monospaced digits): Hits · Accuracy % · Avg reaction ms · Fastest ms · Best streak · Bullseyes. Blaster mode adds a small "Shots fired: N" line.
- Buttons: **Play Again** (borderedProminent, Target Red) · **Menu** (bordered).
- Tally animation: numbers count up over 0.8 s with tick sounds (skipped under Reduce Motion).

HUD mid-round shows **only**: time left (large), score, combo badge "×1.5"/"×2" (hidden at ×1), and transient hint text. Nothing else.

### 3.6 Target types
| Type | Blaster diameter | Touch diameter | Base pts | Motion | Weight N / E / H |
| --- | --- | --- | --- | --- | --- |
| Normal | 0.40 m | 0.20 m | 100 | Idle bob only | 60 / 80 / 40 % |
| Small | 0.26 m | 0.14 m | 150 | Idle bob only | 25 / 10 / 35 % |
| Moving | 0.40 m | 0.20 m | 200 | Horizontal strafe, sinusoidal: Blaster amplitude 0.6 m, period 3.2 s; Touch 0.15 m / 3.0 s | 15 / 10 / 25 % |

Difficulty size multiplier: Easy ×1.15, Hard ×0.85. Big Targets ×1.4 (stacks). Motion speed: Easy ×0.7, Hard ×1.3, Reduce Motion ×0.5.
**Decoys: no for December** (Stretch). They complicate accuracy semantics and onboarding.

### 3.7 Movement toggle
| | Stay Put (default) | Roam Room |
| --- | --- | --- |
| Reference | Arena forward captured at Start | **Live** head pose at each spawn |
| Blaster band | 1.8–3.2 m, azimuth ±35°, elevation −10°…+15° from eye | 2.0–5.0 m, azimuth ±120°, height 0.6–2.0 m above floor |
| Touch band | 0.42–0.58 m forward, ±0.28 m lateral, eye −0.40…−0.05 m vertical | 0.6–2.2 m, azimuth ±90°, height 0.8–1.6 m |
| Lifetime | ×1.0 | ×1.5 |
| Surface placement (M6) | Off (air only) | On when planes available |
| Spawn cue | Blip at target (spatial) | Same — essential for targets behind you |
| Lobby copy | "Stay in one spot" | "Walk around — clear some space first" |

Changeable **only in the lobby** (disabled during a round). Min angular separation between consecutive targets: 20° (Blaster); 0.15 m (Touch).

### 3.8 Difficulty
Presets **Easy / Normal (default) / Hard**, no adaptive difficulty (Stretch). Presets are pure multipliers over §11, so they cost almost nothing once M2 exists.

---

## 4. World & placement (brief §6)

### 4.1 Coordinate facts
- ImmersiveSpace origin is on the **floor** under the user at the time the space opened; +Y up. So `y` = height above floor, which makes height clamps trivial.
- Head pose: `WorldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())` → `originFromAnchorTransform`. Use yaw-only forward (`project −Z onto XZ`) for placement.

### 4.2 Placement pipeline
```
SpawnRequest(type, diameter, mode, input)
  │
  ├─ 1. Generate up to 12 candidates in the band (§3.7) using seeded RNG
  │
  ├─ 2. If Roam ∧ planes available ∧ coin(0.5):   ── surface attempt (M6)
  │       • Wall: ray from head along candidate direction → nearest vertical plane
  │         classified .wall (extent-bounded) within band → point = hit + normal·0.05,
  │         facing = plane normal. Require |hit − head| in band.
  │       • Table/seat: horizontal plane classified .table/.seat within band →
  │         point = random inside extent (inset 0.15 m) + up·(r + 0.02), facing = toward head (yaw-only).
  │
  ├─ 3. Validate each candidate:
  │       height ∈ [0.6, 2.0] m (touch: [0.8, 1.6]) · distance in band ·
  │       angular separation from previous ≥ 20° · not behind a wall
  │       (segment head→candidate doesn't cross a closer vertical plane, when planes known)
  │
  ├─ 4. First valid candidate wins → return pose
  ├─ 5. Else air-spawn: first candidate passing height+distance only
  └─ 6. Else last resort: 2.0 m (touch 0.5 m) straight ahead of head at eye − 0.1 m
```
**Facing:** set once at spawn — air targets `look(at: headPosition)` yaw-only (keep upright); wall targets face the wall normal. Do **not** continuously billboard (feels sticky and makes moving targets read wrong). Moving targets keep their spawn facing while strafing along their own right vector.

### 4.3 Aggressiveness for December
Air-spawn is the demo baseline. Surface placement only in Roam mode, 50 % of spawns, only `.wall`, `.table`, `.seat` classes, ignore planes smaller than 0.5 m × 0.5 m. Scene reconstruction (mesh) = **Stretch** (better "inside furniture" checks; not needed for the demo).

### 4.4 Anchoring
- Targets: world-locked entities parented to the Arena root (no ARKit `WorldAnchor` needed — they live seconds).
- Lobby/results/countdown: world-locked, placed at show time.
- HUD: lazy-follow (§1.3). Never strictly head-locked.

### 4.5 Permissions UX
- Ask once, right after the Arena opens (user just tapped "Enter Arena" — intent is clear): `ARKitSession.requestAuthorization(for: [.handTracking, .worldSensing])`.
- World tracking (device pose) needs no authorization.
- Denials handled per §2.8. Re-check `queryAuthorization` each time the Arena opens.

---

## 5. Visual & audio style guide (brief §7)

### 5.1 Art direction: "pixel target, physical object"
- **Target front:** unlit pixel-art archery face (always readable, even in dim rooms). Generated in code: 32×32 pixel grid drawn into a **512×512 CGImage with nearest-neighbor upscale** (each pixel = 16×16 block) so GPU filtering can't blur the pixels. 5 rings from center: Gold, Red, Blue, Ink, Paper, plus 1-px Ink outline. Slight 1-px "stair-step" circle edges are the 8-bit charm.
- **Body:** front disc = `MeshResource.generateCylinder(height: 0.006, radius: r)` (visionOS 2+) with `UnlitMaterial(texture)`, rotated so the cap faces +Z; behind it a rim cylinder radius r×1.04, depth 0.03 m, `PhysicallyBasedMaterial` Ink (roughness 0.6) so it catches room lighting and feels physical. Fallback if `generateCylinder` is unavailable: `generatePlane(width:height:)` with alpha-masked texture + `generateBox` rim.
- `GroundingShadowComponent(castsShadow: true)` on targets so they sit in the room.
- Idle bob ±1 cm, 2 s period (off with Reduce Motion).
- **No glow halos, no purple, no neon gradients.** Juice comes from motion, flashes and pixel shards.

### 5.2 Palette
| Token | Hex | Use |
| --- | --- | --- |
| Paper | `#F4F1E8` | Outer ring, light text on dark |
| Ink | `#1B1B1F` | Outlines, rim, ring 4 |
| Ring Blue | `#2B6FD6` | Ring 3 |
| Target Red | `#E8402A` | Ring 2, primary button tint, logo |
| Bullseye Gold | `#FFC93C` | Center, score, BULLSEYE text, last-5s timer |
| Blaster Mint | `#3EE6C1` | Armed indicator, beam, reticle, hover halo |
| Miss Gray | `#9AA0A6` | Miss puff, expired tint |

### 5.3 Typography & panels
- Logo, countdown numbers, results score: **Press Start 2P** (SIL OFL — bundle `PressStart2P-Regular.ttf`, register via `UIAppFonts` in Info.plist). Fallback: `.system(.largeTitle, design: .monospaced).weight(.black)`.
- Everything else: `.system(design: .rounded)` heavy for numbers with `.monospacedDigit()`, regular SF for labels. Use system glass (`.glassBackgroundEffect()`), `Picker(...).pickerStyle(.segmented)`, `.buttonStyle(.borderedProminent)`. Standard 60 pt min touch targets.

### 5.4 MVP VFX
| Event | VFX | Duration |
| --- | --- | --- |
| Spawn | Scale 0 → 1.1 → 1.0 | 0.15 s |
| Hit | Face flashes pure white (swap material) → 10 pixel-shard cubes (2 cm, ring colors) fly out 0.25 m while scaling to 0 → target removed; floating 3D text "+150" (Gold; "BULLSEYE +250" on gold ring) rises 0.12 m | flash 0.04 s, shards 0.35 s, popup 0.6 s |
| Expire | Tint to Miss Gray, shrink to 0 | 0.2 s |
| Shot / miss | §2.6 | — |
| Combo up | HUD badge pops (scale 1.3 → 1.0) | 0.2 s |

Implement shards/popups with `Entity.move(to:relativeTo:duration:timingFunction:)` and a small pool; popup text via `MeshResource.generateText`. No `ParticleEmitterComponent` needed for MVP.

### 5.5 Audio → see `docs/sound-design.md`
The sound doc is the source of truth for audio and **supersedes** the earlier table here: 28 finished SFX (48 kHz mono WAV) and 5 music files in the repo at `docs/audio/sfx/` and `docs/audio/music/`, the event → cue map, pooled spatial emitters (never play from a target entity), the UI/music channels, voice cap, ducking, and the **music system** (lobby loop → silent countdown → round loop → intense at 10 s → whistle → results sting, with a lobby Music toggle). Music is in scope (Goal tier, M7a). Don't duplicate its values here or in code comments. Core SFX (`spawn`, `hit*`, `bullseye`, `expire`, `miss`, `pew`, `count`/`go`, `tick`, `end`) are the floor; the rest belong to the Polish & feedback features in M7.

### 5.6 Accessibility
- **Big Targets** toggle (lobby): size ×1.4, aim assist ×1.5.
- **Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): no bob, no shards travel (flash + fade only), no HUD pulse, moving targets ×0.5 speed, no results tally.
- High contrast is built into the palette (Ink outline on every ring boundary).
- Both hands always work (left-handed players need nothing).

---

## 6. Platform facts Sonnet must respect

### 6.1 Targets
- Xcode **26.x**, visionOS SDK 26, **deployment target visionOS 2.0** (keeps API choices conservative; runs on Gary's device on 2.x or 26). If Gary's Mac can't run Xcode 26, Xcode 16.4 (visionOS 2.5 SDK) is acceptable — nothing in this plan needs 26-only APIs.
- App target: Swift 6 toolchain, **Swift 5 language mode**; mark UI/RealityKit/ARKit types `@MainActor` explicitly. `PewPewCore` package: swift-tools-version 6.0, Swift 6 mode (pure value types + one `@MainActor` class — easy to satisfy).

### 6.2 ARKit providers
| Provider | Milestone | Purpose |
| --- | --- | --- |
| `WorldTrackingProvider` | M3 | Head pose (HUD follow, arena forward, spawn bands) |
| `HandTrackingProvider` | M1 | Touch + finger-gun joints |
| `PlaneDetectionProvider(alignments: [.horizontal, .vertical])` | M6 | Walls / tables |
| `SceneReconstructionProvider` | Stretch | Furniture-aware safety |

All run in **one** `ARKitSession`, started after authorization, only while the Arena is open. Check each provider's `.isSupported` (all `false` in the simulator) and skip unsupported ones. Watch `session.events` for `.authorizationChanged` and `.dataProviderStateChanged`.
Hand data: consume `handTracking.anchorUpdates` in a `.task` on the Arena view (resumes on the main actor) and store latest left/right `HandAnchor`. (visionOS 2 adds `handAnchors(at:)` for predicted poses — optional; flag: if it exists in your SDK, prefer it inside the per-frame update for lower latency; fallback is latest-from-stream.)

### 6.3 Info.plist
```
NSHandsTrackingUsageDescription  = "PewPew follows your hands so you can poke and shoot targets."
NSWorldSensingUsageDescription   = "PewPew finds walls and tables so targets can appear around your room."
UIAppFonts                       = [ "PressStart2P-Regular.ttf" ]
UIApplicationSceneManifest       (keep template values; UIApplicationPreferredDefaultSceneSessionRole = UIWindowSceneSessionRoleApplication)
```
No special entitlements are needed (works with free personal team).

### 6.4 Main-actor & RealityKit rules
1. Every entity mutation, `GameSession` call, and ARKit result consumption happens on the **main actor**. No `Task.detached` touching entities.
2. **One per-frame driver:** in `RealityView`'s make closure, `content.subscribe(to: SceneEvents.Update.self) { event in ... }` calls, in this order: `inputCoordinator.update(now:)` → `session.tick(now:)` → `arena.updateFX(now:)` → `hudFollower.update(now:)`. Keep the returned `EventSubscription` alive (store it).
3. Time base everywhere: `CACurrentMediaTime()` (app) — the core package takes time as a `TimeInterval` parameter and never reads the clock itself (tests pass explicit times).
4. Custom `System`s allowed only for target motion (`TargetMotionComponent` + `TargetMotionSystem`), registered once in `PewPewApp.init()`.
5. Attachments: use `RealityView { content, attachments in } update: { ... } attachments: { Attachment(id: "hud") { PlayHUD() } }` (visionOS 1+). Flag: visionOS 26 adds `ViewAttachmentComponent`; if the closure form shows deprecation warnings, warnings are acceptable — don't migrate before the demo.
6. Never block the main actor with file IO or audio loading inside the update loop — preload on Arena open.

### 6.5 Testing without the headset
| Layer | How |
| --- | --- |
| Game rules | `PewPewCore` Swift Testing suites: transitions, timer, spawn scheduling (seeded RNG + explicit times), scoring, accuracy, edge cases. Run with `swift test` in `Packages/PewPewCore` or Xcode ⌘U. |
| Gesture math | `GestureCore` tests with **recorded fixtures** (JSON hand frames captured on device via the DEBUG Hand Recorder) + synthetic poses. |
| App in simulator | Arena opens; providers unsupported → `lookPinch` mode; click targets (gaze+pinch emulation); HUD world-locked fallback; head pose fallback = (0, 1.5, 0) facing −Z. |
| DEBUG hit injector | DEBUG-only attachment `"debug"`, opened from a "Debug" button in the lobby (DEBUG builds only): **Hit nearest** (ρ = 0.5), **Bullseye**, **Miss shot**, **Expire all**, **Autoplay** (bot: 75 % hit chance, rt uniform 0.45–1.3 s, 10 % miss shots). All go through `session.registerHit` / `registerMissedShot` with `source: .debug`. |
| Device tuning | DEBUG "Gesture Lab" panel: live per-hand state, straightness, curl ratios, thumb `t`, fire count, false-fire counter; sliders override `GestureTuning` at runtime. |

---

## 7. Onboarding (brief §3, §11.6)

**Tier: Tutorial & demo — post-core.** Built in **M8**, after MUST-1, the MUST-2 finger-gun gate and the Goal tier; it never delays them. Until M8 lands the lobby's "How to Play" can show a static card ("Poke targets. Finger-gun, drop thumb to shoot."). The table below is the design target; M8 keeps it at outline level.

Runs automatically on first Start (`@AppStorage("tutorialDone") == false`), or via "How to Play". Skippable ("Skip" button on card). Target time: **20–30 s**. No timer, no score.

| Step | Card text (≤ 8 words) | Target | Advances when |
| --- | --- | --- | --- |
| 1 Touch | "Poke the target!" | 1 Normal touch-size target 0.5 m ahead | Hit by any source |
| 2 Gun pose | "Make a finger-gun. Thumb up." + 2-frame pixel illustration of the hand | none; reticle appears when armed | Any hand reaches ARMED_COCKED |
| 3 Fire | "Drop your thumb to shoot!" | 1 Normal blaster target 2 m ahead | Hit (blaster) |
| 4 Done | "Nice! Hit as many as you can." (1.5 s) | — | auto → lobby (or straight into countdown if launched from Start) |

Steps 2–3 are skipped if hand tracking is unavailable or Controls = Touch. In `lookPinch` mode, step 1 reads "Look at it and pinch!". Each completed step plays `tutorial_success`; the lobby music ducks while the tutorial runs (`docs/sound-design.md` §2).

**Attract / demo mode (Stretch, §12.3):** when the lobby sits idle (no input for ~20 s), a self-playing round runs behind the lobby panel, driven by the existing autoplay bot: targets spawn and get "hit" with the normal FX, no score is recorded, SFX stay muted (the lobby loop keeps playing), and any hand movement toward the panel or any pinch stops it instantly. It needs a release-safe bot (the current `AutoplayBot` is DEBUG-only).

---

## 8. Architecture

### 8.1 Repo layout
In the real repo ([gwu18/pewpewGame](https://github.com/gwu18/pewpewGame)) everything below except `README.md` and `docs/` sits under **`pew/`** (`pew/PewPew.xcodeproj`, `pew/PewPew/`, `pew/Packages/PewPewCore/`). Repo-root `docs/` holds this plan, `visual-design-spec.md`, `sound-design.md`, `docs/visual/` (reference mockups/sprites, not app resources) and `docs/audio/` (source WAVs; copied into `pew/PewPew/Resources/Audio/` in M7a).
```
PewPew/   (local repo root, e.g. ~/Developer/PewPew)
├── README.md
├── docs/sonnet-build-plan.md                 (copy of this file)
├── PewPew.xcodeproj                          (Xcode 16+ synchronized folders → minimal pbxproj churn)
├── PewPew/                                   (app target)
│   ├── App/
│   │   ├── PewPewApp.swift                   shared   scenes, system registration
│   │   ├── AppModel.swift                    shared   owns session, arena, tracking, settings; space routing
│   │   └── PlayerSettings.swift              Kevin    @AppStorage-backed lobby choices
│   ├── UI/                                   Kevin
│   │   ├── LauncherView.swift
│   │   ├── LobbyPanel.swift
│   │   ├── CountdownView.swift
│   │   ├── PlayHUD.swift
│   │   ├── ResultsPanel.swift
│   │   ├── TutorialCard.swift
│   │   └── Theme.swift                       palette, fonts, button styles
│   ├── Arena/                                Gary
│   │   ├── ArenaView.swift                   ImmersiveSpace content: RealityView, attachments, frame driver
│   │   ├── ArenaController.swift             implements ArenaRendering; live target registry
│   │   ├── TargetFactory.swift               builds target entities
│   │   ├── PixelTargetTexture.swift          procedural 8-bit texture
│   │   ├── TargetMotion.swift                TargetMotionComponent + TargetMotionSystem
│   │   ├── HitFX.swift                       spawn/hit/expire/miss/tracer FX + pools
│   │   ├── AimVisuals.swift                  beam, reticle, armed dot, hover halo
│   │   ├── PanelPlacer.swift                 places lobby/results/countdown; HUD lazy-follow
│   │   └── AudioBank.swift                   preload + play helpers
│   ├── Tracking/                             Gary
│   │   ├── TrackingService.swift             ARKitSession, auth, providers, events
│   │   ├── HeadPose.swift                    device anchor query + simulator fallback
│   │   ├── HandFrameAdapter.swift            HandAnchor → GestureCore.HandFrame
│   │   └── PlaneStore.swift                  M6
│   ├── Interaction/                          Gary
│   │   └── InputCoordinator.swift            per frame: touch + finger-gun FSMs → session
│   ├── Placement/                            Gary
│   │   └── PlacementService.swift
│   ├── Debug/                                both (all #if DEBUG)
│   │   ├── DebugPanel.swift                  hit injector + autoplay
│   │   ├── AutoplayBot.swift
│   │   ├── GestureLabPanel.swift
│   │   └── HandRecorder.swift
│   ├── Resources/  Audio/*.wav · Fonts/PressStart2P-Regular.ttf · Assets.xcassets
│   └── Info.plist
└── Packages/PewPewCore/
    ├── Package.swift                         platforms: visionOS 2, macOS 14
    ├── Sources/GameCore/                     Kevin
    │   ├── Tuning.swift                      ALL constants (§11) incl. GestureTuning
    │   ├── Types.swift                       TargetID, TargetType, InputSource, Controls, SpaceMode, Difficulty, RoundConfig
    │   ├── HitEvent.swift                    HitEvent, HitOutcome, MissedShot
    │   ├── GamePhase.swift
    │   ├── GameEvent.swift                   events for FX/audio/HUD
    │   ├── ArenaRendering.swift              protocol the app implements
    │   ├── SpawnDirector.swift
    │   ├── ScoreCalculator.swift
    │   ├── RoundStats.swift                  RoundStats accumulator + RoundResult
    │   ├── SeededRandom.swift                SplitMix64 RandomNumberGenerator
    │   └── GameSession.swift                 @MainActor @Observable state machine — THE hit entry point
    ├── Sources/GestureCore/                  Gary (depends on GameCore for Tuning)
    │   ├── HandFrame.swift                   Sendable joint snapshot (simd_float3 per joint)
    │   ├── FingerGunClassifier.swift         pure pose metrics
    │   ├── FingerGunStateMachine.swift       per-hand FSM (§2.7)
    │   ├── AimFilter.swift                   smoothing + lookback ring buffer
    │   └── HitMath.swift                     resolveShot / resolveTouch (pure)
    └── Tests/
        ├── GameCoreTests/  SessionTests, SpawnTests, ScoreTests, StatsTests
        └── GestureCoreTests/  ClassifierTests, StateMachineTests, HitMathTests, Fixtures/*.json
```
**Merge rules:** one owner per folder (above). Shared files (`PewPewApp.swift`, `AppModel.swift`, `Tuning.swift`) change only in small PRs reviewed by the other person. Branch per milestone task (`m2-spawn-director`, …), PR into `main`, merge after the Tue/Thu sync. Never commit `xcuserdata/` or `DerivedData/`.

### 8.2 Key types
```swift
// GameCore/Types.swift
public struct TargetID: Hashable, Sendable { public let raw: Int }
public enum TargetType: Sendable { case normal, small, moving }
public enum InputSource: Sendable { case touch, blaster, lookPinch, debug }
public enum Controls: Sendable { case blaster, touch }
public enum SpaceMode: Sendable { case stayPut, roam }
public enum Difficulty: Sendable { case easy, normal, hard }
public struct RoundConfig: Sendable, Equatable {
    public var length: TimeInterval = 30   // 30 or 60
    public var controls: Controls = .touch // default flips to .blaster at M4 gate
    public var space: SpaceMode = .stayPut
    public var difficulty: Difficulty = .normal
    public var bigTargets = false
    public var reduceMotion = false
}

public struct SpawnRequest: Sendable {
    public let id: TargetID; public let type: TargetType
    public let diameter: Float; public let lifetime: TimeInterval
    public let motion: Motion            // .none | .strafe(amplitude: Float, period: TimeInterval)
    public let config: RoundConfig       // for placement band selection
}

// GameCore/HitEvent.swift
public struct HitEvent: Sendable {
    public let target: TargetID; public let source: InputSource
    public let timestamp: TimeInterval
    public let normalizedRadius: Float   // ρ: 0 = dead center, 1 = edge (assisted hits pass 1)
}
public struct HitOutcome: Sendable {
    public let points: Int; public let ring: Ring /* .gold .red .none */
    public let reactionTime: TimeInterval; public let multiplier: Double; public let streak: Int
}

// GameCore/GamePhase.swift
public enum GamePhase: Equatable, Sendable {
    case lobby
    case tutorial(TutorialStep)            // .touch, .gunPose, .gunFire, .done
    case countdown(endsAt: TimeInterval)
    case playing(endsAt: TimeInterval)
    case results(RoundResult)
}

// GameCore/ArenaRendering.swift
@MainActor public protocol ArenaRendering: AnyObject {
    func spawnTarget(_ request: SpawnRequest, at time: TimeInterval) -> Bool   // false = couldn't place
    func removeTarget(_ id: TargetID, reason: RemovalReason)                   // .hit(HitOutcome) .expired .roundEnded
    func removeAllTargets()
}

// GameCore/GameSession.swift
@MainActor @Observable public final class GameSession {
    public private(set) var phase: GamePhase = .lobby
    public private(set) var hud = HUDState()         // timeRemaining, score, multiplier, hint
    public var config = RoundConfig()
    public weak var arena: ArenaRendering?
    public var onEvent: ((GameEvent) -> Void)?       // FX/audio hooks

    public init(tuning: Tuning = .default, seed: UInt64 = .random(in: 0...UInt64.max))
    public func start(now: TimeInterval)              // lobby/results → countdown (or tutorial on first run)
    public func startTutorial(now: TimeInterval)
    public func tutorialPoseDetected()                // gunPose → gunFire
    public func skipTutorial(now: TimeInterval)
    public func returnToLobby()                       // results → lobby; also abort from anywhere
    public func tick(now: TimeInterval)               // countdown, timer, spawns, expiries
    @discardableResult
    public func registerHit(_ hit: HitEvent) -> HitOutcome?   // ★ THE ONLY WAY TO SCORE ★
    public func registerMissedShot(at: TimeInterval, source: InputSource) // stats only
}
```
`registerHit` returns `nil` (ignored) unless phase is `.playing` or `.tutorial`, the target is live, not already resolved, and `timestamp ≤ expiresAt`. On success it calls `arena.removeTarget(id, .hit(outcome))`, updates HUD, emits `.targetHit(outcome, id)`, and schedules the next spawn. This replaces `GameManager.TargetHit()` from earlier docs — same contract, Swift-idiomatic name.

`GameEvent`: `.countdownTick(Int)`, `.go`, `.finalSecondsTick(Int)`, `.roundEnded(RoundResult)`, `.targetSpawned(TargetID)`, `.targetHit(HitOutcome, TargetID)`, `.targetExpired(TargetID)`, `.missedShot`, `.comboChanged(Double)`, `.tutorialAdvanced(TutorialStep)`. `.finalSecondsTick(n)` fires for n = 10…1 (tick sound only at n ≤ 5; music switch at 10). App-side feedback hooks that are *not* GameEvents (InputCoordinator/AppModel, M7): `armed(hand)`, `fired(hand)`, `lockOn(TargetID)`, `newSessionBest` — see `docs/sound-design.md` §7.

### 8.3 State transitions (legal only)
```
lobby ──start (first run)──► tutorial(.touch) ─► (.gunPose ─► .gunFire) ─► .done ─► countdown
lobby ──start──────────────► countdown(endsAt = now + 3.5)
tutorial(*) ──skip──► countdown           (from "How to Play": ──done/skip──► lobby)
countdown ──now ≥ endsAt──► playing(endsAt = now + length)
playing ──now ≥ endsAt──► results(result)       [removeAllTargets, emit .roundEnded]
results ──Play Again (start)──► countdown        (tutorial never auto-repeats)
results ──Menu──► lobby
ANY ──returnToLobby() (abort: space dismissed / backgrounded / Exit)──► lobby   [no results]
```
Any other call is a no-op (assert in DEBUG). Config is read-only outside `.lobby`/`.results`.

### 8.4 App wiring
```swift
@main struct PewPewApp: App {
    @State private var model = AppModel()
    init() { TargetMotionComponent.registerComponent(); TargetMotionSystem.registerSystem() }
    var body: some Scene {
        WindowGroup(id: "launcher") { LauncherView().environment(model) }
            .windowResizability(.contentSize)
        ImmersiveSpace(id: "arena") { ArenaView().environment(model) }
            .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```
- `AppModel` (`@MainActor @Observable`): `session`, `arena: ArenaController`, `tracking: TrackingService`, `input: InputCoordinator`, `settings: PlayerSettings`, `arenaState: .closed/.opening/.open`, `handTrackingAvailable`, `worldSensingAvailable`.
- `ArenaView.onAppear` → `tracking.start()`; `.onDisappear` → `tracking.stop()`, `session.returnToLobby()`, `arenaState = .closed`, `openWindow(id: "launcher")`. Also observe `@Environment(\.scenePhase)`; on non-active during `.playing` → `returnToLobby()`.

---

## 9. Calendar (today Thu Nov 5 → demo Dec 1–4)

Syncs: **Tue** = integrate/merge, **Thu** = device test. Thanksgiving Thu Nov 26 = light day.

**Rule:** the two Must gates (MUST-1 Sun Nov 15, MUST-2 Thu Nov 19) come first. Nothing after them starts until they're green (only exception: Kevin's M5 core-side prep, §Priority order). Every row after Nov 19 is cuttable in the §12.2 order.

| Dates | Milestone | Gary (AR / interaction) | Kevin (logic / UI) | Gate |
| --- | --- | --- | --- | --- |
| Thu Nov 5 – Sat Nov 7 | **M0** Setup & signing | Signing, pair device, Developer Mode, first device deploy | Repo hygiene, project skeleton, `PewPewCore` package + CI-less test run | Blank Arena on device |
| Sun Nov 8 – Tue Nov 10 | **M1** Target + touch + hit pipe | Arena, target entity, touch hit, look-pinch | `GameSession` stub with real `registerHit` guard | Touch a target on device |
| Sun Nov 8 – Thu Nov 12 | **M2** Game core | — (reviews) | Timer, spawn director, scoring, stats, tests | Raw scored round (sim + debug bot) |
| Mon Nov 9 – Sat Nov 14 | **M4a** Finger-gun pose + aim | Hand recorder, classifier, FSM, aim visuals, Gesture Lab | — | Reticle tracks reliably on device |
| Wed Nov 11 – Sun Nov 15 | **M3** UI shell & full touch loop | Panel placement, HUD follow, head pose | Launcher, lobby, countdown, HUD, results | **MUST-1: full touch game Sun Nov 15** |
| Sun Nov 15 – Thu Nov 19 | **M4b** Fire + shot hits | Thumb hammer, lookback, HitMath, shot FX | Missed-shot stats, blaster results line | **MUST-2: finger-gun gate Thu Nov 19** |
| *— after the Nov 19 gate: Goal tier (cuttable) —* | | | | |
| Fri Nov 20 – Sun Nov 22 | **M5** Variety, difficulty, movement | Motion system, roam bands | Types/weights/difficulty/toggle logic + UI (core prep may start Mon Nov 16, see rule) | Toggle + 3 types on device |
| Fri Nov 20 – Tue Nov 24 | **M7a** Polish & feedback: audio & music system | AudioBank: spatial emitter pool, hand/ray cues, cock + lock-on cues | `SoundCue` map + tests, MusicDirector, Music toggle, asset copy | Every cue + music state machine on device |
| Sat Nov 21 – Tue Nov 24 | **M6** Surface placement (first Goal cut) | Planes, wall/table placement, fallback | Lobby notes for denied sensing | Targets on walls in Roam |
| Sun Nov 22 – Wed Nov 25 | **M7b** Polish & feedback: feedback moments & a11y | Score popups, expire warning/feedback, arena open/close transition, FX reduce-motion | Combo chip + milestones, session best badge, results tally, final-seconds HUD, Big Targets, Reduce Motion | Every feedback moment seen in one playtest round |
| *— Tutorial & demo tier (cuttable) —* | | | | |
| Tue Nov 24 – Thu Nov 26 | **M8** Tutorial & demo | Tutorial target placement, pose hook | Tutorial flow + card, How to Play | 2 first-timers finish unaided |
| Wed Nov 25 – Thu Nov 26 | *Stretch:* attract mode | — | Release-safe bot + idle trigger | Only if every row above is green Wed Nov 25 |
| Fri Nov 27 – Mon Nov 30 | **M9** Freeze & demo | Fresh install, demo room test | README, demo script | **Feature freeze Fri Nov 27**; tag `v1.0-demo` Sun Nov 29 |
| Tue Dec 1 – Fri Dec 4 | Demo | | | |

Finger-gun tuning buffer: Nov 20–24 is explicitly reserved for Gary to keep tuning if the gate is only partially met. In that case M8 extras and M6 are cut first, Gary's M7a/M7b items slide to Nov 23–25, and §12.2 applies from the top.

---

## 10. Milestones

Every Sonnet block below assumes the **shared preamble** is pasted first in each new Sonnet chat.

### Shared preamble (paste at the top of every Sonnet session)
```text
You are building PewPew, an Apple Vision Pro arcade game (visionOS) in the GitHub repo gwu18/pewpewGame.
Stack is LOCKED: Swift + SwiftUI + RealityKit + ARKit, Xcode 26 (deployment target visionOS 2.0).
No Unity, no backend, no ML, no third-party packages. App target uses Swift 5 language mode;
Packages/PewPewCore uses Swift 6 mode.

The design + architecture source of truth is docs/sonnet-build-plan.md in the repo. Read §8
(architecture) and §11 (tuning constants) before writing code. Follow its file layout and type names
exactly. All numeric constants must come from pew/Packages/PewPewCore/Sources/GameCore/Tuning.swift.
The Xcode project lives in pew/: plan paths PewPew/... mean pew/PewPew/..., Packages/... means
pew/Packages/.... Visual/audio specs: docs/visual-design-spec.md, docs/sound-design.md; reference
assets in docs/visual/ and docs/audio/.
Priority is strict: core loop, then finger-gun. Never trade Must scope for polish.

Hard rules:
- One scoring entry point: GameSession.registerHit(_:). Nothing else changes score.
- Game rules live in PewPewCore (no RealityKit/ARKit/SwiftUI imports there). The app target adapts.
- All RealityKit/ARKit/session work on the main actor. One per-frame driver (SceneEvents.Update
  subscription in ArenaView). Core never reads the clock; pass `now` in.
- Check ARKit provider .isSupported; the simulator has no hand tracking or plane detection — code must
  degrade (Look & Pinch on targets, fixed head pose).
- If you are unsure an API exists in the visionOS 2 SDK, say so in your reply and use the fallback
  given in the plan instead of inventing an API.
- Only do the milestone asked. Do not start later milestones. Keep diffs focused.
- When done: list files changed, how to verify in simulator, how to verify on device, and any
  assumptions. Run the package tests if you touched PewPewCore.
```

---

### M0 — Setup & signing (Thu Nov 5 – Sat Nov 7)

**Goal:** both laptops build the same project; a blank mixed Arena runs on the simulator and on Gary's Vision Pro.

**Manual steps (Gary — not Sonnet):**
1. Xcode 26 (or 16.4) + visionOS SDK/simulator installed on both Macs.
2. Signing: Xcode → Settings → Accounts → add personal Apple ID. Target → Signing & Capabilities → Team "(Personal Team)", bundle id `com.garywu.pewpew`. **Decide now:** stay on free provisioning (profiles expire 7 days after install — redeploy at least every Tue sync and on **Mon Nov 30**) or buy the Apple Developer Program ($99/yr; enrollment can take ~1–2 days, so enroll by Nov 20 if you want it for demo week). Recommendation: **buy it** if budget allows — removes the mid-demo-week expiry risk.
3. Vision Pro: Settings → General → Remote Devices; Mac and headset on the same Wi-Fi; Xcode → Window → Devices and Simulators → pair with code. Enable **Settings → Privacy & Security → Developer Mode**, restart. Trust the developer profile if prompted (Settings → General → VPN & Device Management).
4. Kevin develops on the simulator; device deploys go through Gary's Mac (Kevin can also pair his own Mac with his own Apple ID if needed — free teams can each register the device).

**Files to create:** `PewPew.xcodeproj` (Xcode template: visionOS App, Initial Scene **Window**, Immersive Space Renderer **RealityKit**, Immersive Space **Mixed**), `PewPew/App/PewPewApp.swift`, `PewPew/App/AppModel.swift`, `PewPew/UI/LauncherView.swift`, `PewPew/Arena/ArenaView.swift`, `PewPew/Info.plist` keys (§6.3), `Packages/PewPewCore/Package.swift` + empty `GameCore`/`GestureCore` targets with one passing test each, `.gitignore` (Xcode/Swift), `README.md`, `docs/sonnet-build-plan.md`. Remove template sample content (sphere, `ToggleImmersiveSpaceButton` can be folded into LauncherView). Keep or delete the `RealityKitContent` package — **delete** it (unused; less noise).

**Acceptance:**
- Sim: launcher shows "PewPew" + Enter Arena → Arena opens (launcher hides) with a 10 cm Target Red cube 1.5 m ahead at 1.4 m height; a temporary "Exit" attachment returns to launcher.
- Device: same, from Gary's Mac over Wi-Fi. Hand tracking permission prompt appears on Enter Arena (authorization request wired, results just logged).
- `swift test` in `Packages/PewPewCore` passes on both Macs.

**Do NOT yet:** gameplay, targets, hand logic, fonts/audio.

**Ownership:** Gary — signing, device, Arena scene, auth request. Kevin — package, `.gitignore`, README, project folder structure.

**Sonnet instructions (M0):**
```text
[paste shared preamble first]

Milestone M0 — project skeleton. Xcode has already generated a visionOS app from the template
(Window + RealityKit Immersive Space, mixed). Restructure it to match docs/sonnet-build-plan.md §8.1:

1. Create folders PewPew/App, UI, Arena, Tracking, Interaction, Placement, Debug, Resources.
   Move the template app file to App/PewPewApp.swift; create App/AppModel.swift
   (@MainActor @Observable) with `enum ArenaState { case closed, opening, open }`.
2. PewPewApp: WindowGroup(id: "launcher") { LauncherView() } .windowResizability(.contentSize);
   ImmersiveSpace(id: "arena") { ArenaView() } .immersionStyle(selection: .constant(.mixed), in: .mixed).
   Inject AppModel with .environment.
3. LauncherView: title "PewPew", subtitle "Hit the targets. Beat the clock.", prominent
   "Enter Arena" button. On tap: arenaState = .opening; let r = await openImmersiveSpace(id: "arena");
   on .opened → dismissWindow(id: "launcher"), arenaState = .open; on .userCancelled/.error show
   inline red text "Couldn't open the arena. Try again." and arenaState = .closed.
4. ArenaView: RealityView with a root Entity named "ArenaRoot"; add a 0.1 m box, UnlitMaterial
   color #E8402A, at (0, 1.4, -1.5). Add attachment id "exit" with a button "Exit Arena" at
   (0.4, 1.2, -1.2) that calls dismissImmersiveSpace(). In .onDisappear: arenaState = .closed and
   openWindow(id: "launcher").
5. Create Tracking/TrackingService.swift (@MainActor): owns ARKitSession; func start() async:
   requestAuthorization(for: [.handTracking, .worldSensing]) and print results. Call from
   ArenaView .task. Don't run providers yet.
6. Info.plist: NSHandsTrackingUsageDescription and NSWorldSensingUsageDescription with the exact
   strings in §6.3. Keep the template scene manifest.
7. Delete the RealityKitContent package and its references.
8. Create Packages/PewPewCore (swift-tools-version 6.0, platforms .visionOS(.v2), .macOS(.v14)),
   library products GameCore and GestureCore (GestureCore depends on GameCore), test targets
   GameCoreTests and GestureCoreTests using Swift Testing (`import Testing`) with one trivial
   passing test each. Add the package to the Xcode project and link both libraries to the app.
9. .gitignore for Xcode/Swift (xcuserdata, DerivedData, .build, .swiftpm, *.xcuserstate).
10. README.md: what PewPew is, requirements (Xcode 26, visionOS 2+), how to run in simulator,
    how to deploy to device (personal team signing, Wi-Fi pairing, Developer Mode), how to run
    package tests.

Done when: builds with zero errors; simulator shows launcher → Enter Arena → red cube + Exit;
`swift test` passes in Packages/PewPewCore. Do NOT add targets, game logic, hand processing,
fonts or audio.
```

---

### M1 — Target + touch + hit pipeline (Sun Nov 8 – Tue Nov 10)

**Goal:** one 8-bit target in the room; touching it (device) or look-pinching it (sim) calls `GameSession.registerHit`, which removes it with hit FX; a new one appears 1 s later (temporary loop, no timer).

**Files:**
- Create `GameCore/Types.swift`, `HitEvent.swift`, `ArenaRendering.swift`, `Tuning.swift` (§11 values for sizes/touch/ring/FX), `GameSession.swift` (minimal: `phase` starts `.playing(endsAt: .infinity)` *temporarily*, live target set, `registerHit` guard + simple 100 pts, `tick` spawns one target 1 s after previous resolved, `arena` weak ref).
- Create `GestureCore/HandFrame.swift`, `HitMath.swift` (`resolveTouch` only).
- Create `Arena/ArenaController.swift`, `TargetFactory.swift`, `PixelTargetTexture.swift`, `HitFX.swift` (spawn pop + white flash + shards only).
- Create `Tracking/HandFrameAdapter.swift`; extend `TrackingService` to run `HandTrackingProvider` when supported and expose `latestLeft/latestRight: HandFrame?`.
- Create `Interaction/InputCoordinator.swift` (touch only).
- Modify `ArenaView.swift`: frame driver, look-pinch gesture, remove cube.
- Tests: `GameCoreTests/SessionTests.swift` (hit on live target scores; double hit ignored; unknown id ignored), `GestureCoreTests/HitMathTests.swift` (touch inside/outside/swept).

**Acceptance:**
- Sim: target at (0, 1.3, −0.5) facing user; pixel rings crisp (no blur) at 30 cm; click it → white flash + shards → gone → new target in 1 s at a random spot in the touch band. Console logs points.
- Device: poke with either index fingertip → same. Fast poke passes through → still counts (swept). Resting hands near (but not in) the target don't trigger.
- Tests pass.

**Do NOT yet:** timer, countdown, menus, scoring formula beyond flat 100, finger-gun, planes, audio.

**Ownership:** Gary — everything in Arena/Tracking/Interaction/GestureCore. Kevin — `Types.swift`, `HitEvent.swift`, `ArenaRendering.swift`, `GameSession` stub + tests (Kevin owns its future; Gary may write the stub with Kevin reviewing if Kevin is busy with M2 setup).

**Sonnet instructions (M1):**
```text
[paste shared preamble first]

Milestone M1 — first target, touch hit, single hit pipeline. Read plan §2.5, §5.1, §5.4, §8.2.

PewPewCore/GameCore:
- Types.swift, HitEvent.swift, ArenaRendering.swift exactly as in §8.2 (Motion can be .none only for now;
  RemovalReason: .hit(HitOutcome), .expired, .roundEnded).
- Tuning.swift: `public struct Tuning: Sendable { ... public static let `default` }` with nested
  structs Round, Spawn, Targets, Score, Gesture, Touch, FX, HUD. Fill every value from §11 now
  (even ones unused yet) so later milestones only read it.
- SeededRandom.swift: SplitMix64 conforming to RandomNumberGenerator.
- GameSession.swift: @MainActor @Observable. TEMPORARY M1 behavior: init sets phase =
  .playing(endsAt: .infinity). Keeps `live: [TargetID: LiveTarget]` (type, spawnTime, expiresAt=∞).
  tick(now:): if no live target and now >= nextSpawnAt, build SpawnRequest(.normal, touch diameter
  from Tuning, lifetime ∞), call arena?.spawnTarget(req, at: now); on true insert into live.
  registerHit(_:): guard phase is playing, target live, not resolved; remove from live; outcome
  points = 100; arena?.removeTarget(id, .hit(outcome)); nextSpawnAt = hit.timestamp + 1.0; return it.
  Mark the temporary bits with `// M1-TEMP` so M2 can find them.
- Tests (Swift Testing) with a FakeArena: hit live target returns outcome; same id twice → second nil;
  unknown id → nil; tick spawns exactly one target.

PewPewCore/GestureCore:
- HandFrame.swift: `public struct HandFrame: Sendable, Codable { chirality (left/right), timestamp,
  joints: [Joint: SIMD3<Float>] }` where Joint is our own enum mirroring the ARKit joint names we use
  (wrist, thumbKnuckle, thumbIntermediateBase, thumbIntermediateTip, thumbTip, index/middle/ring/
  little Metacarpal/Knuckle/IntermediateBase/IntermediateTip/Tip, forearmWrist). Only tracked joints present.
- HitMath.swift: `resolveTouch(prevTip:, tip:, targets: [TargetSnapshot], forgiveness:) -> TouchResult?`
  TargetSnapshot {id, center, normal, radius}. Segment–sphere test with radius + forgiveness;
  returns nearest target id + ρ (in-plane distance / radius, clamped ≥ 0). Tests: inside, outside,
  fast swept pass-through, two targets picks nearest.

App:
- Arena/PixelTargetTexture.swift: draw a 32×32 pixel archery face (rings from center: Gold #FFC93C,
  Red #E8402A, Blue #2B6FD6, Ink #1B1B1F, Paper #F4F1E8; 1-px Ink boundaries; transparent outside)
  into a 512×512 CGImage by filling 16×16 blocks (nearest-neighbor by construction). Make a
  TextureResource from it (visionOS 2: `TextureResource(image:options:)` async/throws, or
  `TextureResource.generate(from:options:)` — use whichever compiles; semantic .color). Cache it.
- Arena/TargetFactory.swift: make(diameter:) -> Entity: face = generateCylinder(height: 0.006,
  radius: r) with UnlitMaterial(texture) rotated so the flat cap faces +Z; rim = cylinder radius r*1.04,
  height 0.03, PhysicallyBasedMaterial Ink roughness 0.6, behind the face. Add GroundingShadowComponent
  (castsShadow: true). Add CollisionComponent(sphere r) + InputTargetComponent ONLY when look-pinch
  is enabled. If generateCylinder doesn't exist in the SDK, fall back to generatePlane with the
  texture's alpha (UnlitMaterial blending .transparent) + generateBox rim, and say so.
- Arena/ArenaController.swift (@MainActor, implements ArenaRendering): root entity; registry
  [TargetID: TargetEntityRecord] (entity, radius, spawnTime). spawnTarget: temporary placement = random
  point in the Stay Put touch band (§3.7) relative to fixed head (0, 1.5, 0) facing -Z; face toward head
  yaw-only; spawn pop FX; return true. removeTarget(.hit): HitFX hit burst then remove. Expose
  snapshots() -> [TargetSnapshot] (world center, facing normal = entity +Z in world, radius).
- Arena/HitFX.swift: spawn pop (scale 0→1.1→1.0, 0.15 s via move(to:)), hit = swap face to white
  UnlitMaterial for 0.04 s, then 10 pooled 2 cm cubes in ring colors fly 0.25 m outward over 0.35 s
  scaling to 0, then target removed. Times from Tuning.FX.
- Tracking/TrackingService.swift: if HandTrackingProvider.isSupported and authorized, run it; consume
  anchorUpdates in a main-actor Task; convert via HandFrameAdapter (originFromAnchorTransform *
  joint.anchorFromJointTransform, skip !isTracked) into latestLeft/latestRight. Expose
  handTrackingAvailable.
- Interaction/InputCoordinator.swift (@MainActor): update(now:) per hand: prevTip/tip index fingertip
  → resolveTouch against arena.snapshots() → if hit and per-hand cooldown (Tuning.Touch.cooldown)
  passed: session.registerHit(HitEvent(source: .touch, ρ)).
- ArenaView: create AppModel-owned ArenaController + GameSession, set session.arena; subscribe to
  SceneEvents.Update and call input.update(now) then session.tick(now) with now = CACurrentMediaTime();
  store the subscription. Add `.gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { ... })`
  that maps the tapped entity to its TargetID and calls registerHit(source: .lookPinch, ρ: 0.5) —
  enabled only when !handTrackingAvailable. Remove the M0 cube.

Done when: simulator — click target → flash + shards → new target 1 s later; tests pass.
Device — poke with either fingertip works. Do NOT add timer/menus/scoring formula/finger-gun/audio.
```

---

### M2 — Game core: timer, spawns, scoring, stats (Sun Nov 8 – Thu Nov 12)

**Goal:** a complete, unit-tested round engine (without UI): countdown → playing → results, real spawn pacing, lifetimes/expiry, scoring formula, combo, accuracy and reaction stats, DEBUG autoplay.

**Files:**
- Modify `GameSession.swift` (remove all `M1-TEMP`), create `GamePhase.swift`, `GameEvent.swift`, `SpawnDirector.swift`, `ScoreCalculator.swift`, `RoundStats.swift`.
- Tests: `SessionTests` (transitions §8.3 incl. illegal no-ops, abort), `SpawnTests` (first-spawn window, delay ranges, no-spawn tail, warm-up types, concurrency), `ScoreTests` (formula table cases incl. multiplier thresholds and rounding), `StatsTests` (accuracy, avg/fastest, expired vs roundEnded).
- App: `Debug/DebugPanel.swift`, `Debug/AutoplayBot.swift` (DEBUG), temporary "Start 30s" button in the `exit` attachment.

**Acceptance:**
- `swift test` green, ≥ 25 tests, all deterministic (seeded RNG, explicit times).
- Sim: tap temporary Start → (console) countdown 3,2,1,GO → targets spawn/expire per §3.2–3.3 → at 30 s round ends, `RoundResult` printed with correct numbers. Autoplay bot produces ~15–17 spawns / 30 s and plausible stats.
- Device: same with touch.

**Do NOT yet:** SwiftUI lobby/HUD/results visuals (console + temporary button only), difficulty presets UI, moving targets (Normal/Small only; Moving request type exists but weight 0 until M5).

**Ownership:** Kevin (all). Gary reviews `ArenaRendering` changes and wires `.expired` FX (shrink+gray) in `HitFX`.

**Sonnet instructions (M2):**
```text
[paste shared preamble first]

Milestone M2 — real round engine in PewPewCore. Read plan §3 (all), §8.2, §8.3, §11.

1. GamePhase.swift and GameEvent.swift exactly per §8.2 (TutorialStep enum included; tutorial
   behavior comes in M8 — for now start() always goes to countdown).
2. SpawnDirector (struct, pure): inputs Tuning, RoundConfig, RNG, round start/end times. API:
   `mutating func nextRequests(now:, liveCount:) -> [SpawnRequest]` and
   `mutating func targetResolved(at:)`. Rules: concurrency per difficulty; first spawn uniform
   in Tuning.Spawn.firstDelay after GO; after each resolution schedule that slot at
   now + uniform(spawnDelay[difficulty]); never spawn if roundEnd - now < noSpawnTail; during
   warmup only .normal, after that weighted pick (Moving weight forced to 0 until M5 — read from
   Tuning but gate with `allowMoving = false` constant in SpawnDirector, marked // M5).
   Lifetime = base[type] (+touchExtra if controls == .touch) × roomMult (if .roam) × difficultyMult.
   Diameter = (controls == .blaster ? blaster : touch)[type] × difficultyMult × (bigTargets ? 1.4 : 1).
   If arena.spawnTarget returns false, retry that slot after Tuning.Spawn.placementRetry.
3. ScoreCalculator (pure): points(type:, rho:, reactionTime:, streakBefore:) -> HitOutcome per §3.4
   exactly (ring thresholds 0.20/0.40, speed bonus 50 between 0.45 s and 1.50 s, multiplier tiers
   5→1.5, 10→2.0, round to nearest 10). Assisted hits pass rho ≥ 1 → no ring bonus.
4. RoundStats (struct): record hit(outcome), missedShot, expired; produce RoundResult {score, hits,
   missedShots, expired, targetsResolved, shotsFired, accuracy: Double?, reactionTimes, avg, fastest,
   bestStreak, bullseyes, config}. accuracy = hits / (hits + missedShots + expired), nil if 0.
   Targets removed by round end are NOT expired.
5. GameSession: implement §8.3 transitions exactly; illegal calls are no-ops with assertionFailure in
   DEBUG only (use a `strict` flag so tests can verify no-ops without crashing). tick(now:): handle
   countdown ticks (emit .countdownTick(3/2/1) and .go), playing timer (hud.timeRemaining), final
   5 s ticks, expiries (live targets with now > expiresAt → arena.removeTarget(.expired), stats,
   streak = 0, emit), spawns from SpawnDirector, round end (removeAllTargets, results, emit
   .roundEnded). registerHit: guards per §8.2 (incl. timestamp ≤ expiresAt), reaction time =
   hit.timestamp − spawnTime, ScoreCalculator, streak/multiplier, hud update, emit .targetHit and
   .comboChanged when multiplier changes. registerMissedShot: only in .playing; stats + streak = 0.
   Track shotsFired = blaster hits + missed shots.
6. Tests: cover every transition, each formula row in §3.4 with worked numbers, expiry vs hit on the
   same timestamp (hit wins when ≤ expiresAt), no spawns in final 0.8 s, warmup only normal,
   concurrency 2 on hard, accuracy nil when no attempts, roundEnded targets not counted as expired,
   abort from playing gives no result.
7. App (DEBUG only): Debug/DebugPanel.swift attachment with buttons Start 30s, Hit nearest (ρ 0.5),
   Bullseye (ρ 0.1), Miss shot, Expire all (for testing UI), Autoplay toggle. Debug/AutoplayBot.swift:
   for each live target, after uniform(0.45...1.3) s, 75% registerHit(source: .debug, ρ uniform
   0...0.8) else let it expire; 10% chance per second of a missed shot. Print GameEvents and the
   RoundResult to the console.
   Gary's HitFX already handles .hit; add .expired (tint Miss Gray, shrink to 0 in 0.2 s) and
   .roundEnded (instant fade/remove) in ArenaController.removeTarget.

Done when: swift test green (≥ 25 tests). Simulator: Debug Start 30s + Autoplay runs a full round and
prints a sane RoundResult. Do NOT build lobby/HUD/results SwiftUI screens or moving targets.
```

---

### M3 — UI shell & full touch loop (Wed Nov 11 – Sun Nov 15) → **MUST-1**

**Goal:** it feels like a finished small app on touch: launcher → lobby → countdown → HUD → results → play again / menu → exit.

**Files:**
- Kevin: `UI/Theme.swift`, `UI/LobbyPanel.swift`, `UI/CountdownView.swift`, `UI/PlayHUD.swift`, `UI/ResultsPanel.swift`, `App/PlayerSettings.swift`; polish `LauncherView.swift`; add `Resources/Fonts/PressStart2P-Regular.ttf` + `UIAppFonts`.
- Gary: `Tracking/HeadPose.swift` (run `WorldTrackingProvider`), `Arena/PanelPlacer.swift` (lobby/results/countdown placement + HUD lazy-follow §1.3), `ArenaView.swift` attachments + phase-driven visibility, arena-forward capture on Start, Stay Put touch band relative to arena forward.
- Remove the temporary "exit"/Start debug buttons from non-DEBUG UI.

**Acceptance:**
- Sim: whole loop playable with Look & Pinch + debug autoplay; results numbers match console `RoundResult`; 30 s default; 60 s works; Play Again skips lobby; Menu returns to lobby; Exit Arena returns to launcher; reopening works twice in a row.
- Device: whole loop with touch; lobby appears in front wherever you face; HUD stays readable and out of the way when turning 90° (lazy-follow catches up, never jitters when still); Digital Crown exit mid-round → launcher returns, re-entering shows lobby (no stale targets).
- Kevin's checklist: no text < 17 pt; all buttons ≥ 60 pt; Dynamic Type at default only (OK).

**Do NOT yet:** tutorial, difficulty picker, Space toggle (show it disabled with "Soon"), audio, finger-gun UI beyond a disabled "Blaster" segment.

**Ownership:** Kevin — all SwiftUI views and settings. Gary — placement/follow, head pose, attachment hosting.

**Sonnet instructions (M3, Kevin's half):**
```text
[paste shared preamble first]

Milestone M3 (UI half) — SwiftUI screens hosted as RealityView attachments. Read plan §1, §3.1,
§3.5, §5.2, §5.3, §8.2–§8.4.

1. UI/Theme.swift: Color tokens (paper, ink, ringBlue, targetRed, bullseyeGold, blasterMint,
   missGray) from §5.2; Font helpers: pixel(size) = Font.custom("PressStart2P-Regular", size:)
   with fallback .system(design: .monospaced).weight(.black); number(size) = .system(size:,
   weight: .heavy, design: .rounded).monospacedDigit(). Register the font via UIAppFonts in
   Info.plist (file in Resources/Fonts).
2. App/PlayerSettings.swift (@MainActor @Observable): length (30/60, default 30), controls, space,
   difficulty, bigTargets, tutorialDone — persisted with UserDefaults; `var roundConfig: RoundConfig`.
3. UI/LobbyPanel.swift (~600×560 pt, .glassBackgroundEffect()): pixel logo "PEWPEW" in targetRed;
   segmented pickers: Round "30s | 60s"; Controls "Touch | Blaster" (Blaster disabled with caption
   "Coming soon" until AppModel.blasterEnabled); Space "Stay Put | Roam Room" (disabled, "Soon" — M5);
   big prominent "Start" (tint targetRed); secondary "Exit Arena". If AppModel.handTrackingAvailable
   == false show the Look & Pinch banner text from §2.8.
4. UI/CountdownView.swift: shows 3/2/1/GO! from session phase/time in pixel font 140 pt bullseyeGold,
   each number scales 1.3→1.0 over 0.2 s (skip if reduce motion).
5. UI/PlayHUD.swift (~360×140 pt, glass, allowsHitTesting(false)): time left as integer seconds
   ("23") number font 64 pt — turns bullseyeGold and pulses during the last 5 s; score number font
   36 pt; combo badge "×1.5"/"×2" (hidden at 1.0, pops on change); hint line (session.hud.hint).
6. UI/ResultsPanel.swift (~640×520 pt): per §3.5 — hero SCORE (pixel 64 pt gold), chips
   "30s · Touch · Stay Put", 2×3 grid Hits / Accuracy % ("—" if nil) / Avg ms / Fastest ms /
   Best streak / Bullseyes, Blaster-only line "Shots fired: N", buttons Play Again (prominent) and Menu.
   Reaction times shown as integer ms.
7. Wire buttons: Start → session.config = settings.roundConfig; session.start(now:); Play Again →
   session.start(now:); Menu → session.returnToLobby(); Exit Arena → dismissImmersiveSpace().
8. LauncherView polish: pixel logo, subtitle, Enter Arena, footnote "Uses hand tracking. Best in a
   clear, well-lit space."

Coordinate with ArenaView (Gary's half) for attachment ids: "lobby", "countdown", "hud", "results".
Each view reads AppModel/session from the environment. Do NOT build tutorial, difficulty, audio.
```

**Sonnet instructions (M3, Gary's half):**
```text
[paste shared preamble first]

Milestone M3 (spatial half) — head pose, panel placement, HUD lazy-follow. Read plan §1.1, §1.3,
§1.4, §3.7, §4.1, §6.2, §6.4.

1. Tracking/HeadPose.swift (@MainActor): run WorldTrackingProvider in TrackingService when supported.
   func current(now) -> Transform? via queryDeviceAnchor(atTimestamp: now) (originFromAnchorTransform).
   Simulator/unsupported fallback: position (0, 1.5, 0), forward -Z. Provide yawForward (XZ-projected).
2. Arena/PanelPlacer.swift: place(entity, distance:, pitchDegrees:) using current head pose, yaw-only
   facing toward the user. Rules: lobby & results 1.2 m / −8°; countdown at arenaForward 1.6 m eye
   height; tutorial card 0.9 m / −20° (M8). HUD lazy-follow per §1.3 with Tuning.HUD values
   (distance 1.1, pitch −18°, yaw threshold 25°, position threshold 0.4 m, time constant 0.25 s,
   settle 5°/0.05 m). Fallback HUD position (0, 1.25, −1.1).
3. ArenaView: register attachments "lobby", "countdown", "hud", "results" (Kevin's views; use
   placeholders if not merged yet). Show/hide by session.phase (only one panel at a time; HUD only
   in .playing). Re-place lobby/results each time they become visible. Call hudFollower.update(now)
   in the frame driver after session.tick.
4. Arena forward: when session enters .countdown, capture head position + yawForward into
   ArenaController.arenaFrame; spawn bands for Stay Put are relative to arenaFrame (§3.7 touch band
   for now). Move M1's fixed-head placement into Placement/PlacementService.swift
   (air-spawn only, candidates + validation per §4.2 steps 1,3,5,6; min separation 0.15 m touch).
5. Lifecycle: ArenaView .onDisappear → tracking.stop(), session.returnToLobby(), arena.removeAllTargets(),
   openWindow(id: "launcher"). Observe scenePhase: if not .active while .playing → returnToLobby().

Done when: device — lobby appears where I face; HUD follows lazily when I turn; crown-exit mid-round
then re-enter shows a clean lobby. Do NOT add planes, finger-gun, audio.
```

---

### M4a — Finger-gun pose + aim (Mon Nov 9 – Sat Nov 14, parallel)

**Goal:** on device, each hand shows the correct armed/cocked state and a stable reticle; nothing fires yet. Fixtures recorded for tests.

**Files:** `Debug/HandRecorder.swift`, `Debug/GestureLabPanel.swift`, `GestureCore/FingerGunClassifier.swift`, `FingerGunStateMachine.swift` (states up to ARMED_COCKED; FIRE stubbed), `AimFilter.swift`, `Arena/AimVisuals.swift`, extend `InputCoordinator`. Tests + `Fixtures/` (at least: `gun_cocked_right.json`, `gun_cocked_left.json`, `open_hand.json`, `fist.json`, `point_no_thumb.json`, `resting_hands.json`, `pinch.json`, `hammer_snaps_right.json`).

**Acceptance:**
- Device (Gesture Lab): forming the pose arms within ~0.1 s for both hands; open hand / fist / pinch / hands resting on lap never arm; thumb up/down flips filled/hollow reticle; reticle jitter at 3 m visually < target radius of a Small target (13 cm) when holding still.
- Classifier tests pass on all fixtures (expected labels in fixture metadata).

**Do NOT yet:** firing, shot hits, Blaster spawn distances.

**Ownership:** Gary (all). Kevin: none (on M2/M3).

**Sonnet instructions (M4a):**
```text
[paste shared preamble first]

Milestone M4a — finger-gun pose detection and aim visuals, no firing yet. Read plan §2.2, §2.4, §2.6,
§2.7, §6.5, §11 (Gesture rows).

1. Debug/HandRecorder.swift (DEBUG): button "Record 5 s" in a GestureLab attachment; captures every
   HandFrame (both hands) for 5 s and writes JSON {label: String, frames: [HandFrame]} to the app's
   Documents dir as <label>_<timestamp>.json (label chosen from a Picker: gun_cocked, gun_uncocked,
   hammer_snaps, open_hand, fist, point_no_thumb, resting, pinch). Gary pulls files via Xcode →
   Devices → Download Container and copies them into Tests/GestureCoreTests/Fixtures (add as
   test resources in Package.swift).
2. GestureCore/FingerGunClassifier.swift (pure): func metrics(frame:, headForward:) -> GunMetrics
   {handScale, indexStraightness, curls [middle, ring, little], thumbT, aimDir, aimOrigin, pointingAway};
   func isGunPose(metrics, armed: Bool, tuning) -> Bool using arm/release hysteresis (0.90/0.82),
   curl ≤ 1.25 for ≥ 2 of 3, pointingAway dot > 0.2. Exact formulas in §2.2 and §2.4.
3. GestureCore/AimFilter.swift: exponential smoothing on direction (alpha from Tuning), re-normalize;
   ring buffer of last 24 (timestamp, origin, dir); func sample(at time) -> nearest.
4. GestureCore/FingerGunStateMachine.swift: per-hand struct implementing §2.7 states UNTRACKED, IDLE,
   ARMED_UNCOCKED, ARMED_COCKED (+ FIRE, COOLDOWN declared but FIRE transition disabled behind
   `fireEnabled = false` until M4b). armFrames = 4, grace 0.15 s, cocked t ≥ 0.45.
   `mutating func update(frame: HandFrame?, headForward:, now:) -> GunOutput {state, aim, metrics}`.
5. Tests: synthetic poses (build HandFrames from simple joint layouts) + every fixture: gun_cocked*
   frames arm within 4 frames and are ≥ 90% armed after; open_hand/fist/resting/pinch never arm
   (≤ 1% frames); thumb up/down toggles cocked on hammer fixture.
6. Arena/AimVisuals.swift: per hand — 8 mm mint sphere at index tip when armed; 2 mm × 0.6 m mint
   beam (OpacityComponent 0.35) along aim; reticle ring (mint, constant 1.2° angular size) at
   impact point on the hovered target (use HitMath plane intersection, no assist yet) else 3 m along
   ray; filled when cocked, hollow when uncocked; hovered target scales 1.06 + mint halo disc behind.
   All hidden when not armed.
7. InputCoordinator: run one FingerGunStateMachine per hand each frame from TrackingService frames;
   feed AimVisuals. Touch path unchanged.
8. Debug/GestureLabPanel.swift (DEBUG attachment, toggled from DebugPanel): per hand state, metrics to
   2 decimals, fire count, and sliders overriding Tuning.Gesture values at runtime (store overrides in
   a @MainActor Observable GestureTuningOverrides used by InputCoordinator).

Done when: device — reticle appears only for finger-gun pose with either hand, flips filled/hollow with
thumb, steady at 3 m; tests pass on recorded fixtures. Do NOT fire or score shots yet.
```

---

### M4b — Fire + shot hits (Sun Nov 15 – Thu Nov 19) → **MUST-2 gate**

**Goal:** the round is fully playable with the finger-gun; Blaster becomes the default control.

**Files:** finish `FingerGunStateMachine` (FIRE, COOLDOWN, snap window, onset), `HitMath.resolveShot` (+assist), `InputCoordinator` (shot → `registerHit` / `registerMissedShot`), `HitFX` (muzzle, tracer, miss puff, reticle kick), `PlacementService` Blaster band (Stay Put), `LobbyPanel` enable Blaster + default `.blaster` when `handTrackingAvailable`, `ResultsPanel` shots fired line; tests for shot resolution and fire FSM; Plan-B "Auto-trigger" dwell option behind DEBUG toggle (only promote to lobby if gate fails).

**Acceptance (gate, device, Thu Nov 19):**
- 3 people (including one first-timer) each play a 30 s Blaster round: **≥ 90 % of intentional shots register a shot event** (Gesture Lab fire count vs. self-reported), **0 false fires** during 60 s of idle hands-in-lap + 60 s of talking with hands, **≥ 70 % hit rate** at Normal for Gary.
- Aim on fire does not visibly drop (lookback works): shooting a Small target at 2.5 m dead-center lands ρ < 0.5 most of the time.
- Results show Shots fired and accuracy that includes missed shots.
- If gate is missed: keep tuning Nov 20–24 (post-gate tiers give way in the §12.2 cut order: M8 extras, then M6), and enable Plan B toggle in the lobby by Tue Nov 24 latest.

**Do NOT yet:** dual-weapon, skins, voice, other gestures.

**Ownership:** Gary — FSM, HitMath, FX, placement band, tuning. Kevin — Blaster toggle/default, results line, missed-shot stats tests, gate test protocol + logging sheet.

**Sonnet instructions (M4b):**
```text
[paste shared preamble first]

Milestone M4b — finger-gun firing, shot resolution, blaster mode. Read plan §2.3, §2.4, §2.6, §2.7,
§3.6, §3.7, §11. M4a (pose + aim visuals) is merged.

1. FingerGunStateMachine: enable FIRE. Track the stroke: when cocked and thumbT first drops below
   fireOnsetThreshold (0.40) record onsetTime; if thumbT ≤ fireThreshold (0.27) within fireSnapWindow
   (0.25 s) of onset → emit .fire(onsetTime, now); else if the stroke exceeds the window, abandon it
   (require re-cock). Then COOLDOWN 0.22 s → ARMED_UNCOCKED; next shot requires t ≥ 0.45 again.
   Holding the thumb down never auto-fires.
2. HitMath.resolveShot(ray origin/dir, targets, assistDegrees, maxRange) -> ShotResult?: per §2.4 —
   direct hit if ray hits disc (ρ ≤ 1); else assisted if angle(ray, center−origin) ≤ assist (ρ := 1);
   choose smallest angle; ignore targets behind origin or beyond maxRange. Tests: dead center ρ≈0,
   edge, assisted, two targets, behind, beyond range.
3. InputCoordinator: on .fire, aim = aimFilter.sample(at: onsetTime − aimLookback) (0.045 s);
   assist = Tuning assist × (Easy 5/3.5) × (bigTargets ? 1.5 : 1). Hit → session.registerHit(
   HitEvent(source: .blaster, timestamp: fireTime, ρ)); no hit → session.registerMissedShot(at:
   fireTime, source: .blaster). If registerHit returns nil (e.g. already resolved) count as miss.
4. HitFX: muzzle flash (white 1.5 cm square sprite at index tip, 60 ms), tracer (1.5 mm mint box tip→
   impact or ray end, 70 ms), reticle kick (1.4→1.0 over 120 ms), miss puff (gray cubes, small) at ray
   end (impact distance or 3 m).
5. PlacementService: Stay Put Blaster band per §3.7 (1.8–3.2 m, ±35°, −10°…+15°, min separation 20°)
   relative to arenaFrame. SpawnDirector already sizes by controls.
6. UI: LobbyPanel enables "Blaster"; PlayerSettings default controls = .blaster when hand tracking is
   available (keep the user's saved choice if one exists). ResultsPanel shows "Shots fired: N" in Blaster.
7. Plan B (DEBUG toggle in GestureLab, "Auto-trigger"): while armed and hovering the same target
   (within assist) for dwellFire (0.35 s), fire automatically. Must reuse the same fire path.
8. Gesture Lab: add counters for fires, hits, misses, and a 60 s "idle false-fire test" timer that
   counts fires while active.

Done when: device — full 30 s Blaster round playable with either hand; missed shots lower accuracy;
tests pass. Do NOT add other weapons, skins, voice, or new gestures.
```

---

### M5 — Variety, difficulty, movement toggle (Goal; Fri Nov 20 – Sun Nov 22, Kevin's core prep from Mon Nov 16)

**Goal:** Small and Moving targets, Easy/Normal/Hard, Stay Put / Roam Room — all from the lobby.

**Files:** `SpawnDirector` (enable Moving, difficulty tables), tests; `Arena/TargetMotion.swift` (component + system), `TargetFactory` (attach motion; idle bob), `PlacementService` (Roam bands relative to live head, height-above-floor clamps), `LobbyPanel` (Difficulty picker, Space enabled + copy from §3.7), `ResultsPanel` chips.

**Acceptance:**
- Tests: difficulty multipliers, weights (statistical test over 10 000 seeded picks within ±2 %), roam lifetime ×1.5.
- Sim: autoplay at Hard shows two concurrent targets; Moving targets strafe smoothly at the specified amplitude/period.
- Device: Roam Room spawns targets behind you (spawn blip — placeholder `print` until M7a audio) and within 0.6–2.0 m height; switching Space is disabled mid-round.

**Do NOT yet:** planes/walls (M6), decoys, adaptive difficulty.

**Ownership:** Kevin — SpawnDirector, difficulty, lobby UI. Gary — motion system, roam placement.

**Sonnet instructions (M5):**
```text
[paste shared preamble first]

Milestone M5 — target variety, difficulty presets, movement toggle. Read plan §3.2, §3.3, §3.6, §3.7,
§3.8, §4.2, §11.

Core (Kevin):
1. SpawnDirector: remove the `allowMoving` gate. Weights per difficulty from Tuning (Normal 60/25/15,
   Easy 80/10/10, Hard 40/35/25), warmup still normal-only. Motion for .moving = .strafe(amplitude,
   period) from Tuning by controls (blaster 0.6 m / 3.2 s, touch 0.15 m / 3.0 s), period divided by
   speed multiplier (Easy 0.7, Hard 1.3, reduceMotion 0.5). Concurrency, delays, lifetimes, sizes
   per difficulty from Tuning.
2. Tests: weight distribution over 10 000 seeded picks within ±2%; each multiplier; hard concurrency.
3. LobbyPanel: Difficulty "Easy | Normal | Hard" (default Normal); Space enabled with captions
   "Stay in one spot" / "Walk around — clear some space first". Pickers disabled outside lobby.
   ResultsPanel chips include difficulty.

App (Gary):
4. Arena/TargetMotion.swift: TargetMotionComponent {base: SIMD3<Float>, axis: SIMD3<Float> (target's
   right vector at spawn), amplitude, period, phase, bobAmplitude 0.01, bobPeriod 2.0}; TargetMotionSystem
   (EntityQuery on the component) updates position = base + axis·A·sin(2π(t/period)+phase) +
   up·bob·sin(2πt/bobPeriod). Bob disabled when reduceMotion. Register in PewPewApp.init.
   Snapshots for hit tests must read the live (moved) world position.
5. PlacementService Roam: relative to LIVE head pose at spawn time; blaster 2.0–5.0 m, azimuth ±120°,
   height 0.6–2.0 m above floor (y); touch 0.6–2.2 m, ±90°, 0.8–1.6 m. Stay Put unchanged.
   For moving targets ensure base ± amplitude stays inside the band (shrink amplitude if needed).

Done when: tests pass; Hard shows 2 targets; Moving strafes; Roam spawns all around me on device.
Do NOT add plane/wall placement, decoys, or adaptive difficulty.
```

---

### M6 — Surface placement (Goal tier; Sat Nov 21 – Tue Nov 24; first Goal item to cut)

**Goal:** in Roam Room, about half the targets appear on real walls/tables; everything else and every failure falls back to air.

**Files:** `Tracking/PlaneStore.swift` (run `PlaneDetectionProvider(alignments: [.horizontal, .vertical])`, keep `[UUID: PlaneAnchor]` with classification + extent), `PlacementService` (steps 2–3 of §4.2), `LobbyPanel` note for denied sensing; DEBUG toggle to visualize planes as translucent mint quads.

**API flags:** `PlaneAnchor.classification` values `.wall .floor .ceiling .table .seat .door .window` exist since visionOS 1. Extent: visionOS 2 exposes `geometry.extent` (`width`, `height`, `anchorFromExtentTransform`) — if not available, compute bounds from `geometry.meshVertices` projected onto the plane.

**Acceptance (device):** in a normal room, Roam mode puts targets flush on walls (5 cm off, facing out) and upright on tables; no target appears behind a wall or inside a desk edge in 3 rounds; with world sensing denied the game still runs (air only) and shows the note; Stay Put unaffected.

**Do NOT:** scene reconstruction mesh, occlusion, persistent anchors.

**Ownership:** Gary (all); Kevin — lobby note copy.

**Sonnet instructions (M6):**
```text
[paste shared preamble first]

Milestone M6 — wall/table placement in Roam Room with air fallback. Read plan §4 (all), §6.2, §11.

1. Tracking/PlaneStore.swift (@MainActor): if PlaneDetectionProvider.isSupported and worldSensing
   authorized, run PlaneDetectionProvider(alignments: [.horizontal, .vertical]) in the existing
   ARKitSession (restart session with all providers if needed). Consume anchorUpdates (added/updated/
   removed) into [UUID: PlaneInfo] {transform (originFromAnchorTransform), classification, normal,
   width, height, extentTransform}. Use geometry.extent if it exists in the SDK; otherwise compute a
   bounding rect from geometry.meshVertices in plane space — tell me which you used.
   Ignore planes smaller than 0.5 × 0.5 m. Expose walls and tables/seats.
2. PlacementService (Roam only, when planes exist): with probability surfaceChance (0.5) try surface
   first, per §4.2 step 2: wall = ray from head along candidate dir intersect wall rectangles, nearest
   within band → position hit + normal·0.05, facing normal; table/seat = random point inset 0.15 m,
   lifted by r + 0.02, facing head yaw-only. Validate per step 3 including "not behind a wall"
   (segment head→candidate must not cross a nearer wall rectangle). Fall back per steps 5–6.
   Moving targets on walls strafe along the wall's horizontal axis; clamp to the rectangle.
3. Pure geometry (ray–rectangle, segment–rectangle) goes in GestureCore/HitMath.swift or a new
   PlacementMath.swift in GestureCore with tests.
4. DEBUG: toggle in DebugPanel "Show planes" renders translucent mint quads for walls and gold for
   tables.
5. LobbyPanel: when worldSensing is denied/unavailable and Space == Roam, caption "Room scan off —
   targets float in the air."

Done when: device — Roam targets appear on walls/tables about half the time, never behind walls;
sensing denied still plays. Do NOT add scene reconstruction, occlusion, or WorldAnchors.
```

---

### M7 — Polish & feedback tier (Goal; Fri Nov 20 – Wed Nov 25; after the MUST-2 gate)

**Goal:** it sounds and feels like an arcade cabinet: every important moment has an audio cue *and* a visual twin. High-level only; audio specifics live in `docs/sound-design.md`, visual specifics in `docs/visual-design-spec.md` §4–§7. Starts only after MUST-2 passes; every item is cuttable (§12.2).

| Feature | Audio (`docs/sound-design.md`) | Visual twin | Sub-milestone |
| --- | --- | --- | --- |
| Core event SFX + spatial emitters | `spawn*`, `hit*`, `bullseye`, `expire`, `miss`, `pew*`, `count`/`go`, `end` | (existing FX) | M7a |
| Music system: lobby loop → silent countdown → round loop → final-10 s intense → whistle → results sting; Music toggle; ducking | `music/*` | — | M7a |
| Last-seconds ticks + intense music switch | `tick` (n ≤ 5), crossfade at 10 s | Gold pulsing timer (n ≤ 5) | M7a (audio) · M7b (HUD) |
| Blaster cock + lock-on feedback | `blaster_cock`, `lock_on` | Armed cube; lock-on brackets pop | M7a (cues) · M7b (visual check) |
| Combo milestones ×1.5 / ×2, combo break | `combo`, `combo_x2`, `combo_break` (off by default) | HUD combo chip pop; ×2 chip Gold | M7b |
| Target expire feedback | `expire` | Expire warning blink + gray shrink/drop | M7b |
| Score tally on results | `tally` | Count-up over 0.8 s (static under Reduce Motion) | M7b |
| New high score / session best (in-memory, per run) | `new_high_score` (1.0 s after the sting) | "NEW BEST" chip on results | M7b |
| Arena open / close transitions | `arena_open`, `arena_close` | Lobby fades in after preload; panels fade out before dismiss | M7b |
| Score popups, Big Targets, Reduce Motion, Increase Contrast | UI toggles (`ui_toggle_*`) | Visual spec §4.4, §7 | M7b |

Persistent high scores (`@AppStorage`) stay **Stretch**; the session best above is in memory only.

#### M7a — Audio & music system (Fri Nov 20 – Tue Nov 24)
**Scope:** asset copy from `docs/audio/` into `pew/PewPew/Resources/Audio/`, `SoundCue` mapping (pure, tested), `AudioBank` (pooled spatial emitters, hand and UI channels, voice cap), `MusicDirector` (the music state machine), Music toggle, `.finalSecondsTick` for n = 10…1, cock/lock-on/session-best hooks.
**Acceptance:** every cue plays from the right place; spawn cue behind you is locatable with eyes closed; music runs lobby → silent countdown → round → intense at 10 s → whistle → sting → lobby with no gaps or clicks; Music toggle works; no hitch on first hit.
**Ownership:** Gary — AudioBank, hand/ray cues, lock-on hook. Kevin — `SoundCue` + tests, MusicDirector, Music toggle, `finalSecondsTick` change.

**Sonnet instructions (M7a):**
```text
[paste shared preamble first]

Milestone M7a — audio & music system (Polish & feedback tier). Paste and follow the full prompt in
docs/sound-design.md §8 ("M7-audio"), with one path change: the source WAVs are in the repo at
docs/audio/sfx/ and docs/audio/music/ (not store media/audio/); copy them to
pew/PewPew/Resources/Audio/SFX/ and .../Music/ unchanged. docs/sound-design.md supersedes plan §5.5
and visual-design-spec §6 for all audio. Do not touch tutorial flow (M8) or visual polish (M7b).
```

#### M7b — Feedback moments & accessibility (Sun Nov 22 – Wed Nov 25)
**Scope:** the visual twins and UX in the table above: score popups, expire warning + expire FX, combo chip pop (and optional combo-break visual), session best + "NEW BEST" chip, results tally, final-seconds HUD pulse check, arena open/close fades, lock-on brackets pop with the `lock_on` cue, Big Targets, Reduce Motion, Increase Contrast.
**Acceptance:** in one playtest round each feedback moment is seen/heard at least once; Reduce Motion and Increase Contrast change exactly the behaviors in visual spec §7; Big Targets enlarges targets and assist; no frame hitches on hit (pools prewarmed).
**Ownership:** Gary — popups, expire FX, brackets, FX reduce-motion, arena transitions. Kevin — combo chip, session best, results tally, HUD final-seconds, lobby Big Targets toggle, reduce-motion plumbing into `RoundConfig`.

**Sonnet instructions (M7b):**
```text
[paste shared preamble first]

Milestone M7b — feedback moments & accessibility (Polish & feedback tier). M7a (audio) is merged.
Follow docs/visual-design-spec.md §9 "M7" block items 1–3, 5 and 7 (popups, expire warning, bullseye
HUD flash, results tally, accessibility); skip its item 4 (tutorial card → M8) and item 6 (audio →
already done per docs/sound-design.md). Also:
- AppModel keeps an in-memory sessionBest; ResultsPanel shows a "NEW BEST" chip (Press Start 2P 24 pt,
  Gold) when beaten; the new_high_score cue already fires from M7a.
- HUD combo chip pops on .comboChanged; a combo-break visual (chip shrinks out) is fine, but the
  combo_break sound stays off by default.
- Arena open: lobby panel appears (opacity/scale per visual spec §5.3) after preload/arena_open.
  Exit: panels fade out over 0.3 s while arena_close plays, then dismiss.
- LobbyPanel: Big Targets toggle; pass @Environment(\.accessibilityReduceMotion) into RoundConfig.
Do NOT: build the tutorial, add new sounds, persist scores, or change scoring rules.
```

---

### M8 — Tutorial & demo (post-core; Tue Nov 24 – Thu Nov 26)

**Goal:** a first-timer learns to poke and finger-gun in ≤ 30 s without spoken help. Post-core tier: starts after MUST-2 and the Goal tier are on track, never delays them, and is cut before Goal items (§12.2). Outline level; the step design is §7, the card look is visual spec §5.3 "Tutorial card".

**Rough flow:** first Start (or "How to Play") → **Touch** step (poke a near target) → **Gun pose** step (reticle appears when cocked) → **Fire** step (hit a target at 2 m) → "Nice!" → countdown (or back to lobby from How to Play). Skippable at any time; steps 2–3 skipped in Touch / Look & Pinch; `tutorial_success` per step; lobby music ducked.

**Acceptance:** two people who have never used PewPew finish in ≤ 40 s unaided and then play a Blaster round; Skip works from every step; the tutorial never auto-repeats after the first run; no score/stats recorded.

**Stretch — attract / demo mode:** self-playing round behind the idle lobby using the autoplay bot (§7). Only if every row is green Wed Nov 25; otherwise post-demo.

**Ownership:** Kevin — `GameSession` tutorial phases + tests, `TutorialCard`, How to Play. Gary — tutorial target placement, `tutorialPoseDetected()` from InputCoordinator, card placement 0.9 m / −20°.

**Sonnet instructions (M8):**
```text
[paste shared preamble first]

Milestone M8 — tutorial (post-core tier). Read plan §7, §8.2, §8.3 and docs/visual-design-spec.md §5.3
"Tutorial card" (mockup docs/visual/countdown-and-tutorial.png).
1. GameSession: implement the TutorialStep flow and transitions in §8.3 (first-run start → tutorial;
   How to Play → tutorial → lobby; skip; never auto-repeat). Tutorial targets are SpawnDirector-
   independent (touch-size at 0.5 m, blaster-size at 2 m), lifetime ∞, no score/stats. Steps 2–3
   skipped for Touch controls or no hand tracking. Emit .tutorialAdvanced per step. Swift Testing
   tests for the flow.
2. InputCoordinator calls tutorialPoseDetected() when any hand reaches ARMED_COCKED in .gunPose.
3. UI/TutorialCard.swift per the visual spec (pixel hand frames, pips, copy from §7, Skip), placed by
   PanelPlacer at 0.9 m / −20°. LobbyPanel "How to Play" button.
Do NOT build attract mode, change scoring, or add sounds (tutorial_success and the duck are M7a hooks).
```

**Sonnet instructions (Stretch — attract mode, only if green Wed Nov 25):**
```text
[paste shared preamble first]

Stretch — lobby attract mode. Read plan §7 "Attract / demo mode". Extract the autoplay bot's decision
logic into a release-safe AttractDirector (Debug/AutoplayBot stays DEBUG-only and reuses it). After
~20 s of lobby idle, run a scoreless demo round behind the lobby panel (normal spawn + hit FX, SFX
muted, lobby music continues); stop instantly on any pinch, panel interaction or hand raised toward
the panel, removing all demo targets. Never records stats or sessionBest. Off in DEBUG autoplay tests.
```

---

### M9 — Freeze & demo (Fri Nov 27 – Mon Nov 30)

**Goal:** a stable, rehearsed demo build that can't expire.

**Steps:**
- **Fri Nov 27 feature freeze.** Only bug fixes after this; every fix needs a device re-test of the 2-minute script.
- Sat Nov 28: full device test checklist (§13) in the actual demo room if possible (lighting matters for hand tracking).
- **Sun Nov 29 demo freeze:** tag `v1.0-demo` on `main`; Release build installed on the Vision Pro.
- **Mon Nov 30:** fresh install (free provisioning: this resets the 7-day clock to Dec 7), rehearse twice, charge battery, record a backup screen capture (visionOS Control Center → Record My View) of a full round as a fallback video.
- Demo script (2–3 min): Launcher → Enter Arena → lobby explained in one sentence → tutorial (gun steps; if M8 was cut, presenter explains with the static How to Play card) → 30 s Blaster round on Normal Stay Put → results walkthrough → Play Again in Roam Room (if M6 landed) → Exit.
- README final: build, deploy (personal team), play, troubleshooting (re-sign after 7 days; Developer Mode; hand tracking permission).

**Sonnet instructions (M9):**
```text
[paste shared preamble first]

Milestone M9 — freeze. No new features. Tasks:
1. Remove or #if DEBUG-guard every debug UI, print, and M*-TEMP marker; ensure a Release build has
   no Debug panel, Gesture Lab, or plane visualizers.
2. Fix compiler warnings where trivial; do not refactor.
3. Update README.md: requirements, build & deploy with a personal Apple ID team (profiles expire after
   7 days → redeploy), Wi-Fi pairing, Developer Mode, permissions, how to play, known limitations
   (simulator uses Look & Pinch; hand tracking needs good lighting), troubleshooting.
4. Add docs/demo-script.md with the 2–3 minute script from plan §10/M9.
Report any bug you notice instead of fixing it if the fix touches more than one file.
```

---

## 11. Tunables (single source of truth → `GameCore/Tuning.swift`)

| Group | Name | Value | Notes |
| --- | --- | --- | --- |
| Round | `lengths` | [30, 60] s | default 30 |
| Round | `countdownStep` / `goDuration` | 1.0 s / 0.5 s | 3·2·1·GO = 3.5 s |
| Round | `finalWarnSeconds` | 5 | gold + tick |
| Round | `finalTickFrom` | 10 | `.finalSecondsTick` n = 10…1; intense music at 10 (M7a) |
| Round | `resultsDelay` | 0.6 s | after whistle |
| Spawn | `firstDelay` | 0.4–0.9 s | after GO |
| Spawn | `delay` Easy / Normal / Hard | 0.6–1.4 / 0.35–1.10 / 0.25–0.80 s | after resolution |
| Spawn | `maxConcurrent` E/N/H | 1 / 1 / 2 | |
| Spawn | `noSpawnTail` | 0.8 s | |
| Spawn | `warmup` | 5 s | normal only |
| Spawn | `weights` N/S/M — E / N / H | 80/10/10 · 60/25/15 · 40/35/25 % | |
| Spawn | `placementRetry` | 0.1 s | |
| Spawn | `candidates` | 12 | per request |
| Targets | `lifetime` blaster N/S/M | 2.6 / 2.4 / 3.0 s | |
| Targets | `touchLifetimeExtra` | +0.6 s | |
| Targets | `lifetimeMult` E/N/H · roam | 1.3 / 1.0 / 0.8 · ×1.5 | |
| Targets | `diameter` blaster N/S/M | 0.40 / 0.26 / 0.40 m | |
| Targets | `diameter` touch N/S/M | 0.20 / 0.14 / 0.20 m | |
| Targets | `sizeMult` E/N/H · bigTargets | 1.15 / 1.0 / 0.85 · ×1.4 | |
| Targets | `rimDepth` / `rimScale` / `faceThickness` | 0.03 m / 1.04 / 0.006 m | |
| Targets | `strafe` blaster / touch | A 0.6 m, T 3.2 s / A 0.15 m, T 3.0 s | |
| Targets | `speedMult` E/N/H · reduceMotion | 0.7 / 1.0 / 1.3 · ×0.5 | |
| Targets | `bob` | 0.01 m, 2.0 s | off w/ reduce motion |
| Bands | Stay Put blaster | 1.8–3.2 m, az ±35°, el −10°…+15° | vs arena forward |
| Bands | Stay Put touch | fwd 0.42–0.58 m, lat ±0.28 m, vert eye −0.40…−0.05 m | |
| Bands | Roam blaster | 2.0–5.0 m, az ±120°, y 0.6–2.0 m | vs live head |
| Bands | Roam touch | 0.6–2.2 m, az ±90°, y 0.8–1.6 m | |
| Bands | `minSeparation` blaster / touch | 20° / 0.15 m | |
| Placement | `surfaceChance` | 0.5 | Roam only |
| Placement | `wallOffset` / `tableInset` / `minPlaneSize` | 0.05 m / 0.15 m / 0.5×0.5 m | |
| Placement | `lastResort` blaster / touch | 2.0 m / 0.5 m ahead, eye −0.1 m | |
| Score | `base` N/S/M | 100 / 150 / 200 | |
| Score | `ringBonus` gold ≤0.20 / red ≤0.40 | +100 / +50 | |
| Score | `speedBonus` | max 50, full ≤0.45 s, zero ≥1.50 s | |
| Score | `comboTiers` | streak ≥5 ×1.5, ≥10 ×2.0 | reset on miss/expire |
| Score | `rounding` | nearest 10 | |
| Gesture | `armFrames` | 4 | ~45 ms @ 90 Hz |
| Gesture | `poseGrace` | 0.15 s | |
| Gesture | `indexStraightArm` / `Release` | 0.90 / 0.82 | |
| Gesture | `curlMax` / `curledRequired` | 1.25 / 2 of 3 | |
| Gesture | `pointingAwayMinDot` | 0.2 | |
| Gesture | `thumbCocked` | t ≥ 0.45 | t normalized by hand scale |
| Gesture | `fireOnset` / `fireThreshold` | t < 0.40 / t ≤ 0.27 | |
| Gesture | `fireSnapWindow` | 0.25 s | onset → fire |
| Gesture | `fireCooldown` | 0.22 s | |
| Gesture | `aimLookback` | 0.045 s | before onset |
| Gesture | `aimAlpha` | 0.45 | per frame |
| Gesture | `aimBlend` finger / knuckle-wrist | 0.6 / 0.4 | |
| Gesture | `aimBuffer` | 24 samples | |
| Gesture | `assist` Normal / Easy · bigTargets | 3.5° / 5.0° · ×1.5 | |
| Gesture | `maxRange` | 8 m | |
| Gesture | `dwellFire` (Plan B) | 0.35 s | |
| Touch | `forgiveness` | +0.03 m radius | |
| Touch | `cooldown` | 0.15 s per hand | |
| Hints | `handsLostHint` | 3.0 s | |
| HUD | follow: distance / pitch | 1.1 m / −18° | |
| HUD | follow thresholds: yaw / position / settle | 25° / 0.4 m / 5°, 0.05 m | |
| HUD | follow time constant | 0.25 s | |
| Panels | lobby & results / countdown / tutorial | 1.2 m −8° / 1.6 m eye / 0.9 m −20° | |
| FX | spawnPop / hitFlash / shards / popup / expire | 0.15 / 0.04 / 0.35 (10 × 2 cm, 0.25 m) / 0.6 (rise 0.12 m) / 0.2 s | |
| FX | muzzle / tracer / reticleKick / reticleAngle | 0.06 / 0.07 / 0.12 s / 1.2° | |
| FX | beam | 2 mm × 0.6 m, opacity 0.35 | |
| Audio | spatial gain | −6 dB | all other audio/music values: `docs/sound-design.md` §1–§3 |

---

## 12. Risks & cut list

### 12.1 Risks
| Risk | Likelihood / impact | Mitigation | Trigger → action |
| --- | --- | --- | --- |
| Thumb occluded by index → missed/ghost fires | Med / High | Fixtures in M4a (Nov 9–14) before tuning; snap window; hand-scale normalization; Gesture Lab sliders | Gate fails Nov 19 → keep tuning to Nov 24; ship Plan B "Auto-trigger" toggle; Plan C Look & Pinch exists anyway |
| Aim jitter at 3 m | Med / High | Blend + smoothing + lookback + assist | Raise assist to 5°, Normal blaster diameter to 0.45 m |
| Free provisioning expires during demo week | High if free / High | Paid program, or reinstall Mon Nov 30 (valid to Dec 7) | Calendar reminder every Tue |
| Hand tracking poor in demo-room lighting | Med / High | Test in demo room Sat Nov 28; bright, even light | Switch demo to Touch + Stay Put |
| Merge conflicts in pbxproj | Med / Med | Synchronized folders; folder ownership; small PRs | — |
| Swift concurrency errors stall Sonnet | Med / Med | Swift 5 mode in app; explicit @MainActor | Don't fight warnings; annotate |
| API not in SDK (cylinder, extent, attachments) | Low / Low | Fallbacks listed inline | Use fallback, note in PR |
| Comfort: neck strain / walking hazards | Low / Med | Band limits, HUD −18°, Roam safety copy, mixed immersion | Default Stay Put for demo |
| Schedule slip (Gary overloaded M1+M4a+M3) | Med / High | Kevin takes PanelPlacer if M3 slips; everything after Nov 19 is cuttable | See cut list |
| Post-gate squeeze (M5/M6/M7a/M7b/M8 in Nov 20–26) | High / Med | Strict tiers; Must never trades scope for polish | Apply §12.2 from the top at each Tue/Thu sync |

### 12.2 Cut list (cut in this order, lowest tier first; never cut the Must list)
1. **Stretch** — attract mode and everything in §12.3 (never started unless all green Wed Nov 25).
2. **M8 Tutorial & demo** → fall back to a static How to Play card ("Poke targets. Finger-gun, drop thumb to shoot.") and the presenter explains. Decide Tue Nov 24.
3. **M6** surface placement entirely (Roam = air-spawn) — decide Tue Nov 24.
4. M7b nice-to-haves: arena open/close fades, lock-on cue + brackets pop, expire warning blink, combo-break visual.
5. Session best ("NEW BEST" + `new_high_score`) and the final-10 s intense music switch (round loop keeps playing).
6. Hard difficulty (keep Easy/Normal).
7. Moving targets (keep Normal/Small).
8. Roam Room mode (keep Stay Put; toggle hidden).
9. Results tally animation, combo chip pop, score popups.
10. Music entirely (SFX stay), then spatial emitters → plain UI sounds for everything.
**Never cut:** timed 30/60 loop, spawn, touch, scoring, lobby/HUD/results stats, single-shot finger-gun, 8-bit targets.

### 12.3 Stretch (only if all green Wed Nov 25; otherwise post-demo)
**Attract / demo mode** (§7, M8), persistent high score (`@AppStorage` best per length/controls), decoy targets, grade badge (S/A/B/C) + grade jingles, streak "coin ladder" hit pitches, hands-lost chime, scene-reconstruction safety, gun skin (reticle/beam color variants), voice fire. (Music moved to the Goal tier in M7a.)

---

## 13. Device test checklist (run every Thu sync and in full on Sat Nov 28)

**Install & permissions**
- [ ] Deploy from Xcode over Wi-Fi succeeds; app launches; profile not expired (note install date).
- [ ] First Enter Arena prompts for Hand Tracking and World Sensing; deny each once and verify fallbacks (§2.8).
- [ ] Launcher ↔ Arena round-trip 3× without relaunch.

**Flow**
- [ ] Lobby appears in front of me after entering, after results→Menu, and after turning 180° then returning to lobby.
- [ ] 30 s default; 60 s works; countdown beeps + numbers; GO starts timer.
- [ ] HUD readable, follows lazily on 90° turn, doesn't jitter when still, never blocks a target.
- [ ] Round ends exactly at 0; results numbers match a manual tally (count hits on paper for one round).
- [ ] Play Again / Menu / Exit Arena all correct. Digital Crown mid-round → clean state.

**Touch**
- [ ] Either fingertip hits; fast poke counts; resting hand near target doesn't.
- [ ] Touch targets always reachable without stepping (Stay Put).

**Finger-gun**
- [ ] Both hands arm; open hand/fist/pinch/hands in lap never arm.
- [ ] 20 deliberate shots per hand: ≥ 18 register.
- [ ] 60 s idle + 60 s talking with hands: 0 fires.
- [ ] Bullseye achievable on Normal at 3 m; aim doesn't drop on fire.
- [ ] Missed shots reduce accuracy; shots fired shown.

**Variety / space**
- [ ] Small, Moving appear per weights; Hard shows 2 at once.
- [ ] Roam spawns all around; spawn blip locatable; heights 0.6–2.0 m.
- [ ] (M6) Wall/table targets flush, none behind walls.

**Feel / comfort / a11y**
- [ ] Every sound plays from the right place; no hitch on hit.
- [ ] (M7a) Music: lobby → silent countdown → round → intense at 10 s → whistle → sting; Music toggle mutes it.
- [ ] (M7b) Combo chip, expire warning, results tally and NEW BEST each show up in a round.
- [ ] Reduce Motion and Big Targets work.
- [ ] (M8) Two first-timers finish the tutorial unaided.
- [ ] 3 consecutive rounds: no crash, no thermal warning, battery noted.

---

## 14. Ownership summary

| Milestone | Gary (AR / interaction) | Kevin (logic / UI) | Integration point |
| --- | --- | --- | --- |
| M0 | Signing, device, Arena scene, auth | Package, repo hygiene, README | Both build & run |
| M1 | Target, texture, FX, hand tracking, touch, look-pinch | Core types, `ArenaRendering`, `GameSession` stub + tests | `registerHit` from touch |
| M2 | Expire/roundEnded FX | Timer, spawns, scoring, stats, debug autoplay | `ArenaRendering` spawn/remove |
| M3 | Head pose, PanelPlacer, HUD follow, attachments host, lifecycle | All SwiftUI panels, settings, font | Attachment ids + phase visibility |
| M4a | Recorder, classifier, FSM, aim visuals, Gesture Lab | — | — |
| M4b | Fire, HitMath shots, FX, blaster band, tuning | Blaster toggle/default, shots stats, gate protocol | `registerHit` / `registerMissedShot` from blaster |
| M5 | Motion system, Roam placement | Weights, difficulty, lobby pickers | `SpawnRequest.motion`, `RoundConfig.space` |
| M6 | Planes, surface placement, plane debug | Denied-sensing copy | `PlacementService` fallback |
| M7a | AudioBank, emitter pool, hand/ray/lock-on cues | `SoundCue` + tests, MusicDirector, Music toggle, asset copy | `GameEvent` → `SoundCue` → audio/music |
| M7b | Popups, expire FX, brackets, arena fades, FX a11y | Combo chip, session best, tally, HUD final seconds, Big Targets, reduce-motion plumbing | `.comboChanged`, `newSessionBest` |
| M8 | Tutorial targets, pose hook, card placement | Tutorial flow + tests, card, How to Play | `tutorialPoseDetected()`, `.tutorialAdvanced` |
| M9 | Device tests, fresh install | README, demo script, debug cleanup | Tag `v1.0-demo` |

Rule of thumb: Kevin never edits `Arena/`, `Tracking/`, `Interaction/`, `Placement/`, `GestureCore/`; Gary never edits `UI/` or `GameCore/` except `Tuning.swift` gesture rows and the M1 stub — both via PR reviewed by the other.
