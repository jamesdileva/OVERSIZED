"""SFX + boss music generator (Sprint 3.2 audio lane).

Generates the demo-tier SFX set (procedural chiptune/noise sounds) and an
intense boss loop. All 16-bit mono WAVs at 22050 Hz; AudioBus registers
voice limits and per-id retrigger intervals for these.

Usage: python -I tests/gen_sfx.py   (writes into assets/audio/sfx + music/)
"""
import math
import os
import struct

RATE = 22050
OUT_SFX = "assets/audio/sfx"
OUT_MUSIC = "assets/audio/music"


def write_wav(path, samples):
    data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
    hdr = b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE" + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(hdr + b"data" + struct.pack("<I", len(data)) + data)
    print("wrote", path, f"({len(samples) / RATE:.2f}s)")


def env(i, n, attack=0.02, release=0.6):
    """Simple attack/release envelope over n samples."""
    t = i / n
    if t < attack:
        return t / attack
    if t > 1.0 - release:
        return max(0.0, (1.0 - t) / release)
    return 1.0


def noise(seconds, vol=0.3, decay=1.0, lp=0.2):
    out = []
    prev = 0.0
    n = int(seconds * RATE)
    for i in range(n):
        v = (float((i * 7919 + 104729) % 65536) / 32768.0 - 1.0)
        prev = prev * (1.0 - lp) + v * lp
        out.append(prev * vol * env(i, n, 0.01, release=decay))
    return out


def sweep(f0, f1, seconds, vol=0.25, shape="sine", decay=0.5):
    out = []
    n = int(seconds * RATE)
    for i in range(n):
        t = i / n
        freq = f0 + (f1 - f0) * t
        ph = freq * i / RATE
        if shape == "sine":
            v = math.sin(ph * 2 * math.pi)
        elif shape == "square":
            v = 0.7 if (ph % 1.0) < 0.5 else -0.7
        else:
            v = 2.0 * (ph % 1.0) - 1.0
        out.append(v * vol * env(i, n, 0.05, release=decay))
    return out


def tone(freq, seconds, vol=0.2, shape="sine", decay=0.4):
    return sweep(freq, freq, seconds, vol, shape, decay)


def mix(*layers):
    n = max(len(x) for x in layers)
    return [sum(x[i] if i < len(x) else 0.0 for x in layers) / max(len(layers), 1) for i in range(n)]

def seq(notes, note_len, vol=0.2, shape="sine"):
    out = []
    for freq in notes:
        if freq <= 0:
            out += [0.0] * int(note_len * RATE)
        else:
            out += tone(freq, note_len, vol, shape)
    return out


SFX = {
    "hit_light": mix(noise(0.08, 0.5, 0.9, 0.5), sweep(900, 400, 0.08, 0.2)),
    "hit_heavy": mix(noise(0.13, 0.6, 0.9, 0.35), sweep(500, 150, 0.13, 0.3)),
    "kill": mix(noise(0.2, 0.5, 0.9, 0.5), sweep(600, 80, 0.2, 0.25)),
    "xp_pickup": sweep(880, 1420, 0.12, 0.18),
    "level_up": mix(sweep(440, 880, 0.3, 0.2), sweep(660, 1320, 0.3, 0.15), sweep(880, 1760, 0.35, 0.12)),
    "wave_clear": mix(sweep(523, 784, 0.25, 0.2), tone(1046, 0.3, 0.15)),
    "dash": sweep(1200, 300, 0.15, 0.22, "triangle"),
    "player_hurt": mix(noise(0.15, 0.5, 0.8, 0.4), sweep(300, 120, 0.15, 0.3)),
    "buy": mix(sweep(987, 1318, 0.12, 0.2), tone(1568, 0.18, 0.15)),
    "evolve": mix(sweep(330, 1320, 0.5, 0.2), sweep(495, 1980, 0.5, 0.15), noise(0.5, 0.15, 0.8, 0.3)),
    "reaction_steam": noise(0.3, 0.4, 0.7, 0.6),
    "reaction_boil": mix(noise(0.3, 0.5, 0.8, 0.4), sweep(220, 60, 0.3, 0.3)),
    "boss_roar": mix(sweep(180, 60, 0.9, 0.3, "saw"), noise(0.9, 0.3, 0.7, 0.4)),
    "boss_slam": mix(noise(0.4, 0.6, 0.8, 0.4), sweep(180, 40, 0.4, 0.35)),
    "ui_select": sweep(700, 1000, 0.08, 0.15),
}


def boss_loop():   # ~13.7s intense minor drive, faster/darker than the run loop
    bass = []
    bar_notes = [92.5, 92.5, 103.83, 87.31]   # F#m-ish menace
    for rep in range(4):
        base = bar_notes[rep]
        bass += seq([base, base, base, base * 1.5, base, base * 1.335, base, base],
                    0.4375, 0.24, "square")
    arp = []
    for rep in range(4):
        base = bar_notes[rep]
        arp += seq([base * 3, base * 3.375, base * 4, base * 3, base * 3.375, base * 4, base * 4.5, base * 4],
                   0.375, 0.12, "saw")
    drive = []
    for rep in range(4):
        drive += noise(0.375, 0.06, 0.9, 0.5) * 2
    write_wav(os.path.join(OUT_MUSIC, "boss_loop.wav"), mix(bass, arp, drive))


if __name__ == "__main__":
    for name, gen in SFX.items():
        write_wav(os.path.join(OUT_SFX, name + ".wav"), gen)
    boss_loop()
    print("SFX pass complete: %d sounds + boss loop" % len(SFX))
