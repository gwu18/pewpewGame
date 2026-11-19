# Experimental 3D Virtual Gun Mode — Design Notes

**Status:** exploratory / experimental. Captures current intent so Gary can decide whether to build it. **Not a build commitment.** Do not treat this as a milestone rewrite of `docs/sonnet-build-plan.md`.

**Changelog:** Thu Nov 19, 2026 — locked holster default (float in air in front at round start) and put-down (open hand drops); updated Open questions.

| | |
| --- | --- |
| Mode | Separate from finger-gun for now; off by default |
| Demo | Dec demo does **not** require this mode |
| Owner | One owner for the whole experiment (for now) |
| Related | Finger-gun remains the main blaster path until (if) this wins |

---

## Goals

- Let the player pick up a **3D toy gun**, aim from its **barrel**, and fire with the same **index-bend trigger** used by finger-gun.
- Support **independent dual-wield** (left and right guns, each its own hold/aim/fire).
- Keep the experiment **opt-in** from the lobby, sharing existing Size / Distance / Stay-Put (Space) settings.
- Stay inside the existing **8-bit / summer-fair arcade** look (`docs/visual-design-spec.md`, `docs/sound-design.md`).

## Non-goals (v1)

- No recoil.
- Does **not** replace finger-gun yet (can replace later only if it proves better).
- Not blocking the Dec demo — either mode shipping is fine.
- No random drop / holster polish beyond “stays close to the hand.”
- Clipping with hands / body / world is **OK**.
- Gun mesh color / detailed skinning does not matter for the experiment.

---

## Player loop

1. **Lobby** — before the round, turn on an experimental **Virtual Gun** toggle (default **off**). Same Distance / Space (Stay Put vs Roam) / Size settings as finger-gun / blaster rounds.
2. **Spawn** — at round start, both guns float in the air **in front of the player** (not a chest holster). Player must pick them up to shoot.
3. **Grab** — make a **fist** near a gun to pick it up (**fist = grab only**). While held, the hand pose matches the current finger-gun trigger setup: **grip held, index straight or slightly curled** (index is trigger only).
4. **Aim** — the **3D gun is the aiming tool**. Ray originates at the **barrel**; the mesh is **fixed to the hand** when picked up (snap/smooth at implementer discretion so it doesn’t jitter or drop randomly).
5. **Fire** — **index finger bend while holding grip**, matching today’s finger-gun trigger thresholds and single-shot re-arm.
6. **Put down** — **open the hand** to drop the gun (not a second fist). While Virtual Gun mode is selected, put-down = **unarmed** — **no finger-gun fallback**.
7. Round uses the same spawn Distance / Space / Size path as a normal blaster round.

### Decided (Gary)

| Topic | Decision |
| --- | --- |
| Holster / spawn | Floating in the air in front of the player at round start (not chest) |
| Put-down | Opening the hand drops the gun (not a second fist); fist is grab only |

---

## Dual-wield & tracers

- **Must:** each hand can hold and fire its own gun independently.
- **Tracers:** left = **red**, right = **blue** (hand identity, not mesh paint).
- Gun mesh color is TBD / unimportant; keep the voxel / pixel toy language from the visual spec.
- Existing finger-gun beam/reticle language can stay mint until this mode defines its own aim feedback; tracers for this mode are the L/R color rule above.

---

## Tracking loss

- If a hand loses tracking while holding a gun: **freeze that gun in place** (do not despawn, do not teleport to holster, do not fall back to finger-gun).
- When tracking returns, resume follow/snap of that same gun to that hand (details left to implementer; prefer continuity over re-grab).

Contrast with current finger-gun: `FingerGunStateMachine` keeps armed state for `trackingGrace` (~0.75 s) then goes `.untracked` and clears aim. Virtual gun should **leave the world object frozen** instead of clearing the weapon.

---

## Visual / audio

- Follow `docs/visual-design-spec.md` (native shell, arcade soul; no glow/bloom/purple neon) and `docs/sound-design.md` (hybrid chip + foley).
- Gun mesh: TBD low-poly / chunky toy blaster in that aesthetic.
- Open whether to reuse muzzle flash sprite + `pew` / `pew_b` SFX (see Open questions). Hit / miss / cock cues can reuse the existing bank unless playtests say otherwise.
- Tracer thickness/duration can start from visual-spec FX (`tracerThickness` / `tracerDuration`) with L/R colors instead of mint.

