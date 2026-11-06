# PewPew — Sound Design

**Brief:** "Summer-fair archery booth, played on a NES." Each SFX has a chiptune core for identity (pulse/square, triangle and noise voices with envelopes) and a short synthesized foley layer for physicality (wood *thock*, cardboard tap, finger snap, woodblock, whistle). The music is upbeat chiptune that sits under the SFX and never covers them. All sounds were synthesized in code, so there are no samples and no licensing questions.

This builds on [visual-design-spec §6](visual-design-spec.md) (hybrid chip + foley, 48 kHz mono, 12-sound list, loudness targets) and [sonnet-build-plan](sonnet-build-plan.md) §5.5 (audio), §8.2 (`GameEvent`) and §11 (spatial gain −6 dB). The **Changes vs. spec** section below lists every place this doc departs from them, and why.

| What | Where ([`docs/audio/`](audio/)) |
| --- | --- |
| 28 SFX, mono, 48 kHz, 16-bit | [`sfx/*.wav`](audio/sfx/) |
| 5 music files, stereo, 48 kHz, 16-bit | [`music/*.wav`](audio/music/) |
| Listening montage, 68.7 s, 192 kbps | [`preview_all.mp3`](audio/preview_all.mp3) (SFX by group → spawn cue panned L/C/R → tally → lobby → round, crossfaded into intense at 10 s → `end` → results sting) |
| Generator (numpy + scipy, deterministic) | [`generate_audio.py`](audio/generate_audio.py) — `python3 generate_audio.py` regenerates everything in about 20 s |
| Measured facts per file | [`manifest.json`](audio/manifest.json) (duration, samples, peak, LUFS, loop-seam check) |

**Mastering.** SFX: high-pass at 150 Hz, 4th-order low-pass at 11 kHz, at most 1 ms of leading silence, normalized to a per-sound loudness target, peaks ≤ −1 dBFS. Transient-heavy files (`pew*`, `spawn*`, `hit*`, `miss`, `blaster_cock`, `ui_tap`) pass through a look-ahead peak limiter (1.5 ms look-ahead, 30 ms release) so they reach their targets under the ceiling. Every file lands within 0.7 dB of its target. Music: integrated loudness of −18 LUFS for the round loop and −19 for the lobby. All loops are rendered circularly: note tails, delays and filters wrap across the loop point, so each loop is an exact number of bars (sample-accurate) and passes the seam check. Loudness was cross-checked with pyloudnorm and agrees within 0.25 dB.

---

## 1. Sound list

Gains are app-side, layered on top of the file loudness. **Spatial** means the sound plays from a pooled emitter (or the hand entity) with `SpatialAudioComponent(gain: −6)`, as in the spec. **UI** means it plays from the HUD audio entity with `ChannelAudioComponent(gain: −6)`. "Trim" is `AudioPlaybackController.gain`, 0 dB unless noted. LUFS is the measured maximum momentary loudness.

