#!/usr/bin/env python3
"""PewPew audio generator: every SFX and music loop, synthesized from scratch (no samples, no licenses).

    pip install numpy scipy          # ffmpeg on PATH is optional (MP3 preview)
    python3 generate_audio.py        # writes sfx/, music/, preview_all.mp3, manifest.json next to this file
    python3 generate_audio.py --out /tmp/pew_audio --no-preview

Output: 48 kHz 16-bit WAV. SFX are mono (for RealityKit spatial audio), music is stereo.
SFX: high-passed at 150 Hz, normalized to a per-sound loudness target (max momentary LUFS, 400 ms
window), peak ceiling -1 dBFS. Music: integrated LUFS target, loops are rendered circularly so they
are sample-accurate seamless (note tails, delays and filters wrap around the loop point).
Everything is deterministic (fixed RNG seed). Tweak the TUNABLES / sound functions and re-run.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
RNG = np.random.default_rng(7)

# ----------------------------------------------------------------------------- TUNABLES
SFX_HPF_HZ = 150          # headset speakers can't reproduce sub-bass
SFX_LPF_HZ = 11000        # comfort: no harsh air band
PEAK_CEIL_DBFS = -1.0
MUSIC_PEAK_CEIL_DBFS = -1.0
ROUND_BPM = 150           # 48000*60/150 = 19200 samples per beat (integer -> exact loop length)
LOBBY_BPM = 100           # 28800 samples per beat
FINAL10_LAYER_DB = 6.0    # level of the final-10 s layer relative to the round bed (intense = bed + layer)
MUSIC_LUFS = {"music_lobby_loop": -19.0, "music_round_loop": -18.0, "music_results_sting": -16.0}

# file -> target loudness (max momentary LUFS). Values follow visual-design-spec §6 where listed.
SFX_LUFS = {
    "ui_tap": -22, "ui_back": -22, "ui_toggle_on": -22, "ui_toggle_off": -23, "lock_on": -28,
    "blaster_cock": -22, "pew": -16, "pew_b": -16, "miss": -26,
    "spawn": -18, "spawn_roam": -16, "hit": -14, "hit_red": -14, "bullseye": -12, "expire": -20,
    "count": -16, "go": -14, "tick": -22, "tally": -26, "end": -14, "time_up_buzzer": -17,
    "combo": -16, "combo_x2": -16, "combo_break": -24, "new_high_score": -14,
    "tutorial_success": -16, "arena_open": -20, "arena_close": -21,
}


# ----------------------------------------------------------------------------- basics
def db(x):
    return 10 ** (x / 20)


def n_of(dur):
    return int(round(dur * SR))


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


_NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name):
    """'C#5' -> MIDI number."""
    n, i = _NOTE[name[0]], 1
    if name[1] in "#b":
        n += 1 if name[1] == "#" else -1
        i = 2
    return 12 * (int(name[i:]) + 1) + n


def hz(name):
    return midi_hz(note(name))


def _freq(freq, n):
    f = np.asarray(freq, dtype=float)
    return np.full(n, float(f)) if f.ndim == 0 else f[:n]


def _phase(freq, n):
    f = _freq(freq, n)
    ph = (np.concatenate([[0.0], np.cumsum(f[:-1])]) / SR) % 1.0
    return ph, f / SR


def _blep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = 2 * x - x * x - 1
    m = t > 1 - dt
    x = (t[m] - 1) / dt[m]
    y[m] = x * x + 2 * x + 1
    return y


def pulse(freq, dur, duty=0.5):
    """Band-limited (PolyBLEP) pulse; duty 0.125 / 0.25 / 0.5 are the classic NES widths."""
    n = n_of(dur)
    ph, dt = _phase(freq, n)
    y = np.where(ph < duty, 1.0, -1.0)
    y += _blep(ph, dt)
    y -= _blep((ph - duty) % 1.0, dt)
    return y - (2 * duty - 1)


def tri(freq, dur, steps=None):
    """Triangle; steps=16 gives the 4-bit stair-step NES flavour."""
    ph, _ = _phase(freq, n_of(dur))
    y = 2 * np.abs(2 * ph - 1) - 1
    if steps:
        y = np.round((y + 1) / 2 * (steps - 1)) / (steps - 1) * 2 - 1
    return y


def sine(freq, dur):
    ph, _ = _phase(freq, n_of(dur))
    return np.sin(2 * np.pi * ph)


def noise(dur, rate=SR):
    """White noise, sample-and-held at `rate` Hz (lower rate = grittier, NES-noise-like)."""
    n = n_of(dur)
    if rate >= SR:
        return RNG.uniform(-1, 1, n)
    vals = RNG.uniform(-1, 1, int(n * rate / SR) + 2)
    return vals[(np.arange(n) * rate / SR).astype(int)]


def sweep(f0, f1, dur, curve="exp"):
    n = n_of(dur)
    x = np.linspace(0, 1, n)
    return f0 * (f1 / f0) ** x if curve == "exp" else f0 + (f1 - f0) * x


def perc(dur, decay, attack=0.001):
    n = n_of(dur)
    e = np.exp(-np.arange(n) / SR / decay)
    a = max(1, n_of(attack))
    e[:a] *= np.linspace(0, 1, a)
    return e


def adsr(dur, a=0.003, d=0.06, s=0.7, r=0.05):
    """Total length = dur; release happens in the last r seconds."""
    n = n_of(dur)
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-9), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-9)))
    rn = min(n_of(r), n)
    if rn > 0:
        e[n - rn:] *= np.linspace(1, 0, rn) ** 2
    return e


def fade(x, fin=0.001, fout=0.004):
    x = x.copy()
    a, b = min(n_of(fin), len(x)), min(n_of(fout), len(x))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def filt(x, kind, f, order=2):
    sos = signal.butter(order, f, kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=-1)


def lp(x, f, order=2):
    return filt(x, "lowpass", f, order)


def hp(x, f, order=2):
    return filt(x, "highpass", f, order)


def bp(x, lo, hi, order=2):
    return filt(x, "bandpass", [lo, hi], order)


def svf_bp(x, fc, q=2.0):
    """Time-varying band-pass (TPT state-variable filter); fc may be an array (for whooshes)."""
    fc = _freq(fc, len(x))
    g = np.tan(np.pi * np.clip(fc, 20, SR * 0.45) / SR)
    k = 1.0 / q
    y = np.zeros_like(x)
    ic1 = ic2 = 0.0
    for i in range(len(x)):
        a1 = 1.0 / (1.0 + g[i] * (g[i] + k))
        a2 = g[i] * a1
        a3 = g[i] * a2
        v3 = x[i] - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1, ic2 = 2 * v1 - ic1, 2 * v2 - ic2
        y[i] = v1
    return y


def mix(parts):
    """parts = [(signal, start_seconds, gain_db), ...] -> summed mono buffer."""
    n = max(n_of(at) + len(s) for s, at, _ in parts)
    out = np.zeros(n)
    for s, at, g in parts:
        i = n_of(at)
        out[i:i + len(s)] += s * db(g)
    return out


def vibrato(f, dur, rate=5.5, cents=15, delay=0.12):
    t = np.arange(n_of(dur)) / SR
    depth = np.clip((t - delay) / 0.1, 0, 1) * cents
    return f * 2 ** (depth * np.sin(2 * np.pi * rate * t) / 1200)


# ----------------------------------------------------------------------------- foley-like layers
def modes(spec, dur, pitch_drop=0.0):
    """Modal synthesis: spec = [(freq, decay_s, gain_db)]. Gives wood/plastic body resonances."""
    out = np.zeros(n_of(dur))
    for f, dec, g in spec:
        fr = f * (1 + pitch_drop * np.exp(-np.arange(len(out)) / SR / 0.01))
        out += sine(fr, dur) * perc(dur, dec, 0.0003) * db(g)
    return out


def wood_thock(dur=0.12):
    body = modes([(190, 0.035, 0), (520, 0.018, -4), (1130, 0.009, -9), (1900, 0.005, -14)], dur, 0.25)
    knock = bp(noise(dur), 700, 3500) * perc(dur, 0.004)
    return body + knock * db(-6)


def cardboard_tap(dur=0.06):
    body = modes([(340, 0.012, 0), (860, 0.006, -6)], dur)
    return body + bp(noise(dur), 400, 1800) * perc(dur, 0.010) * db(-2)


def finger_snap(dur=0.04):
    return hp(noise(dur), 2500) * perc(dur, 0.005, 0.0003) + bp(noise(dur), 2200, 3800, 4) * perc(dur, 0.012) * db(-8)


def click(dur=0.02, lo=1500, hi=6000, decay=0.003):
    return bp(noise(dur), lo, hi) * perc(dur, decay, 0.0002)


def woodblock(dur=0.06, f=1700):
    return modes([(f, 0.022, 0), (f * 1.68, 0.010, -6), (f * 2.9, 0.004, -12)], dur) + click(dur, 2000, 7000, 0.002) * db(-10)


def whistle(dur=0.48, f=2250):
    """Referee 'pea' whistle: tone with a ~30 Hz rattle (AM+FM) and breath noise; pitch kept moderate."""
    t = np.arange(n_of(dur)) / SR
    rattle = np.sin(2 * np.pi * 31 * t)
    fr = f * (1 + 0.012 * rattle) * (1 + 0.03 * np.exp(-t / 0.04))
    tone = sine(fr, dur) * (0.65 + 0.35 * rattle) + 0.15 * sine(fr * 2, dur)
    breath = bp(noise(dur), f * 0.7, f * 1.5) * 0.25
    shape = np.clip(t / 0.02, 0, 1) * np.clip((dur - t) / 0.06, 0, 1) * (1 - 0.25 * t / dur)
    return (tone + breath) * shape


def whoosh(dur, f0, f1, q=1.6):
    fc = sweep(f0, f1, dur)
    t = np.linspace(0, 1, n_of(dur))
    return svf_bp(noise(dur), fc, q) * np.sin(np.pi * t) ** 1.5


def sparkle(dur=0.25, decay=0.09):
    return bp(noise(dur, 9000), 5000, 9000) * perc(dur, decay) * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * np.arange(n_of(dur)) / SR))


# ----------------------------------------------------------------------------- chip voices
def blip(f, dur, duty=0.25, decay=None, a=0.001):
    return pulse(f, dur, duty) * (perc(dur, decay, a) if decay else adsr(dur, a, 0.05, 0.6, min(0.03, dur / 3)))


def chirp(f0, f1, dur, duty=0.25, decay=0.04):
    return pulse(sweep(f0, f1, dur), dur, duty) * perc(dur, decay)


# ----------------------------------------------------------------------------- SFX definitions
def sfx_ui_tap():
    return mix([(blip(hz("E6"), 0.045, 0.25, 0.016), 0, 0), (click(0.02), 0, -8), (modes([(620, 0.01, 0)], 0.04), 0, -10)])


def sfx_ui_back():
    return mix([(chirp(990, 620, 0.08, 0.5, 0.045), 0, 0), (click(0.02, 900, 4000), 0, -10)])


def sfx_ui_toggle_on():
    return mix([(blip(hz("C6"), 0.035, 0.25, 0.015), 0, -2), (blip(hz("G6"), 0.05, 0.25, 0.02), 0.04, 0), (click(0.02), 0, -10)])


def sfx_ui_toggle_off():
    x = mix([(blip(hz("G6"), 0.035, 0.25, 0.015), 0, -2), (blip(hz("C6"), 0.05, 0.25, 0.02), 0.04, 0), (click(0.02), 0, -10)])
    return lp(x, 4500)


def sfx_lock_on():
    return mix([(tri(hz("A6"), 0.04) * perc(0.04, 0.012), 0, 0), (click(0.01, 3000, 7000, 0.0015), 0, -12)])


def sfx_blaster_cock():
    c1 = click(0.03, 1200, 6000, 0.004) + modes([(900, 0.008, -4)], 0.03)
    c2 = click(0.04, 1800, 7000, 0.003) + modes([(1400, 0.006, -4), (420, 0.012, -6)], 0.04)
    return mix([(c1, 0, -3), (c2, 0.038, 0), (blip(330, 0.025, 0.5, 0.01), 0.038, -12)])


def sfx_pew(f0=1200, f1=400, duty=0.5):
    d = 0.12
    zap = pulse(sweep(f0, f1, d), d, duty) * perc(d, 0.055)
    sub = tri(sweep(320, 120, d), d) * perc(d, 0.03)
    return mix([(zap, 0, 0), (sub, 0, -8), (finger_snap(), 0, -7)])


def sfx_miss():
    return mix([(click(0.06, 1500, 5000, 0.005), 0, 0), (modes([(1200, 0.008, 0)], 0.06), 0, -6)])


def _hit(n1, n2, dur=0.25):
    ding1 = pulse(hz(n1), 0.07, 0.5) * adsr(0.07, 0.001, 0.03, 0.6, 0.01)
    ding2 = pulse(hz(n2), dur - 0.06, 0.5) * perc(dur - 0.06, 0.07)
    pop = noise(0.035, 8000) * perc(0.035, 0.008)
    return mix([(wood_thock(), 0, -6), (pop, 0, -12), (lp(ding1, 7000), 0.004, -3), (lp(ding2, 7000), 0.06, 0)])


def sfx_hit():
    return _hit("C6", "E6")


def sfx_hit_red():
    return _hit("D#6", "G6")


def sfx_bullseye():
    d = 0.4
    a1 = lp(pulse(hz("C6"), 0.06, 0.5) * perc(0.06, 0.04), 7000)
    a2 = lp(pulse(hz("E6"), 0.06, 0.5) * perc(0.06, 0.04), 7000)
    a3 = lp(pulse(vibrato(hz("G6"), d - 0.1, 7, 20, 0.05), d - 0.1, 0.5) * perc(d - 0.1, 0.11), 7000)
    shimmer = tri(hz("C7"), d - 0.12) * perc(d - 0.12, 0.1) * (0.6 + 0.4 * np.sin(2 * np.pi * 24 * np.arange(n_of(d - 0.12)) / SR))
    return mix([(wood_thock(), 0, -6), (a1, 0.004, -2), (a2, 0.05, -2), (a3, 0.10, 0), (shimmer, 0.12, -12), (sparkle(0.25), 0.1, -20)])


def _spawn_chirp(f0, f1, dur=0.06):
    # bright broadband onset (2-6 kHz, ~25 ms) gives the HRTF pinna cues; the chirp carries identity
    onset = bp(noise(0.03), 2000, 6000) * perc(0.03, 0.009, 0.0003)
    return mix([(onset, 0, -4), (chirp(f0, f1, dur, 0.25, 0.035), 0, 0), (tri(sweep(f0, f1, dur) * 2, dur) * perc(dur, 0.02), 0, -14)])


def sfx_spawn():
    return mix([(_spawn_chirp(600, 1000), 0, -1), (_spawn_chirp(900, 1400, 0.07), 0.068, 0)])


def sfx_spawn_roam():
    return mix([(_spawn_chirp(600, 1000), 0, -2), (_spawn_chirp(750, 1200), 0.1, -1), (_spawn_chirp(900, 1400, 0.08), 0.2, 0)])


def sfx_expire():
    d = 0.16
    fwip = pulse(sweep(900, 250, d), d, 0.5) * perc(d, 0.07)
    air = whoosh(0.12, 3000, 600, 2.0)
    return mix([(fwip, 0, 0), (air, 0, -6), (cardboard_tap(), 0.13, -7)])


def sfx_count():
    d = 0.15
    return mix([(lp(pulse(hz("A5"), d, 0.5) * adsr(d, 0.002, 0.05, 0.55, 0.04), 7000), 0, 0), (woodblock(0.04, 1400), 0, -12)])


def sfx_go():
    d = 0.3
    f = np.concatenate([sweep(hz("A5"), hz("A6"), 0.04), vibrato(hz("A6"), d - 0.04, 7, 18, 0.06)])
    lead = lp(pulse(f, d, 0.5) * adsr(d, 0.002, 0.08, 0.6, 0.1), 7000)
    body = tri(hz("A4"), d) * adsr(d, 0.002, 0.1, 0.5, 0.1)
    crash = bp(noise(d, 12000), 3000, 8000) * perc(d, 0.08)
    return mix([(lead, 0, 0), (body, 0, -6), (crash, 0, -16), (wood_thock(), 0, -12)])


def sfx_tick():
    return mix([(woodblock(0.05, 1700), 0, 0), (blip(1700, 0.01, 0.5, 0.004), 0, -14)])


def sfx_tally():
    return mix([(pulse(hz("B5"), 0.012, 0.5), 0, 0), (pulse(hz("E6"), 0.028, 0.5) * perc(0.028, 0.014), 0.012, 0)])


def sfx_end():
    triad = [lp(pulse(hz(n), 0.17, 0.5) * adsr(0.17, 0.002, 0.06, 0.6, 0.05), 6000) for n in ("G5", "E5", "C5")]
    return mix([(whistle(), 0, -2), (triad[0], 0.30, 0), (triad[1], 0.42, 0), (triad[2], 0.54, 0), (tri(hz("C4"), 0.17) * perc(0.17, 0.08), 0.54, -6)])


def sfx_time_up_buzzer():
    d = 0.6
    x = pulse(233, d, 0.5) + pulse(247, d, 0.25) * 0.7
    return lp(x, 2500) * adsr(d, 0.004, 0.2, 0.8, 0.08)


def _combo(n1, n2):
    s1 = pulse(sweep(hz(n1) * 0.94, hz(n1), 0.07), 0.07, 0.25) * adsr(0.07, 0.001, 0.03, 0.6, 0.01)
    s2 = pulse(vibrato(hz(n2), 0.12, 14, 30, 0.02), 0.12, 0.25) * perc(0.12, 0.06)
    return lp(mix([(s1, 0, -2), (s2, 0.075, 0)]), 7500)


def sfx_combo():
    return _combo("C6", "G6")


def sfx_combo_x2():
    return _combo("F6", "C7")


def sfx_combo_break():
    d = 0.18
    return mix([(tri(sweep(520, 260, d), d) * perc(d, 0.08), 0, 0), (pulse(sweep(520, 260, d), d, 0.5) * perc(d, 0.05), 0, -14)])


def sfx_new_high_score():
    step = 0.1
    parts = []
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        parts.append((lp(pulse(hz(n), 0.09, 0.25) * adsr(0.09, 0.001, 0.03, 0.6, 0.02), 7000), i * step, -2))
    hold = 0.75
    trill = np.concatenate([pulse(hz(n), 0.05, 0.5) for n in ["G6", "E6"] * 8])[: n_of(hold)]
    parts += [
        (lp(trill * perc(hold, 0.35), 6500), 0.5, 0),
        (tri(hz("C5"), hold) * adsr(hold, 0.003, 0.2, 0.6, 0.2), 0.5, -4),
        (tri(hz("C4"), 0.3) * perc(0.3, 0.12), 0.5, -4),
        (sparkle(0.5, 0.2), 0.5, -18),
        (wood_thock(), 0.5, -12),
    ]
    return mix(parts)


def _bell(f, dur, decay):
    return modes([(f, decay, 0), (f * 2.0, decay * 0.6, -8), (f * 2.76, decay * 0.4, -12), (f * 5.4, decay * 0.2, -20)], dur)


def sfx_tutorial_success():
    return mix([(_bell(hz("G5"), 0.2, 0.1), 0, -2), (tri(hz("G5"), 0.08) * perc(0.08, 0.04), 0, -8),
                (_bell(hz("C6"), 0.35, 0.16), 0.1, 0), (tri(hz("C6"), 0.1) * perc(0.1, 0.05), 0.1, -8)])


def _arp(notes, step, duty=0.25, gain=0):
    return [(lp(pulse(hz(n), step * 1.4, duty) * perc(step * 1.4, step * 0.6), 6000), i * step, gain) for i, n in enumerate(notes)]


def sfx_arena_open():
    notes = ["C4", "E4", "G4", "C5", "E5", "G5", "C6"]
    return mix([(whoosh(0.7, 300, 4000), 0, -2)] + _arp(notes, 0.07, gain=-6) + [(_bell(hz("C6"), 0.4, 0.15), 0.49, -8)])


def sfx_arena_close():
    notes = ["C6", "G5", "E5", "C5", "G4", "E4", "C4"]
    return mix([(whoosh(0.65, 4000, 300), 0, -2)] + _arp(notes, 0.07, gain=-6) + [(cardboard_tap(), 0.5, -10)])


SFX = {
    "ui_tap": sfx_ui_tap, "ui_back": sfx_ui_back, "ui_toggle_on": sfx_ui_toggle_on, "ui_toggle_off": sfx_ui_toggle_off,
    "lock_on": sfx_lock_on, "blaster_cock": sfx_blaster_cock,
    "pew": sfx_pew, "pew_b": lambda: sfx_pew(1100, 360, 0.25), "miss": sfx_miss,
    "spawn": sfx_spawn, "spawn_roam": sfx_spawn_roam,
    "hit": sfx_hit, "hit_red": sfx_hit_red, "bullseye": sfx_bullseye, "expire": sfx_expire,
    "count": sfx_count, "go": sfx_go, "tick": sfx_tick, "tally": sfx_tally,
    "end": sfx_end, "time_up_buzzer": sfx_time_up_buzzer,
    "combo": sfx_combo, "combo_x2": sfx_combo_x2, "combo_break": sfx_combo_break,
    "new_high_score": sfx_new_high_score, "tutorial_success": sfx_tutorial_success,
    "arena_open": sfx_arena_open, "arena_close": sfx_arena_close,
}


# ----------------------------------------------------------------------------- loudness (ITU-R BS.1770-4)
_K1 = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585])
_K2 = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])


def _kweight(x):
    x = np.atleast_2d(x)
    return signal.lfilter(*_K2, signal.lfilter(*_K1, x, axis=-1), axis=-1)


def _block_powers(x, win=0.4, hop=0.1):
    y = _kweight(x) ** 2
    w, h = n_of(win), n_of(hop)
    cs = np.concatenate([np.zeros((y.shape[0], 1)), np.cumsum(y, axis=1)], axis=1)
    starts = np.arange(0, y.shape[1] - w + 1, h)
    return ((cs[:, starts + w] - cs[:, starts]) / w).sum(axis=0)


def lufs_integrated(x):
    z = _block_powers(x)
    z = z[z > 0]
    lk = -0.691 + 10 * np.log10(z)
    z = z[lk > -70]
    rel = -0.691 + 10 * np.log10(z.mean()) - 10
    z = z[-0.691 + 10 * np.log10(z) > rel]
    return -0.691 + 10 * np.log10(z.mean())


def lufs_momentary_max(x):
    pad = np.zeros(np.atleast_2d(x).shape[:-1] + (n_of(0.4),))
    xx = np.concatenate([pad, np.atleast_2d(x), pad], axis=-1)
    z = _block_powers(xx, 0.4, 0.005)
    return -0.691 + 10 * np.log10(z.max() + 1e-20)


def peak_dbfs(x):
    return 20 * np.log10(np.max(np.abs(x)) + 1e-12)


# ----------------------------------------------------------------------------- SFX finishing
def trim(x, thresh_db=-60):
    a = np.abs(x)
    idx = np.nonzero(a > db(thresh_db) * a.max())[0]
    return x[max(0, idx[0] - n_of(0.001)): idx[-1] + 1]


def limit(x, ceiling_db, look=0.0015, release=0.03, max_gr_db=6.0):
    """Look-ahead peak limiter (gain never rises above what any nearby peak needs)."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    need = np.minimum(1.0, db(ceiling_db) / (np.abs(x) + 1e-12))
    need = np.maximum(need, db(-max_gr_db))
    w = max(1, n_of(look))
    g = minimum_filter1d(need, 2 * w + 1)
    coef = 1 - np.exp(-1 / (release * SR))
    r = np.empty_like(g)
    prev = 1.0
    for i in range(len(g)):
        prev = min(g[i], prev + (1 - prev) * coef)
        r[i] = prev
    return x * uniform_filter1d(r, 2 * w + 1)


