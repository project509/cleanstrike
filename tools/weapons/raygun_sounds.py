"""CleanStrike Weapons Pack: the Ray Gun's voice (original, synthesised).

Usage: python -I tools/weapons/raygun_sounds.py
Writes mods/WeaponsPack/CSWeaponsPack/Sounds/: raygun_fire_1..3.wav (a
descending energy chirp over a sub thump), raygun_hit_1..2.wav (plasma
crackle and whump), raygun_charge.wav (battery power-up whine). 44.1 kHz mono.
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "mods", "WeaponsPack", "CSWeaponsPack", "Sounds")
rng = np.random.default_rng(2077)


def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, attack, release, curve=2.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((t[-1] - t) / max(release, 1e-4), 0, 1) ** curve
    return a * r


def squareish(phase, harmonics=7):
    y = np.zeros_like(phase)
    for k in range(1, harmonics * 2, 2):
        y += np.sin(phase * k) / k
    return y


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def echo(x, delays=(0.045, 0.09, 0.14), gains=(0.35, 0.2, 0.1)):
    y = np.concatenate([x, np.zeros(int(0.2 * SR))])
    for d, g in zip(delays, gains):
        k = int(d * SR)
        y[k:k + len(x)] += g * x
    return y


def fire(seed):
    r = np.random.default_rng(seed)
    dur = 0.42
    t = t_of(dur)
    f0, f1 = r.uniform(1700, 2100), r.uniform(240, 320)
    f = f0 * (f1 / f0) ** (t / dur) * (1 + 0.06 * np.sin(2 * np.pi * r.uniform(30, 42) * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    zap = squareish(phase, 6) * env(len(t), 0.002, 0.3, 1.6)
    ring = np.sin(phase * 2.01) * 0.3 * env(len(t), 0.002, 0.2, 2.5)
    sub = np.sin(2 * np.pi * np.cumsum(90 * (1 - 0.4 * t / dur)) / SR) * env(len(t), 0.003, 0.25, 2.0) * 0.9
    burst = r.normal(0, 1, len(t)) * env(len(t), 0.001, 0.03, 1.0) * 0.5
    y = 0.55 * zap + ring + sub + lowpass(burst, 6000)
    return echo(y)


def hit(seed):
    r = np.random.default_rng(seed)
    dur = 0.55
    t = t_of(dur)
    noise = r.normal(0, 1, len(t))
    crackle = np.zeros(len(t))
    for _ in range(70):
        at = r.integers(0, len(t) - 400)
        ln = r.integers(60, 400)
        crackle[at:at + ln] += r.uniform(0.3, 1.0) * noise[at:at + ln]
    crackle = crackle * env(len(t), 0.001, 0.45, 1.4)
    whump = np.sin(2 * np.pi * np.cumsum(70 + 80 * np.exp(-t * 18)) / SR) * env(len(t), 0.002, 0.3, 2.0)
    chirp = np.sin(2 * np.pi * np.cumsum(600 + 2200 * t / dur) / SR) * env(len(t), 0.005, 0.15, 2.0) * 0.25
    return echo(0.6 * lowpass(crackle, 7000) + whump + chirp, (0.06, 0.12), (0.25, 0.12))


def charge():
    dur = 1.1
    t = t_of(dur)
    f = 180 * (720 / 180) ** (t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = squareish(phase, 4) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)) * env(len(t), 0.25, 0.12, 1.0)
    y += 0.3 * np.sin(phase * 1.5) * env(len(t), 0.4, 0.1, 1.0)
    click = np.zeros(len(t))
    click[int(0.95 * SR):int(0.95 * SR) + 200] = rng.normal(0, 1, 200)
    return 0.5 * y + click


def save(name, y, gain=0.85):
    os.makedirs(OUT, exist_ok=True)
    y = np.tanh(1.6 * y / (np.max(np.abs(y)) + 1e-9))
    y = y / (np.max(np.abs(y)) + 1e-9) * gain
    data = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    for i in range(3):
        save("raygun_fire_%d" % (i + 1), fire(10 + i), 0.9)
    for i in range(2):
        save("raygun_hit_%d" % (i + 1), hit(20 + i), 0.8)
    save("raygun_charge", charge(), 0.6)
    print("wrote", sorted(os.listdir(OUT)))
