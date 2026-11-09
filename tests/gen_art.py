"""Procedural pixel-art + music generator (Sprint 3.1 art lane).

Generates placeholder-final pixel sprites (ASCII-art defined, nearest-filter
in engine) and two looping chiptune-style music tracks. The art-timing
exercise from implementation-guide §16.1 logs the generation time — see the
Sprint 3.1 worklog entry for the rescaled estimate.

Usage: python -I tests/gen_art.py   (writes into assets/)
"""
import io
import math
import struct
import zlib
import os

OUT_SPRITES = "assets/sprites"
OUT_MUSIC = "assets/audio/music"
RATE = 22050


# --- minimal PNG writer (RGBA, no external deps) -------------------------------

def write_png(path, width, height, rgba_rows):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b""
    for row in rgba_rows:
        raw += b"\x00" + bytes(v for px in row for v in px)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", path)


def render_ascii(name, art, palette):
    """art: list of equal-length strings; palette: char -> (r, g, b, a)."""
    h = len(art)
    w = len(art[0])
    rows = []
    for line in art:
        row = []
        for ch in line:
            row.append(palette.get(ch, (0, 0, 0, 0)))
        rows.append(row)
    write_png(os.path.join(OUT_SPRITES, name + ".png"), w, h, rows)


# --- sprites (ASCII defined; . = transparent) ----------------------------------

HERO = [  # 16x16 knight, facing right, held-sword pose reads with the blade draw
    "......gggg......",
    ".....gwwwwg.....",
    ".....gwwwwg.....",
    ".....gddddg.....",
    "......gggg......",
    ".....gggggg.....",
    "....gggggggg....",
    "...gggggggggg...",
    "...ggdgggdggg...",
    "...gggggggggg...",
    "....gggggggg....",
    "....gg....gg....",
    "...gg......gg...",
    "..gg........gg..",
    "..gg........gg..",
    "..dd........dd..",
]
HERO_PAL = {"g": (58, 62, 84, 255), "w": (150, 168, 205, 255), "d": (30, 32, 46, 255)}

CHASER = [  # 12x12 red imp
    "............",
    "..r......r..",
    ".rrr....rrr.",
    ".rrrr..rrrr.",
    "..rrrrrrrr..",
    ".rrrwwrrrrr.",
    "rrrdwwrrrrrr",
    "rrrrrrrrrrrr",
    ".rrrrrrrrrr.",
    "..rrrrrrrr..",
    "...rr..rr...",
    "............",
]
CHASER_PAL = {"r": (178, 48, 38, 255), "d": (96, 22, 18, 255), "w": (240, 235, 225, 255)}

SWARMER = [  # 12x12 orange wasp-ish swarm unit
    "ww........ww",
    ".www....www.",
    "..rrrrrrrr..",
    ".rrrrrrrrrr.",
    "..rrrrrrrr..",
    ".rrrrrrrrrr.",
    "..rrrrrrrr..",
    ".rrrrrrrrrr.",
    "..rrrrrrrr..",
    "....r..r....",
    "............",
    "............",
]
SWARMER_PAL = {"r": (200, 90, 30, 255), "w": (235, 225, 200, 180)}

SPRINTER = [  # 12x12 lean yellow streak
    "............",
    "............",
    "....yyyy....",
    "...yyyyyy...",
    "..yyyyyyyy..",
    "...yywwyy...",
    "..yyyyyyyy..",
    "...yyyyyy...",
    "....yyyy....",
    "...yy..yy...",
    "..yy....yy..",
    "............",
]
SPRINTER_PAL = {"y": (215, 175, 55, 255), "w": (245, 240, 220, 255)}

BRUTE = [  # 12x12 horned dark tank
    "dd........dd",
    "ddd......ddd",
    ".dddddddddd.",
    "dddddddddddd",
    "ddrrwwwwrrdd",
    "ddrrwwwwrrdd",
    ".dddddddddd.",
    ".dddddddddd.",
    "..dddddddd..",
    "..dd.dd.dd..",
    ".ddd....ddd.",
    "............",
]
BRUTE_PAL = {"d": (72, 34, 30, 255), "r": (130, 40, 34, 255), "w": (210, 200, 190, 255)}

SPITTER = [  # 12x12 pink, open mouth
    "............",
    "...pppppp...",
    "..pppppppp..",
    ".pppmmmmppp.",
    ".ppmmwwmmpp.",
    ".ppppppppppp",
    ".ppppppppp..",
    "..pppppppp..",
    "...pppppp...",
    "....p..p....",
    "............",
    "............",
]
SPITTER_PAL = {"p": (186, 68, 122, 255), "m": (60, 14, 30, 255), "w": (235, 220, 230, 255)}

POPPER = [  # 12x12 yellow round with fuse
    "........ff..",
    ".......f....",
    "....yyyy....",
    "..yyyyyyyy..",
    ".yyyyyyyyyy.",
    ".yyyddyyyyy.",
    ".yyydwyyyyy.",
    ".yyyyyyyyyy.",
    ".yyyyyyyyyy.",
    "..yyyyyyyy..",
    "....yyyy....",
    "............",
]
POPPER_PAL = {"y": (216, 168, 44, 255), "d": (110, 82, 20, 255), "w": (245, 240, 225, 255), "f": (240, 140, 60, 255)}

