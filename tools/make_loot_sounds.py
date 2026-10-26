"""Generate Tarkov Looting's sounds (original, procedurally synthesised).

Usage: python tools/make_loot_sounds.py
Writes mods/TarkovLooting/TarkovLooting/Sounds/{rummage,found}.wav:
  rummage  2.4 s seamless loop of hands going through cloth, paper and plastic
  found    short soft "pick-up" cue when a searched item is revealed
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "mods", "TarkovLooting", "TarkovLooting", "Sounds")
rng = np.random.default_rng(509)


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f[(freqs < lo) | (freqs > hi)] = 0
    return np.fft.irfft(f, len(x))


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t / decay)


def write(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    pcm = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# --- rummage: many short rustle grains (cloth = low band, paper/plastic =
# high band), placed on a circular timeline so the loop has no seam.
n = int(SR * 2.4)
out = np.zeros(n)
for _ in range(70):
    length = int(SR * rng.uniform(0.04, 0.22))
    lo, hi = (300, 2500) if rng.random() < 0.6 else (1800, 7000)
    grain = bandpass(rng.standard_normal(length), lo, hi)
    grain *= env(length, rng.uniform(0.005, 0.03), rng.uniform(0.03, 0.09)) * rng.uniform(0.3, 1.0)
    start = rng.integers(0, n)
    idx = (start + np.arange(length)) % n
    out[idx] += grain
# a few soft knocks (things bumping inside the container)
for _ in range(5):
    length = int(SR * 0.12)
    t = np.arange(length) / SR
    knock = np.sin(2 * np.pi * rng.uniform(90, 160) * t) * env(length, 0.002, 0.025) * 0.6
    idx = (rng.integers(0, n) + np.arange(length)) % n
    out[idx] += knock
write("rummage", out * 0.6)

# --- found: soft cloth slide into a muted two-note tick.
length = int(SR * 0.35)
t = np.arange(length) / SR
slide = bandpass(rng.standard_normal(length), 600, 4000) * env(length, 0.02, 0.06) * 0.5
tick = (np.sin(2 * np.pi * 660 * t) * env(length, 0.002, 0.05)
        + 0.6 * np.sin(2 * np.pi * 990 * np.clip(t - 0.06, 0, None)) * env(length, 0.002, 0.07) * (t > 0.06))
write("found", slide + tick * 0.7)
print("wrote", OUT)