| File | Len | LUFS | Trigger (`GameEvent` / UI) | Ch | Spatial | Trim dB | Voices / cooldown |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `sfx/ui_tap.wav` | 45 ms | −22 | Any primary/secondary button (Play, Play Again, segment pick) | mono | UI | 0 | 1, restart |
| `sfx/ui_back.wav` | 80 ms | −22 | Menu / Back / Cancel / Skip tutorial | mono | UI | 0 | 1 |
| `sfx/ui_toggle_on.wav` | 90 ms | −22 | Toggle → on (Big Targets, Music, Movement) | mono | UI | 0 | 1 |
| `sfx/ui_toggle_off.wav` | 90 ms | −23 | Toggle → off | mono | UI | 0 | 1 |
| `sfx/lock_on.wav` | 40 ms | −28 | Blaster reticle enters a target's assist cone *(new hook)* | mono | target | 0 | 1; 0.3 s per target |
| `sfx/blaster_cock.wav` | 78 ms | −23 | Hand enters ARMED_COCKED *(new hook)* | mono | hand (index tip) | −3 | 1 per hand; 0.4 s |
| `sfx/pew.wav` / `pew_b.wav` | 120 ms | −16 | Fire (InputCoordinator). Alternate a/b round-robin; left hand starts on `b` | mono | hand (index tip) | 0 | 2 per hand; steal oldest |
| `sfx/miss.wav` | 50 ms | −26 | `.missedShot`, at the ray end (or 4 m along the ray) | mono | ray end | 0 | 2; 60 ms |
| `sfx/spawn.wav` | 138 ms | −18 | `.targetSpawned` (Stay Put) | mono | target | 0 (+3 if no rolloff API) | 2 (Hard concurrency) |
| `sfx/spawn_roam.wav` | 280 ms | −16 | `.targetSpawned` in Roam, or any spawn > 60° off gaze | mono | target | 0 (+3 if no rolloff API) | 2 |
| `sfx/hit.wav` | 250 ms | −14 | `.targetHit`, `ring == .none` | mono | target position | 0 | 3; steal oldest |
| `sfx/hit_red.wav` | 250 ms | −14 | `.targetHit`, `ring == .red` | mono | target position | 0 | 3 (shared with hit) |
| `sfx/bullseye.wav` | 400 ms | −12 | `.targetHit`, `ring == .gold` (ducks music) | mono | target position | 0 | 2 |
| `sfx/expire.wav` | 190 ms | −20 | `.targetExpired` | mono | target position | 0 | 2 |
| `sfx/count.wav` | 148 ms | −16 | `.countdownTick(3/2/1)` | mono | UI | 0 | 1 |
| `sfx/go.wav` | 300 ms | −14 | `.go` (round music starts the same frame) | mono | UI | 0 | 1 |
| `sfx/tick.wav` | 50 ms | −22 | `.finalSecondsTick(n)` for n ≤ 5 | mono | UI | 0 | 1; drop if playing |
| `sfx/end.wav` | 710 ms | −14 | `.roundEnded` — whistle + falling G–E–C triad (ducks, then stops music) | mono | UI | 0 | 1 |
| `sfx/time_up_buzzer.wav` | 595 ms | −17 | *Alternative* to `end` (classic arcade buzzer). Not used by default: harsher for kids | mono | UI | 0 | 1 |
| `music/music_results_sting.wav` | 2.9 s | −16 int. | Results panel appears (`.roundEnded` + 0.6 s) | stereo | UI (music entity) | −6 | 1 |
| `sfx/tally.wav` | 40 ms | −26 | Each results count-up step (skipped under Reduce Motion) | mono | UI | 0 | 1; drop if playing (≈ 12/s max) |
| `sfx/new_high_score.wav` | 1.25 s | −14 | Score beats the session best *(new hook)*, 1.0 s after the sting starts (ducks the sting) | mono | UI | 0 | 1 |
| `sfx/combo.wav` | 195 ms | −16 | `.comboChanged(1.5)` | mono | UI | 0 | 1 |
| `sfx/combo_x2.wav` | 195 ms | −16 | `.comboChanged(2.0)` (ducks music) | mono | UI | 0 | 1 |
| `sfx/combo_break.wav` | 180 ms | −24 | `.comboChanged(1.0)` from ≥ 1.5. **Off by default** (feels punishing for kids) | mono | UI | 0 | 1 |
| `sfx/tutorial_success.wav` | 450 ms | −16 | `.tutorialAdvanced(_)` (each step done) | mono | UI | 0 | 1 |
| `sfx/arena_open.wav` | 890 ms | −20 | Immersive space opened (after preload) | mono | UI | 0 | 1 |
| `sfx/arena_close.wav` | 639 ms | −21 | Exit Arena tapped (play, then dismiss after 0.3 s) | mono | UI | 0 | 1 |

**Global cap:** at most 6 simultaneous SFX (spec). When the cap is full, steal the oldest voice with the lowest priority. Priority order: `end` > `go`/`count` > `bullseye` > `hit`/`hit_red` > `spawn*` > `expire` > `pew*` > `combo*` > `miss` > `tick` > `tally` > `lock_on` > UI. Music doesn't count toward the cap.

**Spawn vs. hit:** never in the same frame at the same spot. The plan's ≥ 0.25 s respawn delay already guarantees this.

## 2. Music