---

## Relationship to current finger-gun code

Reuse the **trigger metric and fire edges**; replace **aim origin/direction** and **arming/grip** with virtual-gun hold state.

| Concern | Today (finger-gun) | Virtual gun |
| --- | --- | --- |
| Grip / arm | Thumb raised + curled non-index fingers (`FingerGunClassifier.isGunPose`) | Fist = grab; open hand = drop; while held, grip like finger-gun trigger setup (index free) |
| Trigger | Index straightness curl: pull ≤ `triggerPull` (0.75), release ≥ `triggerOnset` (0.85) | **Same** index-bend while holding the mesh |
| Aim | Wrist origin; forearm → wrist (else palm) direction — **index is not the ray** | **Barrel** of the attached gun mesh; gun fixed to hand |
| Fire edge | `armedReady` → `armedPulled` in `FingerGunStateMachine`; `InputCoordinator.fire` | Same edge semantics; ray from barrel |
| Per-hand FSM | `InputCoordinator` keeps `[Chirality: FingerGunStateMachine]` | Parallel per-hand hold + gun entity; dual-wield required |
| Tracking loss | Grace then `.untracked` | Freeze that gun in world |

**Key files / types (as of this writing):**

- `pew/Packages/PewPewCore/Sources/GestureCore/FingerGunClassifier.swift` — `GunMetrics.indexStraightness` is the trigger; comments state aim must not use the index bone.
- `pew/Packages/PewPewCore/Sources/GestureCore/FingerGunStateMachine.swift` — `GunState` (`armedReady` / `armedPulled`), hold-aim while pulled, tracking grace.
- `pew/Packages/PewPewCore/Sources/GameCore/Tuning.swift` — `Tuning.Gesture` (`triggerPull`, `triggerOnset`, `thumbUp`, `aimAlpha`, `fireCooldown`, …).
- `pew/PewPew/Interaction/InputCoordinator.swift` — per-hand update, cock on arm, fire on ready→pulled, `HitMath.aimHit`, `InputSource.blaster`.
- `pew/PewPew/Arena/AimVisuals.swift` — per-`Chirality` beam/reticle (mint today).
- Lobby / settings: `pew/PewPew/UI/LobbyPanel.swift`, `pew/PewPew/App/PlayerSettings.swift`, `RoundConfig` / `Controls` / `SpaceMode` / `TargetDistance` in `Types.swift`.

**Code fact that should shape the design:** the live finger-gun already treats the **index as trigger-only** and aims from the **wrist / forearm**, not the fingertip. Virtual gun continues that split (finger = trigger, object = barrel) and makes the barrel explicit as a mesh.

---

## Settings

| Setting | Behavior |
| --- | --- |
| Virtual Gun | Lobby-only toggle, **off by default**, experimental |
| Distance | Shared with finger-gun / blaster (`TargetDistance` Near / Mid / Far) |
| Space | Shared Stay Put / Roam (`SpaceMode`) |
| Size | Shared with whatever Size / big-target controls finger-gun uses (lobby / `RoundConfig`) |
| During round | Toggle disabled (same rule as other lobby config) |

Suggested shape: a new experimental flag (e.g. on `RoundConfig` or `PlayerSettings`) rather than overloading `Controls.blaster` until the experiment graduates. When the flag is on, finger-gun arming for that round is off (put-down = unarmed, no fallback).

---

## Open questions

1. **Muzzle flash / pew SFX:** reuse current `muzzle_star` + `pew`/`pew_b`, or distinct cues for the mesh gun?
2. (Implementer detail, not blocking design) snap distance / smoothing / attach offset while held; where the dropped gun rests (float in place vs return to front spawn).

---

## Suggested next step (if Gary greenlights)

High level only — **do not** edit `docs/sonnet-build-plan.md` unless asked:

1. Add lobby experimental toggle + persisted setting (default off).
2. At round start, spawn two RealityKit gun entities floating in front of the player; attach-follow on fist grab, drop on open hand, freeze-on-tracking-loss.
3. Index straightness reuse from `GunMetrics` / shared thresholds → fire via barrel ray into existing `HitMath` / session hit path.
4. L/R tracers (red/blue); leave mesh art placeholder.
5. Device playtest vs finger-gun; only then decide whether to promote or drop.
