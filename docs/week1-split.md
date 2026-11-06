# Week 1 split — PewPew

**Scope this week:** Setup + Layer 1 only (not Layer 2+).  
**Stack:** Swift + RealityKit + SwiftUI + ARKit on **visionOS** (Xcode).  
**Build order:** touch target first; finger-gun comes later (must ship by Dec week 1).  
**Cadence:** meet **Tue** (integrate / pick next items) and **Thu** (device/sim test / blockers).

**Gesture weapons later?** Yes — different hand poses could select weapon types later. Out of scope until **single-shot finger-gun / handgun** works. Do not plan it this week.

Integration handoff: AR hit → `GameManager.TargetHit()` (or one agreed Swift equivalent).

**Before device deploy:** Vision Pro is university-owned; Apple Developer access is **most likely via the university program**. Confirm uni team provisioning / device trust with lab or IT; verify signing works on the headset. **Simulator** can cover early UI/logic meanwhile.

---

## Gary Wu — AR / RealityKit / hands / effects

- [ ] Agree Xcode / visionOS SDK versions with Kevin; install locally
- [ ] Stand up visionOS Immersive Space / RealityKit scene in **genesis**
- [ ] Confirm hand tracking / Spatial Tap (or equivalent) path in sim / docs
- [ ] First run: blank cube in immersive space (**simulator** OK; device after uni signing check)
- [ ] Spawn one **8-bit archery target** in front of the player
- [ ] Fingertip / hand touch detection on target
- [ ] Despawn or hide on hit; call Kevin’s `GameManager.TargetHit()` stub
- [ ] Arcade hit feedback stub (flash / pop / juice)
- [ ] Verify touch → feedback on **simulator**; re-verify on **device** after uni signing check

---

## Kevin Young — game logic / SwiftUI / tracking

- [ ] Agree versions + repo with Gary; keep **genesis**; Swift `.gitignore`
- [ ] Both can push; document clone / open-in-Xcode steps briefly
- [ ] Agree folder/module naming + Game Logic vs AR file ownership (both Swift)
- [ ] Add minimal stubs: `GameManager.TargetHit()`, target identity if needed
- [ ] Track Week 1 checklist; note uni signing / device-trust status
- [ ] Placeholder target mesh / material notes for 8-bit look (Gary places it)
- [ ] Light SwiftUI stub only if it unblocks Layer 1 (no timed round yet)
- [ ] Join Tue/Thu integrates; keep milestone status current

---

## Parallel + integration

| Parallel | Gary | Kevin |
| --- | --- | --- |
| Early week | Xcode project + first sim run | Repo + naming + stubs |
| Mid week | Target spawn + touch | Wire stub API; track progress |
| Integrate (Tue/Thu) | Hit events fire (sim/device) | Confirm `TargetHit()` receives them |

**Integration point:** Gary’s touch path invokes Kevin’s `GameManager.TargetHit()` — no timed loop, scoring UI, or finger-gun this week.

---

## Done when (Week 1)

- [ ] Both can open the shared Xcode / visionOS project and push
- [ ] App runs in **visionOS simulator** (and on uni Vision Pro after signing check)
- [ ] See one 8-bit target → touch → disappears with feedback
- [ ] Hit reaches `GameManager.TargetHit()` (even if the method only logs)
- [ ] Ownership / naming agreed; checklist updated for next week (Layer 2)
- [ ] Uni signing / device trust confirmed (or still pending with lab/IT)
