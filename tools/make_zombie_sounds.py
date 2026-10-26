"""Generate CleanStrike Zombies' voices (original, procedurally synthesised).

Usage: python tools/make_zombie_sounds.py
Writes dist/zombie_synth_voices/*.wav (22.05 kHz mono). The mod ships the
owner-supplied pack instead (see CSZombies/Sounds/SOURCE.txt); these are the
fallback, original voices, same names:
  moan_1..8     low, rattling moans while wandering or closing in
  scream_1..3   the call that brings the pack
  attack_1..4   short effort grunts with a blow
  hit_1..3      pained grunts when shot
  death_1..3    a last gurgle
A rough voice source (jittery sawtooth with period doubling for the rattle)
through vowel formants, plus breath noise and bubbling gurgles.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "dist", "zombie_synth_voices")
rng = np.random.default_rng(1031)

VOWELS = {  # formant (Hz, bandwidth)
    "uh": [(520, 90), (1190, 120), (2390, 180)],
    "ah": [(730, 110), (1090, 130), (2440, 200)],
    "oh": [(500, 90), (850, 110), (2400, 200)],
    "ae": [(660, 110), (1720, 150), (2410, 220)],
}


def resonator(x, f, bw):
    """Two-pole resonator (one formant)."""
    r = np.exp(-np.pi * bw / SR)
    a1 = -2 * r * np.cos(2 * np.pi * f / SR)
    a2 = r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    g = 1 - r
    for i in range(len(x)):
        v = g * x[i] - a1 * y1 - a2 * y2
        y[i] = v
        y2, y1 = y1, v
    return y


def source(f0, rattle):
    """Glottal-ish pulse train following the pitch contour f0 (per sample)."""
    jitter = 1 + 0.06 * np.cumsum(rng.normal(0, 0.02, len(f0))) / np.sqrt(np.arange(1, len(f0) + 1))
    f = f0 * jitter * (1 + 0.03 * rng.normal(0, 1, len(f0)))
    phase = np.cumsum(f / SR)
    saw = 2 * (phase % 1.0) - 1
    sub = 2 * ((phase / 2) % 1.0) - 1                         # period doubling: the rattle
    x = saw + rattle * sub
    x *= 1 + rattle * 0.8 * np.sin(2 * np.pi * np.cumsum(np.full(len(f0), 23.0) / SR))
    return x


def voice(dur, f0_a, f0_b, vowel, rattle=0.6, breath=0.25, curve=1.0):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    f0 = f0_a + (f0_b - f0_a) * t ** curve
    x = source(f0, rattle)
    x += breath * rng.normal(0, 1, n)
    y = np.zeros(n)
    for (f, bw), gain in zip(VOWELS[vowel], [1.0, 0.6, 0.25]):
        y += gain * resonator(x, f * rng.uniform(0.92, 1.08), bw)
    return y


def envelope(n, attack, release, wobble=0.0):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(attack, 1e-3)) * np.minimum(1, (t[-1] - t) / max(release, 1e-3))
    if wobble:
        e *= 1 + wobble * np.sin(2 * np.pi * rng.uniform(2, 5) * t)
    return np.clip(e, 0, None)


def gurgle(dur, rate):
    n = int(dur * SR)
    y = np.zeros(n)
    for _ in range(int(dur * rate)):
        at = rng.integers(0, max(1, n - 2000))
        ln = rng.integers(300, 1400)
        f = rng.uniform(150, 450)
        t = np.arange(ln) / SR
        y[at:at + ln] += np.sin(2 * np.pi * f * t * (1 + 2 * t)) * np.exp(-t * 40)
    return y


def finish(y, gain=0.8):
    y = np.tanh(2.2 * y / (np.max(np.abs(y)) + 1e-9))     # grit
    y = y / (np.max(np.abs(y)) + 1e-9) * gain
    return y


def save(name, y):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    for i in range(8):
        d = rng.uniform(1.4, 2.6)
        y = voice(d, rng.uniform(85, 110), rng.uniform(55, 75), rng.choice(["uh", "oh", "ah"]), rattle=rng.uniform(0.5, 0.9))
        y *= envelope(len(y), 0.25, 0.6, wobble=0.25)
        save("moan_%d" % (i + 1), finish(y, 0.75))
    for i in range(3):
        d = rng.uniform(1.6, 2.2)
        y = voice(d, rng.uniform(170, 210), rng.uniform(300, 380), rng.choice(["ah", "ae"]), rattle=0.9, breath=0.5, curve=0.5)
        y *= envelope(len(y), 0.08, 0.5, wobble=0.15)
        save("scream_%d" % (i + 1), finish(y, 0.95))
    for i in range(4):
        d = rng.uniform(0.35, 0.55)
        y = voice(d, rng.uniform(120, 150), rng.uniform(80, 100), rng.choice(["uh", "ah"]), rattle=0.7, breath=0.6)
        y *= envelope(len(y), 0.02, 0.2)
        save("attack_%d" % (i + 1), finish(y, 0.9))
    for i in range(3):
        d = rng.uniform(0.3, 0.5)
        y = voice(d, rng.uniform(140, 170), rng.uniform(100, 120), "ae", rattle=0.8, breath=0.5)
        y *= envelope(len(y), 0.01, 0.25)
        save("hit_%d" % (i + 1), finish(y, 0.85))
    for i in range(3):
        d = rng.uniform(1.6, 2.2)
        y = voice(d, rng.uniform(90, 110), 40, "oh", rattle=0.9, breath=0.4, curve=0.7)
        y = y * envelope(len(y), 0.05, 1.0) + 0.6 * gurgle(d, 9) * envelope(len(y), 0.3, 0.4)
        save("death_%d" % (i + 1), finish(y, 0.8))
    print("wrote", len(os.listdir(OUT)), "sounds to", OUT)


if __name__ == "__main__":
    main()