def finish_sfx(x, target):
    x = lp(hp(x, SFX_HPF_HZ), SFX_LPF_HZ, order=4)
    x = fade(trim(x))
    for _ in range(4):
        x = x * db(target - lufs_momentary_max(x))
        if peak_dbfs(x) > PEAK_CEIL_DBFS:
            x = limit(x, PEAK_CEIL_DBFS - 0.1)
    over = peak_dbfs(x) - PEAK_CEIL_DBFS
    if over > 0:
        x *= db(-over)
    return x


def to_int16(x):
    tpdf = (RNG.uniform(-0.5, 0.5, x.shape) + RNG.uniform(-0.5, 0.5, x.shape)) / 32767
    return np.clip(np.round((x + tpdf) * 32767), -32768, 32767).astype(np.int16)


def write_wav(path, x):
    """x: mono (n,) or stereo (2, n) float."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = to_int16(x.T if x.ndim == 2 else x)
    wavfile.write(path, SR, data)


# ----------------------------------------------------------------------------- music engine
def pan_gains(p):
    a = (p + 1) * np.pi / 4
    return np.cos(a), np.sin(a)


class Loop:
    """Circular stereo multitrack. Notes may run past the end: their tails wrap to the start."""

    def __init__(self, bpm, bars, loop=True):
        spb = SR * 60 / bpm
        assert loop is False or abs(spb - round(spb)) < 1e-9, "choose a BPM with integer samples per beat"
        self.spb = spb
        self.loop = loop
        self.L = int(round(bars * 4 * spb))
        self.buses = {}

    def add(self, bus, sig, beat, pan=0.0, gain_db=0.0):
        b = self.buses.setdefault(bus, np.zeros((2, self.L + SR * 4)))
        s = int(round(beat * self.spb))
        gl, gr = pan_gains(pan)
        n = min(len(sig), b.shape[1] - s)
        b[0, s:s + n] += sig[:n] * gl * db(gain_db)
        b[1, s:s + n] += sig[:n] * gr * db(gain_db)

    def _fold(self, b):
        out = b[:, :self.L].copy()
        if self.loop:
            tail = b[:, self.L:]
            out[:, :tail.shape[1]] += tail
            return out
        return b

    def loop_filter(self, x, fn):
        if not self.loop:
            return fn(x)
        return fn(np.concatenate([x, x, x], axis=1))[:, 2 * self.L:]

    def delay(self, x, beats, fb=0.35, wet_db=-10, taps=5, pingpong=True):
        d = int(round(beats * self.spb))
        out = x.copy()
        mono = x.mean(axis=0)
        for k in range(1, taps + 1):
            if self.loop:
                tap = np.roll(mono, k * d)
            else:
                tap = np.concatenate([np.zeros(k * d), mono])[: len(mono)]
            g = db(wet_db) * fb ** (k - 1)
            ch = (k % 2) if pingpong else None
            if ch is None:
                out += tap * g
            else:
                out[ch] += tap * g
        return out

    def render(self, fx=None):
        fx = fx or {}
        total = None
        for name, b in self.buses.items():
            x = self._fold(b)
            if name in fx:
                x = fx[name](self, x)
            total = x if total is None else total + x
        return total

    def beat_s(self, beats):
        return beats * self.spb / SR


def parse_line(text):
    """'E5 2,G5 1,R 1' -> [(midi|None, eighths)]"""
    out = []
    for tok in text.split(","):
        n, d = tok.split()
        out.append((None if n == "R" else note(n), float(d)))
    return out


CHORDS = {
    "C": ["C", "E", "G"], "G": ["G", "B", "D"], "Am": ["A", "C", "E"], "F": ["F", "A", "C"],
    "Em": ["E", "G", "B"], "Dm": ["D", "F", "A"],
    "Cmaj7": ["C", "E", "G", "B"], "Am7": ["A", "C", "E", "G"], "Fmaj7": ["F", "A", "C", "E"],
    "G6": ["G", "B", "D", "E"], "Em7": ["E", "G", "B", "D"], "Dm7": ["D", "F", "A", "C"], "G7": ["G", "B", "D", "F"],
}


def chord_midis(ch, octave):
    """Chord tones stacked upward from the root in `octave`."""
    base = note(CHORDS[ch][0] + str(octave))
    out = []
    for name in CHORDS[ch]:
        m = note(name + str(octave))
        while m < base:
            m += 12
        while out and m <= out[-1]:
            m += 12
        out.append(m)
    return out


# instruments ------------------------------------------------------------------
def i_lead(m, dur, duty=0.25, rel=0.06):
    d = dur + rel
    x = pulse(vibrato(midi_hz(m), d, 5.5, 14, 0.14), d, duty) * adsr(d, 0.003, 0.09, 0.62, rel)
    return lp(x, 5500)


def i_soft_lead(m, dur, rel=0.15):
    d = dur + rel
    x = tri(vibrato(midi_hz(m), d, 5, 12, 0.2), d) + 0.25 * pulse(midi_hz(m), d, 0.5)
    return lp(x * adsr(d, 0.01, 0.2, 0.6, rel), 3500)


def i_arp(m, dur, duty=0.125, decay=0.07):
    d = dur + 0.05
    return lp(pulse(midi_hz(m), d, duty) * perc(d, decay, 0.001), 5000)


def i_bass(m, dur):
    d = dur * 0.92
    x = tri(midi_hz(m), d, steps=16) + db(-12) * lp(pulse(midi_hz(m + 12), d, 0.5), 1200)
    return x * adsr(d, 0.002, 0.08, 0.85, 0.02)


def i_kick(gain=1.0):
    d = 0.18
    body = sine(sweep(170, 48, 0.07).tolist() + [48] * (n_of(d) - n_of(0.07)), d) * perc(d, 0.09, 0.0005)
    return (body + click(d, 1500, 5000, 0.002) * 0.25) * gain


def i_snare():
    d = 0.18
    return bp(noise(d), 1200, 7500) * perc(d, 0.07, 0.0005) * 0.8 + tri(sweep(220, 170, d), d) * perc(d, 0.035) * 0.6


def i_hat(open_=False):
    d = 0.16 if open_ else 0.05
    return lp(hp(noise(d), 6500), 11000) * perc(d, 0.06 if open_ else 0.012, 0.0005)


def i_shaker():
    d = 0.06
    return lp(hp(noise(d), 4000), 9000) * perc(d, 0.018, 0.004)


def i_pad(m, dur):
    d = dur + 0.4
    x = tri(midi_hz(m) * db(0.03), d) + tri(midi_hz(m) / db(0.03), d)
    return lp(x * adsr(d, 0.35, 0.5, 0.8, 0.5), 2500)


# ----------------------------------------------------------------------------- music: round loop + final-10 layer
ROUND_CHORDS = ["C", "G", "Am", "F", "C", "G", "Am", "F", "F", "G", "Em", "Am", "F", "G", "C", "G"]
ROUND_MELODY = [
    "E5 2,G5 1,A5 1,G5 2,E5 2", "D5 2,G5 1,B5 1,D6 2,B5 2", "C6 2,B5 1,A5 1,E5 2,C5 2", "F5 2,A5 1,C6 1,A5 3,R 1",
    "E5 1,E5 1,G5 1,C6 1,E6 2,D6 2", "D6 1,B5 1,G5 2,B5 2,D6 2", "C6 3,B5 1,A5 2,G5 2", "F5 2,G5 2,A5 2,B5 2",
    "A5 4,C6 2,A5 2", "B5 4,D6 2,B5 2", "G5 4,B5 2,E6 2", "E6 6,R 2",
    "F6 2,E6 2,D6 2,C6 2", "D6 2,C6 2,B5 2,G5 2", "C6 6,R 2", "R 4,G4 1,A4 1,B4 1,D5 1",
]
ROUND_BASS_ROOT = {"C": "C3", "G": "G2", "Am": "A2", "F": "F2", "Em": "E2"}


def build_round(final_layer=False):
    lp_ = Loop(ROUND_BPM, 16)
    bs = lp_.beat_s
    for bar, ch in enumerate(ROUND_CHORDS):
        b0 = bar * 4
        b_section = bar >= 8
        if not final_layer:
            # lead
            pos = 0.0
            for m, e in parse_line(ROUND_MELODY[bar]):
                if m is not None:
                    lp_.add("lead", i_lead(m, bs(e * 0.5) * 0.92, 0.5 if b_section else 0.25), b0 + pos * 0.5, -0.12, -4)
                pos += e
            assert abs(pos - 8) < 1e-9, f"bar {bar} melody length {pos}"
            # arp (16ths, chord tones in octave 4)
            tones = chord_midis(ch, 4)
            pat = [0, 1, 2, 3, 2, 1] if not b_section else [0, 2, 1, 3]
            seq = tones + [tones[0] + 12]
            for k in range(16):
                m = seq[pat[k % len(pat)] % len(seq)]
                lp_.add("arp", i_arp(m, bs(0.25)), b0 + k * 0.25, 0.35, -15 + (2 if k % 4 == 0 else 0))
            # bass: octave bounce 8ths in A, driving roots + fifths in B
            root = note(ROUND_BASS_ROOT[ch])
            bpat = [0, 0, 12, 0, 0, 0, 12, 0] if not b_section else [0, 0, 7, 0, 12, 0, 7, 0]
            for k, off in enumerate(bpat):
                lp_.add("bass", i_bass(root + off, bs(0.5)), b0 + k * 0.5, 0, -3)
            # drums
            kicks = [0, 2] + ([2.5] if bar % 4 == 3 else []) if not b_section else [0, 1.5, 2]
            for k in kicks:
                lp_.add("drums", i_kick(), b0 + k, 0, -2)
            for s in (1, 3):
                lp_.add("drums", i_snare(), b0 + s, 0, -7)
            for k in range(8):
                lp_.add("hats", i_hat(), b0 + k * 0.5, 0.2 if k % 2 else -0.2, -17 if k % 2 == 0 else -14)
            if bar == 15:  # snare fill into the loop point
                for i, k in enumerate(np.arange(2, 4, 0.25)):
                    lp_.add("drums", i_snare(), b0 + k, 0, -16 + i * 1.2)
        else:
            # intensity layer: four-on-the-floor, 16th hats, open-hat offbeats, high counter-arp
            for k in (1, 3):
                lp_.add("drums", i_kick(0.85), b0 + k, 0, -3)
            for k in range(16):
                lp_.add("hats", i_hat(), b0 + k * 0.25, -0.3 if k % 2 else 0.3, -21 if k % 4 else -18)
            for k in range(4):
                lp_.add("hats", i_hat(True), b0 + k + 0.5, 0, -19)
            tones = chord_midis(ch, 5)
            seq = [tones[0], tones[2], tones[1], tones[2]]
            for k in range(16):
                lp_.add("arp", i_arp(seq[k % 4], bs(0.25), 0.25, 0.05), b0 + k * 0.25, -0.45, -19)
            if bar == 15:
                for i, k in enumerate(np.arange(0, 4, 0.25)):
                    lp_.add("drums", i_snare(), b0 + k, 0, -22 + i * 0.8)
    fx = {
        "lead": lambda L, x: L.delay(x, 0.75, 0.32, -11),
        "arp": lambda L, x: L.delay(x, 0.5, 0.25, -14),
        "bass": lambda L, x: L.loop_filter(x, lambda y: hp(y, 45)),
    }
    return lp_.render(fx)


# ----------------------------------------------------------------------------- music: lobby loop
LOBBY_CHORDS = ["Cmaj7", "Am7", "Fmaj7", "G6", "Cmaj7", "Am7", "Fmaj7", "G6",
                "Fmaj7", "Em7", "Dm7", "G7", "Fmaj7", "Em7", "Am7", "G6"]
LOBBY_MELODY = {
    8: "C6 3,A5 1,F5 4", 9: "G5 3,B5 1,E5 4", 10: "F5 3,A5 1,D6 4", 11: "B5 6,R 2",
    12: "A5 2,C6 2,E6 4", 13: "D6 2,B5 2,G5 4", 14: "A5 2,C6 2,E6 2,D6 2", 15: "B5 4,R 4",
}
LOBBY_BASS = {"Cmaj7": "C3", "Am7": "A2", "Fmaj7": "F2", "G6": "G2", "Em7": "E2", "Dm7": "D3", "G7": "G2"}


def build_lobby():
    L = Loop(LOBBY_BPM, 16)
    bs = L.beat_s
    for bar, ch in enumerate(LOBBY_CHORDS):
        b0 = bar * 4
        tones = chord_midis(ch, 4)
        up = tones + [tones[0] + 12]
        pattern = [0, 1, 2, 3, 4, 3, 2, 1]
        for k, idx in enumerate(pattern):
            L.add("arp", i_arp(up[idx], bs(0.5), 0.5, 0.18), b0 + k * 0.5, 0.25 if k % 2 else -0.25, -12)
        for m in tones[1::2]:
            L.add("pad", i_pad(m, bs(4) * 0.95), b0, 0, -17)
        root = note(LOBBY_BASS[ch])
        L.add("bass", i_bass(root, bs(2)), b0, 0, -6)
        L.add("bass", i_bass(root + (7 if bar % 2 else 12), bs(2)), b0 + 2, 0, -8)
        for k in range(4):
            L.add("perc", i_shaker(), b0 + k + 0.5, 0.4, -20)
        L.add("perc", i_kick(0.6), b0, 0, -10)
        if bar >= 8:
            for k in (1, 3):
                L.add("perc", woodblock(0.06, 1100), b0 + k, -0.3, -22)
        if bar in LOBBY_MELODY:
            pos = 0.0
            for m, e in parse_line(LOBBY_MELODY[bar]):
                if m is not None:
                    L.add("lead", i_soft_lead(m, bs(e * 0.5) * 0.95), b0 + pos * 0.5, 0.1, -7)
                pos += e
            assert abs(pos - 8) < 1e-9
    fx = {
        "arp": lambda L_, x: L_.loop_filter(L_.delay(x, 0.75, 0.4, -9), lambda y: lp(y, 3200)),
        "lead": lambda L_, x: L_.delay(x, 0.75, 0.35, -12),
        "bass": lambda L_, x: L_.loop_filter(x, lambda y: hp(y, 45)),
    }
    return L.render(fx)


# ----------------------------------------------------------------------------- music: results sting
def build_results_sting():
    S = Loop(ROUND_BPM, 2, loop=False)
    bs = S.beat_s
    third = 1 / 3
    for i, n in enumerate(["G4", "C5", "E5"]):
        S.add("lead", i_lead(note(n), bs(third) * 0.9, 0.5), i * third, -0.1, -4)
        S.add("drums", i_snare(), i * third, 0, -14 + i * 2)
    line = [("G5", 1, 1.0), ("E5", 1.5, 0.5), ("G5", 2.0, 0.5), ("C6", 2.5, 2.6)]
    harm = {"G5": "E5", "E5": "C5", "C6": "G5"}
    for n, at, ln in line:
        S.add("lead", i_lead(note(n), bs(ln) * 0.92, 0.5), at, -0.1, -4)
        S.add("lead", i_lead(note(harm[n]), bs(ln) * 0.92, 0.25), at, 0.35, -10)
    for k in range(10):  # final-chord shimmer arp
        S.add("arp", i_arp(chord_midis("C", 5)[k % 3] + (12 if k >= 6 else 0), bs(0.25), 0.25, 0.08), 2.5 + k * 0.25, 0.4, -15)
    for at, n in [(1, "C3"), (2.5, "C3")]:
        S.add("bass", i_bass(note(n), bs(0.5 if at < 2.5 else 2.5)), at, 0, -3)
        S.add("drums", i_kick(), at, 0, -2)
    crash = lp(hp(noise(1.6), 3500), 10000) * perc(1.6, 0.45, 0.001)
    S.add("drums", crash, 2.5, 0, -16)
    S.add("drums", i_snare(), 2.5, 0, -6)
    out = S.render({"lead": lambda L, x: L.delay(x, 0.75, 0.3, -14)})
    end = n_of(S.beat_s(2.5) + 1.9)
    out = out[:, :end]
    out[:, -n_of(0.3):] *= np.linspace(1, 0, n_of(0.3)) ** 2
    return out


# ----------------------------------------------------------------------------- music finishing
def finish_music(x, target, ref=None, ceiling=MUSIC_PEAK_CEIL_DBFS):
    """Normalize to integrated LUFS (measured on the loop played twice). ref: measure on this instead."""
    x = x - x.mean(axis=1, keepdims=True)
    meas = lufs_integrated(np.concatenate([ref if ref is not None else x] * 2, axis=1))
    g = target - meas
    return g


def apply_gain_with_ceiling(x, g_db, ceiling):
    y = x * db(g_db)
    over = peak_dbfs(y) - ceiling
    if over > 0:
        y *= db(-over)
        g_db -= over
    return y, g_db


# ----------------------------------------------------------------------------- preview montage
def build_preview(out_dir, sfx_files, music):
    def st(x):
        return np.vstack([x, x]) if x.ndim == 1 else x

    def panned(x, p):
        gl, gr = pan_gains(p)
        return np.vstack([x * gl, x * gr])

    gap, group_gap = np.zeros((2, n_of(0.35))), np.zeros((2, n_of(0.9)))
    s = {k: wavfile.read(v)[1].astype(float) / 32768 for k, v in sfx_files.items()}
    groups = [
        ["ui_tap", "ui_back", "ui_toggle_on", "ui_toggle_off", "lock_on"],
        ["blaster_cock", "pew", "pew_b", "miss"],
        ["spawn", "spawn_roam", "hit", "hit_red", "bullseye", "expire"],
        ["count", "count", "count", "go"],
        ["tick", "tick", "tick", "tick", "tick", "end", "time_up_buzzer"],
        ["combo", "combo_x2", "combo_break", "new_high_score", "tutorial_success", "arena_open", "arena_close"],
    ]
    seq = []
    for g in groups:
        for name in g:
            seq += [st(s[name]), gap if name not in ("count", "tick") else np.zeros((2, n_of(0.85 if name == "count" else 0.7) - len(s[name])))]
        seq.append(group_gap)
    # spatial hint: the spawn cue left -> center -> right
    for p in (-0.9, 0, 0.9):
        seq += [panned(s["spawn"], p), np.zeros((2, n_of(0.6)))]
    seq.append(group_gap)
    tally = np.zeros((2, n_of(0.8)))
    for k in range(10):
        i = n_of(k * 0.075)
        tally[:, i:i + s["tally"].shape[0]] += st(s["tally"])
    seq += [tally, group_gap]

    def excerpt(x, secs, fin=0.05, fout=1.0):
        y = x[:, :n_of(secs)].copy()
        y[:, :n_of(fin)] *= np.linspace(0, 1, n_of(fin))
        y[:, -n_of(fout):] *= np.linspace(1, 0, n_of(fout))
        return y

    seq += [excerpt(music["music_lobby_loop"], 12), group_gap]
    rnd, intense = music["music_round_loop"], music["music_round_intense_loop"]
    xf = n_of(0.4)
    a = rnd[:, :n_of(10.4)].copy()
    b = intense[:, n_of(10.0):n_of(18.0)].copy()
    a[:, -xf:] *= np.linspace(1, 0, xf)
    b[:, :xf] *= np.linspace(0, 1, xf)
    joined = np.concatenate([a[:, :-xf], a[:, -xf:] + b[:, :xf], b[:, xf:]], axis=1)
    joined[:, -n_of(0.15):] *= np.linspace(1, 0, n_of(0.15))
    seq += [joined, st(s["end"]), np.zeros((2, n_of(0.6))), music["music_results_sting"], group_gap]
    out = np.concatenate(seq, axis=1)
    wav = os.path.join(out_dir, "preview_all.wav")
    write_wav(wav, out)
    mp3 = os.path.join(out_dir, "preview_all.mp3")
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-codec:a", "libmp3lame", "-b:a", "192k", mp3], check=True)
        os.remove(wav)
        return mp3
    return wav


# ----------------------------------------------------------------------------- verify
def verify(out_dir):
    rows = []
    for sub in ("music", "sfx"):
        d = os.path.join(out_dir, sub)
        for f in sorted(os.listdir(d)):
            if not f.endswith(".wav"):
                continue
            sr, data = wavfile.read(os.path.join(d, f))
            x = data.astype(float).T / 32768
            ch = 1 if x.ndim == 1 else x.shape[0]
            row = {"file": f"{sub}/{f}", "sr": sr, "channels": ch, "duration_s": round(x.shape[-1] / sr, 4),
                   "samples": int(x.shape[-1]), "peak_dbfs": round(peak_dbfs(x), 2)}
            if sub == "sfx":
                row["lufs_momentary_max"] = round(lufs_momentary_max(x), 1)
                lead = np.nonzero(np.abs(x) > db(-60))[0]
                row["leading_silence_ms"] = round(lead[0] / sr * 1000, 1)
            else:
                row["lufs_integrated"] = round(lufs_integrated(np.concatenate([x, x], axis=-1) if ("loop" in f or "layer" in f) else x), 1)
            if "loop" in f or "layer" in f:
                d_ = np.abs(np.diff(x, axis=-1))
                jump = np.max(np.abs(x[..., 0] - x[..., -1]))
                row["loop_boundary_jump"] = round(float(jump), 5)
                row["loop_p999_step"] = round(float(np.percentile(d_, 99.9)), 5)
                row["loop_seamless"] = bool(jump <= np.percentile(d_, 99.9))
            assert sr == SR and row["peak_dbfs"] <= -0.9, row
            rows.append(row)
    return rows


# ----------------------------------------------------------------------------- main
def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=here)
    ap.add_argument("--no-preview", action="store_true")
    args = ap.parse_args()
    out = args.out
    sfx_dir, mus_dir = os.path.join(out, "sfx"), os.path.join(out, "music")

    sfx_files = {}
    for name, fn in SFX.items():
        x = finish_sfx(fn(), SFX_LUFS[name])
        p = os.path.join(sfx_dir, f"{name}.wav")
        write_wav(p, x)
        sfx_files[name] = p
        print(f"sfx   {name:18s} {len(x) / SR * 1000:6.0f} ms")

    music = {}
    rnd = build_round()
    layer = build_round(final_layer=True) * db(FINAL10_LAYER_DB)
    g = finish_music(rnd, MUSIC_LUFS["music_round_loop"])
    # round, layer and intense share one gain, so round + layer summed at unity == intense
    peak_lim = PEAK_CEIL_DBFS - peak_dbfs((rnd + layer) * db(g))
    g = g + min(0.0, peak_lim)
    music["music_round_loop"] = rnd * db(g)
    music["music_round_final10_layer"] = layer * db(g)
    music["music_round_intense_loop"] = (rnd + layer) * db(g)
    lobby = build_lobby()
    music["music_lobby_loop"], _ = apply_gain_with_ceiling(lobby, finish_music(lobby, MUSIC_LUFS["music_lobby_loop"]), MUSIC_PEAK_CEIL_DBFS)
    sting = build_results_sting()
    sg = MUSIC_LUFS["music_results_sting"] - lufs_integrated(sting)
    music["music_results_sting"], _ = apply_gain_with_ceiling(sting, sg, MUSIC_PEAK_CEIL_DBFS)
    for name, x in music.items():
        write_wav(os.path.join(mus_dir, f"{name}.wav"), x)
        print(f"music {name:28s} {x.shape[1] / SR:6.2f} s")

    if not args.no_preview:
        print("preview ->", build_preview(out, sfx_files, music))

    rows = verify(out)
    with open(os.path.join(out, "manifest.json"), "w") as f:
        json.dump({"sample_rate": SR, "round_bpm": ROUND_BPM, "lobby_bpm": LOBBY_BPM, "files": rows}, f, indent=1)
    print(f"\n{'file':40s} {'ch':>2s} {'dur s':>8s} {'peak':>6s} {'LUFS':>6s}  loop")
    for r in rows:
        lu = r.get("lufs_momentary_max", r.get("lufs_integrated"))
        print(f"{r['file']:40s} {r['channels']:2d} {r['duration_s']:8.3f} {r['peak_dbfs']:6.1f} {lu:6.1f}  {r.get('loop_seamless', '')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