SPLITTER = [  # 12x12 violet-pink blob with a split seam
    "............",
    "...vv..vv...",
    "..vvvvvvvv..",
    ".vvvvddvvvv.",
    ".vvvddddvvv.",
    "vvvvdwwdvvvv",
    "vvvvddddvvvv",
    ".vvvddddvvv.",
    ".vvvvddvvvv.",
    "..vvvvvvvv..",
    "...vv..vv...",
    "............",
]
SPLITTER_PAL = {"v": (150, 62, 110, 255), "d": (70, 26, 52, 255), "w": (225, 200, 220, 255)}

SHARD = [  # 8x8 tiny fragment
    "..vv.....",
    ".vvvv....",
    "vvvdvvv..",
    ".vvvvvvv.",
    "..vvvdvv.",
    "....vv...",
    ".........",
    ".........",
]
SHARD_PAL = {"v": (150, 62, 110, 255), "d": (70, 26, 52, 255)}

WASP = [  # 12x12 yellow-black striped ranged
    "............",
    "...yy..yy...",
    "..yybbbbbb..",
    ".yybybybyby.",
    "..yybbbbbb..",
    ".yybybybyby.",
    "..yybbbbbb..",
    "...yy..yy...",
    "....y..y....",
    "............",
    "............",
    "............",
]
WASP_PAL = {"y": (216, 190, 70, 255), "b": (50, 44, 30, 255)}

GOLEM = [  # 12x12 gray rock giant
    "gggggggggggg",
    "gggggggggggg",
    "gggddggddggg",
    "gggdwdgwdggg",
    "gggggggggggg",
    "gggggggggggg",
    "gggggggggggg",
    "ggg.gggg.ggg",
    "gggg.gg.gggg",
    "gggg.gg.gggg",
    "gggg.gg.gggg",
    "ddd..dd..ddd",
]
GOLEM_PAL = {"g": (110, 110, 120, 255), "d": (60, 60, 70, 255), "w": (150, 150, 165, 255)}

VOLATILE = [  # 12x12 cracked orange bomb
    "....oooo....",
    "..oooooooo..",
    ".oooo..oooo.",
    ".oooo..oooo.",
    "ooooocccoooo",
    "ooooocccoooo",
    ".oooocccooo.",
    ".oooooooooo.",
    "..oooooooo..",
    "..ooo..ooo..",
    "....oooo....",
    "............",
]
VOLATILE_PAL = {"o": (200, 100, 40, 255), "c": (255, 190, 90, 255)}

SPRITES = [
    ("hero", HERO, HERO_PAL),
    ("enemies/chaser", CHASER, CHASER_PAL),
    ("enemies/swarmer", SWARMER, SWARMER_PAL),
    ("enemies/sprinter", SPRINTER, SPRINTER_PAL),
    ("enemies/brute", BRUTE, BRUTE_PAL),
    ("enemies/spitter", SPITTER, SPITTER_PAL),
    ("enemies/popper", POPPER, POPPER_PAL),
    ("enemies/splitter", SPLITTER, SPLITTER_PAL),
    ("enemies/splitter_shard", SHARD, SHARD_PAL),
    ("enemies/wasp", WASP, WASP_PAL),
    ("enemies/golem", GOLEM, GOLEM_PAL),
    ("enemies/volatile", VOLATILE, VOLATILE_PAL),
]


# --- music (simple chiptune loops, 16-bit mono WAV) ----------------------------

def write_wav(path, samples):
    data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
    hdr = b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE" + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(hdr + b"data" + struct.pack("<I", len(data)) + data)
    print("wrote", path, f"({len(samples) / RATE:.1f}s)")


def tone(freq, seconds, vol=0.2, shape="sine"):
    out = []
    for i in range(int(seconds * RATE)):
        ph = freq * i / RATE
        if shape == "sine":
            v = math.sin(ph * 2 * math.pi)
        elif shape == "square":
            v = 0.7 if (ph % 1.0) < 0.5 else -0.7
        else:
            v = 2.0 * (ph % 1.0) - 1.0
        out.append(v * vol)
    return out


def mix(*layers):
    n = max(len(x) for x in layers)
    return [sum(x[i] if i < len(x) else 0.0 for x in layers) / max(len(layers), 1) for i in range(n)]


def seq(notes, note_len, vol=0.2, shape="sine"):
    out = []
    for freq in notes:
        if freq <= 0:
            out += [0.0] * int(note_len * RATE)   # rests
        else:
            out += tone(freq, note_len, vol, shape)
    return out


def menu_loop():   # 24s slow ambient pad progression: Am F C G
    bars = []
    chords = [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
    for chord in chords:
        layers = [tone(f, 6.0, 0.10) for f in chord]
        layers.append(tone(chord[0] / 2.0, 6.0, 0.12))
        bars += mix(*layers)
    write_wav(os.path.join(OUT_MUSIC, "menu_loop.wav"), bars)


def run_loop():   # ~25.8s driving bass + arp
    bass = []
    bar_notes = [110.0, 110.0, 146.83, 98.0]
    for rep in range(4):
        base = bar_notes[rep]
        bass += seq([base, base, base * 1.5, base, base, base * 1.335], 0.75, 0.22, "square")
    arp = []
    for rep in range(4):
        base = bar_notes[rep]
        arp += seq([base * 2, base * 2.5, base * 3, base * 2.5, base * 2, base * 3, base * 4, base * 2.5],
                   0.375, 0.10, "sine")
    write_wav(os.path.join(OUT_MUSIC, "run_loop.wav"), mix(bass, arp))


if __name__ == "__main__":
    for name, art, pal in SPRITES:
        render_ascii(name, art, pal)
    menu_loop()
    run_loop()
    print("generation complete (art-timing exercise: 12 sprites + 2 loops, scripted)")