| File | Length | Tempo / key | Role |
| --- | --- | --- | --- |
| `music/music_lobby_loop.wav` | 38.40 s (16 bars) | 100 BPM, C major 7ths | Lobby, tutorial, results → menu. Soft 50 % pulse arp with ping-pong delay, triangle pad and bass, shaker; woodblock and triangle melody in bars 9–16. |
| `music/music_round_loop.wav` | 25.60 s (16 bars) | 150 BPM, C major (I–V–vi–IV, B section IV–V–iii–vi) | Round bed. 25 % / 50 % pulse lead with dotted-eighth delay, 12.5 % arp, stair-step triangle bass with a pulse octave for small speakers, chip kit. The A/B form and a snare fill into the loop point keep it from droning across 60 s. |
| `music/music_round_final10_layer.wav` | 25.60 s | same grid | **Additive** layer: four-on-the-floor kick, 16th hats, off-beat open hats, high counter-arp. Bed + layer at unity = intense. |
| `music/music_round_intense_loop.wav` | 25.60 s | same grid | Bed + layer pre-mixed (−17.4 LUFS). Use for the simple crossfade path. |
| `music/music_results_sting.wav` | 2.90 s | 150 BPM | Triplet pickup → G–E–G → held C6 with harmony, arp sparkle, crash. Not a loop. |

**Why it isn't fatiguing:** the lead sits in E5–F6 behind a 5.5 kHz low-pass. Hats are 14–21 dB under the bed. The melody rests every 4 bars. The music is 6–8 dB under the SFX in game. The countdown is music-free, which gives a natural reset each round.

### Behavior (state machine)

| Moment | Music action |
| --- | --- |
| Arena opens (preload done) | `arena_open`, then lobby loop fades in from silence to −6 dB over **1.5 s** |
| Tutorial running | Lobby loop ducked to −14 dB (fade 0.5 s), restored to −6 dB when done |
| Play pressed (lobby → countdown) | Lobby fades out over **0.8 s** and stops. Countdown plays dry |
| `.go` | Start `music_round_loop` (gain −8 dB) **and** `music_round_intense_loop` (gain −80 dB) in the same frame. No fade-in: the downbeat lands with GO |
| 10 s left (`.finalSecondsTick(10)`) | Crossfade bed → intense over **0.4 s** (one beat): bed to −80, intense to −8. In a 30 s round the bed has looped once; in a 60 s round, twice |
| `.roundEnded` | `end` plays; both round controllers fade out over **0.15 s** and stop |
| Results +0.6 s | `music_results_sting` at −6 dB; `new_high_score` at +1.0 s if earned |
| Play Again | Countdown directly (no lobby music) |
| Menu | Lobby loop fades in over **1.5 s** |
| Exit Arena | `arena_close`; any music fades out over **0.5 s** |

**Ducking** (bullseye, combo ×2, end, new high score): fade the current music controller(s) by **−4 dB** over 0.03 s and restore over 0.30 s. Debounce: if a duck is active, extend it rather than stacking. Routine hits do not duck; the 6 dB gap covers them.

**Layer vs. crossfade:** two RealityKit controllers started in the same frame stay on the same timeline, so a short crossfade to the pre-mixed intense loop is coherent. Summing the separate `final10_layer` on top would expose any ≤ 1-frame start skew as kick flams, so the layer file is there for an `AVAudioEngine` path (two `AVAudioPlayerNode`s scheduled at one `AVAudioTime`). Ship the crossfade path for the demo.

Loops must stay WAV. MP3/AAC encoder padding breaks gapless looping.

## 3. Spatial audio setup (RealityKit, visionOS)

| Component | Used for | Why |
| --- | --- | --- |
| `SpatialAudioComponent(gain: −6, directivity: .beam(focus: 0), distanceAttenuation: .rolloff(factor: 0.6))` | Everything that happens *at a place*: target spawn/hit/expire/lock-on, pew/cock (hand), miss (ray end) | HRTF-rendered, so the player hears where it happened. `focus: 0` = omni. Rolloff 0.6 keeps 5 m Roam spawns audible (*flag: verify these initializer labels in the SDK; if `distanceAttenuation` is missing, use the default and add +3 dB trim on `spawn*`*). Keep the default reverb level; room reverb helps externalization. |
| `ChannelAudioComponent(gain: −6)` on a `hudAudio` entity under the HUD | UI clicks, countdown, ticks, combo, end, tally, tutorial, arena open/close, new high score | Head-relative, unspatialized. Feedback about *your* state shouldn't come from a direction. |
| `ChannelAudioComponent(gain: −8)` on a `musicAudio` entity under the arena root | All music | Plain stereo, unaffected by head pose. |
| `AmbientAudioComponent` | **Not used** | It renders a world-anchored, direction-preserving bed (the stereo image would rotate as you turn). That is wrong for music and UI. Reserve it for a future fair-ambience bed. |

**Entities:**
- `AudioEmitterPool`: 6 plain `Entity`s under the arena root, each with the spatial component above. To play at a point, move a free (or stolen) emitter there, then call `playAudio`. **Never play hit/expire from the target entity itself.** Removing an entity stops its audio, and targets are removed on hit and expire.
- `pew` and `blaster_cock` play from an entity parented to the index-tip anchor of the firing hand (so they follow the hand).
- `miss` plays from a pooled emitter at the ray hit point, or at 4 m along the ray if nothing was hit.
- `spawn`/`spawn_roam` play from a pooled emitter at the target's spawn position, in the frame it appears. Moving targets drift < 5 cm during the 138 ms cue, which is negligible.

**Loading:** preload everything (`loadingStrategy: .preload`) when the Arena opens, before `arena_open` plays. Use `shouldLoop: true` for the three round/lobby loops. Total memory is about 23 MB of PCM (music is 22.7 MB of it), which is fine. Use `try await AudioFileResource(named: "spawn.wav", configuration:)` on visionOS 2; `AudioFileResource.load(named:)` also works.

## 4. How the directional respawn cue works

`spawn.wav` is designed for localization, not just signaling:

1. **Broadband bright onset.** Each chirp starts with a 25–30 ms burst of 2–6 kHz band-passed noise. The ear's pinna and head-shadow cues (level differences between the ears, elevation, front/back) live in about 2–8 kHz. Pure chip tones are mostly harmonics of one note, so they localize poorly; the noise onset fixes that.
2. **Low-mid fundamental.** The chirp sweeps 600 → 1400 Hz. Below about 1.5 kHz the brain uses interaural *time* differences, so you get both cue families.
3. **Two onsets, 68 ms apart.** Localization locks onto onsets (the precedence effect). Two onsets give two samples of direction without making the sound long. The second chirp is higher, so it reads as "up/new", the opposite of `expire`'s falling fwip.
4. **Short (138 ms) and identical every time**, so it is quickly learnable and never masks a hit. It is quieter (−18) than hits (−14), so hits stay the reward.
5. **`spawn_roam.wav` (280 ms, three onsets, +2 dB)** for Roam mode or any spawn more than 60° from gaze. It lasts long enough for a head turn to start while it plays, which resolves front/back confusion (static HRTF can't). It always pairs with the visual edge chevron ([`visual/sprites/chevron.png`](visual/sprites/chevron.png)), because some players can't hear direction (single-sided hearing, one AirPod-style use, noisy rooms).

Test on device by spawning targets at ±90° and 180° with your eyes closed. The pass bar is pointing within about 30° after 3 tries.

## 5. Accessibility & comfort

- **Music toggle**: "Music" `Toggle` in the lobby (on by default), stored in `AppModel.musicEnabled` (`@AppStorage("musicEnabled")`, a single bool and not a stats store). Off means the music entity never plays; SFX are unaffected. Toggle sounds give immediate feedback.
- **Volume:** follows the system volume. Nothing exceeds −1 dBFS. Music sits 6–8 dB under SFX in game.
- **No harsh highs:** every SFX is low-passed at 11 kHz (4th order). The whistle sits at about 2.2 kHz, not the 3–4 kHz of a real pea whistle. The final-seconds tick is a woodblock rather than a beep. No tone sustains longer than 1.3 s. The default end cue is the whistle, with the buzzer optional.
- **Kid-friendly:** misses are a quiet dry tick (−26). `combo_break` is off by default. No sound is designed to startle, and nothing is louder than `bullseye`.
- **Every audio cue has a visual twin** (deaf / hard-of-hearing / muted device): spawn → pop-in + chevron, hit → shards + popup, final seconds → gold pulsing timer, combo → badge.
- Reduce Motion doesn't change audio, except that `tally` is skipped because the count-up is skipped.

## 6. More ideas (ranked by value ÷ cost)

| # | Idea | Status |
| --- | --- | --- |
| 1 | Spatial respawn cue + long Roam variant (`spawn`, `spawn_roam`) | **Produced** |
| 2 | Blaster fire round-robin (`pew`, `pew_b`), against repetition fatigue across about 60 shots | **Produced** |
| 3 | Blaster cock / armed click (`blaster_cock`), audible confirmation of the pose | **Produced** |
| 4 | Combo milestones ×1.5 / ×2 (`combo`, `combo_x2`) | **Produced** |
| 5 | Final-10 s music intensity (`final10_layer`, `intense_loop`) + last-5 s ticks (`tick`) | **Produced** |
| 6 | Results sting + new session best (`music_results_sting`, `new_high_score`) | **Produced** |
| 7 | Tutorial step success (`tutorial_success`) | **Produced** |
| 8 | Arena open / close (`arena_open`, `arena_close`) | **Produced** |
| 9 | Hover / lock-on tick (`lock_on`), only in Blaster mode | **Produced** |
| 10 | Classic buzzer alternative (`time_up_buzzer`) and gentle combo break (`combo_break`) | **Produced** (both off by default) |
| 11 | Streak "coin ladder": hit ding pitched up a semitone per streak step (bake 5 files) | Idea: cheap, needs a playtest to see whether it overloads |
| 12 | Moving-target spatial whir loop (very quiet), so strafing targets are trackable by ear | Idea: medium; needs a loop per entity, which counts against the voice cap |
| 13 | Hands-lost / tracking-lost soft chime alongside the hint text | Idea: cheap |
| 14 | Results grade jingles (S/A/B) instead of one sting | Idea: medium, needs grade rules |
| 15 | Summer-fair ambience bed (crowd murmur, distant calliope) via `AmbientAudioComponent` | Idea: needs recorded foley or a lot of synthesis; post-demo |
| 16 | Announcer voice ("Bullseye!", "Go!") | Idea: needs VO/TTS and licensing; post-demo |

## 7. Changes vs. spec (and why)

1. **Music added.** Spec §6 says "No music bed" and plan M7 says "Do NOT add music". The user asked for music. To protect the arcade clarity the spec wanted, it sits 6–8 dB under SFX, stays silent during the countdown, and can be muted.
2. **Loudness unit:** spec targets are kept, but measured as **maximum momentary loudness (400 ms)** instead of short-term (3 s). A 3 s window on a 50–400 ms sound mostly measures silence.
3. **Baked pitch variants:** `hit_red` (+3 semitones, as spec'd) and `combo_x2` (+5) are files rather than pitched in code. RealityKit playback has no simple pitch control.
4. **`spawn`** uses two onsets (138 ms) instead of one 150 ms blip, plus the new `spawn_roam`, for localization (§4).
5. **`end`** uses a synthesized whistle instead of a recorded one (no licensing). The buzzer is an alternative.
6. **`.finalSecondsTick(n)`** should be emitted for n = 10…1 (plan: last 5). AudioBank plays `tick` only when n ≤ 5 and switches the music at 10. The HUD's gold pulse still starts at 5.
7. **New hooks** (not in `GameEvent`; fired from InputCoordinator/AppModel): `armed(hand)`, `fired(hand)` (already exists as the pew trigger), `lockOn(TargetID)`, `newSessionBest`.
8. **Hit/expire sounds play from pooled emitters**, not the target entity (§3). This avoids audio being cut when the entity is removed.

## 8. Paste-ready Sonnet prompt (M7 audio)

```text
[paste shared preamble first]

Milestone M7-audio — wire the finished audio into PewPew. Read docs/sound-design.md (all) and plan §5.5,
§8.2. This supersedes M7 item 1 and its "Do NOT add music" line: music is now in scope.

Assets (already made; do not generate or rename):
- Copy docs/audio/sfx/*.wav     -> pew/PewPew/Resources/Audio/SFX/
- Copy docs/audio/music/*.wav   -> pew/PewPew/Resources/Audio/Music/
  (synchronized folder: files land flat in the bundle; names are unique; load with the ".wav" extension)

1. GameCore/SoundCue.swift (pure, no RealityKit): enum SoundCue: String { uiTap="ui_tap", uiBack="ui_back",
   uiToggleOn="ui_toggle_on", uiToggleOff="ui_toggle_off", lockOn="lock_on", blasterCock="blaster_cock",
   pew, pewB="pew_b", miss, spawn, spawnRoam="spawn_roam", hit, hitRed="hit_red", bullseye, expire, count, go,
   tick, tally, end, timeUpBuzzer="time_up_buzzer", combo, comboX2="combo_x2", comboBreak="combo_break",
   newHighScore="new_high_score", tutorialSuccess="tutorial_success", arenaOpen="arena_open",
   arenaClose="arena_close" } plus `static func cues(for: GameEvent, space: SpaceMode) -> [SoundCue]`:
   countdownTick→count, go→go, finalSecondsTick(n)→tick if n ≤ 5, roundEnded→end, targetSpawned→spawn
   (spawnRoam when space == .roam), targetHit(o,_)→ o.ring .gold→bullseye, .red→hitRed, else hit,
   targetExpired→expire, missedShot→miss, comboChanged(1.5)→combo, (2.0)→comboX2, (1.0)→[] (comboBreak
   only if a flag is on; default off), tutorialAdvanced→tutorialSuccess. Add priority (sound-design §1
   order) and per-cue voice limit/cooldown as static tables. Unit tests for the mapping.
   GameSession: emit .finalSecondsTick for n = 10...1 (was 5...1); the HUD still pulses only at ≤ 5.
2. Arena/AudioBank.swift (@MainActor): `func preload() async` loads every SoundCue + the 5 music files
   (AudioFileResource(named:configuration:) with .preload; shouldLoop true for music_lobby_loop,
   music_round_loop, music_round_intense_loop). Call it when the ImmersiveSpace opens, before playing
   arena_open; until it finishes, play() is a no-op. Missing file → log once, stay silent.
   - Emitter pool: 6 Entities under the arena root with SpatialAudioComponent(gain: -6,
     directivity: .beam(focus: 0), distanceAttenuation: .rolloff(factor: 0.6)). If that initializer
     doesn't compile, use SpatialAudioComponent(gain: -6) and add +3 dB controller gain on spawn/spawnRoam;
     say which you used in the PR. play(_ cue, at worldPosition) moves a free emitter (else steals the
     oldest lowest-priority voice) and calls playAudio. NEVER play from the target entity (removal cuts audio).
   - playAtHand(_ cue, hand): from an entity parented to that hand's index-tip anchor (same spatial component).
     pew alternates pew/pewB per hand (left hand starts on pewB).
   - playUI(_ cue): from a `hudAudio` entity under the HUD with ChannelAudioComponent(gain: -6).
   - Enforce: ≤ 6 concurrent SFX total, the per-cue limits/cooldowns, and tick/tally "drop if still playing".
3. Arena/MusicDirector.swift (@MainActor): a `musicAudio` entity with ChannelAudioComponent(gain: -8)
   under the arena root. Implement the table in sound-design §2: lobby fade-in 1.5 s at -6 dB; fade out
   0.8 s on Play; at .go start round (−8 dB) and intense (−80 dB) in the same call; at
   .finalSecondsTick(10) crossfade 0.4 s (round→−80, intense→−8); .roundEnded fade both out 0.15 s and
   stop; results sting at roundEnded + 0.6 s (−6 dB); Menu → lobby fade-in 1.5 s; tutorial ducks lobby to
   −14 dB; Exit fades all 0.5 s. duck(): −4 dB in 0.03 s, restore in 0.30 s, extend if already ducked —
   called for bullseye, comboX2, end, newHighScore. Use AudioPlaybackController.fade(to:duration:) (if it
   doesn't exist, ramp .gain from a small System/Timer over the same durations). Respects
   AppModel.musicEnabled (stop with a 0.3 s fade when turned off, resume the right track when turned on).
4. Wiring: GameSession.onEvent → SoundCue.cues → AudioBank (spatial cues at the target's position, read
   before removal) and MusicDirector. InputCoordinator: fire → playAtHand(pew), ARMED_COCKED entry →
   playAtHand(blasterCock) (0.4 s cooldown), missed shot → play(miss, at: ray hit or origin + 4 m·dir),
   reticle entering a target's assist cone → play(lockOn, at: target) (0.3 s per target, Blaster only).
   UI: Button taps → uiTap, Menu/Back/Skip → uiBack, toggles → uiToggleOn/Off. Results: tally per
   count-up step (skip under reduce motion); AppModel keeps an in-memory sessionBest and plays
   newHighScore 1.0 s after the sting when beaten. Exit Arena: play arenaClose, dismiss after 0.3 s.
5. LobbyPanel: add a "Music" Toggle bound to AppModel.musicEnabled (@AppStorage("musicEnabled"), default true).

Do NOT: change, resample or re-encode the WAVs (no MP3/AAC — breaks gapless loops); load audio inside the
update loop; play spatial sounds from entities that are about to be removed; add new sounds.
Done when: on device every cue plays from the right place, the spawn cue behind you is locatable with
eyes closed, music goes lobby → (silent countdown) → round → intense at 10 s → whistle → sting → lobby
without gaps or clicks at the loop point, Music toggle works, no hitch on first hit (all preloaded).
```
