"""Sky Yard: schwebende Plattformen im All (Vorbild Q3DM17 The Longest Yard), ca. 72 x 114 m.

Langer Hof in der Mitte, zwei Koepfe an den Enden (CTF-Basen), Inseln seitlich und in den Ecken,
Mittelplattform mit Quad ueber dem Hof. Alles ueber Jump-Pads verbunden, darunter der Abgrund.
Aufruf aus dem Projektordner:  python tools/maps/sky_yard.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapkit import MapKit, FLOOR, ACCENT, WALK, METAL, CYAN, MAGENTA, YELLOW, ORANGE  # noqa: E402

kit = MapKit('sky_yard', 'SkyYard', sky=((0.08, 0.06, 0.2), (0.3, 0.5, 1), (0.6, 0.3, 1)))
kit.void(-25)

# --- Hof (y=0), 16 x 70 m, mit Deckung und Stuetzen ins Nichts ---
kit.platform(-8, -35, 8, 35, 0, FLOOR, glow=CYAN, thick=1.0)
for x, z in ((-4, -15), (4, 15), (4, -24), (-4, 24)):
    kit.solid(x - 1, 0, z - 1, x + 1, 1.8, z + 1, METAL)
    kit.deco(x - 1.02, 1.7, z - 1.02, x + 1.02, 1.82, z + 1.02, ORANGE)
for x in (-6, 6):
    for z in (-30, 0, 30):
        kit.pillar(x, z, -14, -1, w=1.4, glow=CYAN)

# --- Koepfe (y=6) an den Enden: CTF-Basen ---
for sz in (-1, 1):
    z0, z1 = sorted((sz * 43, sz * 57))
    kit.platform(-10, z0, 10, z1, 6, ACCENT, glow=MAGENTA, thick=1.0)
    kit.pillar(-8, sz * 50, -16, 5, w=2.0, glow=MAGENTA)
    kit.pillar(8, sz * 50, -16, 5, w=2.0, glow=MAGENTA)
    kit.rail(-10, sz * 57, 10, sz * 57, 6)  # Rueckwand-Gelaender
    kit.pad(0, 0, sz * 32, 0, 6, sz * 47, apex=3.0)                 # Hof -> Kopf
    kit.pad(sz * -6, 6, sz * 45, sz * -4, 0, sz * 26, apex=2.0)     # Kopf -> Hof
    kit.spawn(0, 6, sz * 51, 180 if sz < 0 else 0)
    kit.item('armor', sz * -6, 6, sz * 53)
    kit.light(0, 10, sz * 50, (1, 0.25, 0.8), 3.0, 14)

# --- Seiteninseln (y=10): West mit Mega Health, Ost mit Railgun ---
for sx in (-1, 1):
    x0, x1 = sorted((sx * 24, sx * 36))
    kit.platform(x0, -6, x1, 6, 10, WALK, glow=YELLOW, thick=1.0)
    kit.pillar(sx * 30, 0, -12, 9, w=2.0, glow=YELLOW)
    kit.pad(sx * 6, 0, 0, sx * 30, 10, 0, apex=3.0)                 # Hof -> Insel
    kit.pad(sx * 30, 10, sx * -4, sx * 4, 0, sx * -8, apex=2.0)     # Insel -> Hof
    kit.spawn(sx * 33, 10, sx * 4, -90 * sx)
    kit.light(sx * 30, 14, 0, (1, 0.8, 0.2), 2.5, 12)
kit.item('mega', -33, 10, 0)
kit.weapon('railgun', 33, 10, 0)

# --- Mittelplattform (y=13) ueber dem Hof mit Quad ---
kit.platform(-4, -4, 4, 4, 13, ACCENT, glow=MAGENTA)
kit.pad(0, 0, 12, 0, 13, 1.5, apex=2.0)
kit.item('quad', 0, 13, 0)
kit.light(0, 16, 0, (1, 0.25, 0.8), 3.0, 12)

# --- Eckinseln (y=4) mit Leben, ueber Pads vom Hof ---
for sx in (-1, 1):
    for sz in (-1, 1):
        cx, cz = sx * 24, sz * 26
        kit.platform(cx - 3, cz - 3, cx + 3, cz + 3, 4, WALK, glow=CYAN)
        kit.pillar(cx, cz, -10, 3, w=1.2)
        kit.pad(sx * 6, 0, sz * 22, cx, 4, cz, apex=2.5)                       # Hof -> Ecke
        kit.pad(cx + sx * 1.5, 4, cz - sz * 1.5, sx * 3, 0, sz * 18, apex=2.0)  # Ecke -> Hof
        kit.item('health', cx - sx * 1.5, 4, cz + sz * 1.5)

# --- Teleporter: Kopf Nord -> Ost-Insel, Kopf Sued -> West-Insel ---
kit.tele(8, 6, -53, 30, 10, -3, 90)
kit.tele(-8, 6, 53, -30, 10, 3, -90)

# --- Waffen, Munition, Spawns im Hof ---
kit.weapon('rocket_launcher', 0, 0, 0)
kit.weapon('plasma', 6, 6, -49)
kit.weapon('lightning', -6, 6, 49)
kit.weapon('shock_rifle', 0, 0, -20)
kit.weapon('shotgun', 0, 0, 20)
for z in (-28, 28):
    kit.item('ammo', 5, 0, z)
kit.item('health', -5, 0, -8)
kit.item('health', 5, 0, 8)
for x, z, yaw in ((-5, -12, 0), (5, 12, 180), (5, -28, 0), (-5, 28, 180)):
    kit.spawn(x, 0, z, yaw)
kit.light(0, 5, -20, (0.2, 0.85, 1), 2.0, 14)
kit.light(0, 5, 20, (0.2, 0.85, 1), 2.0, 14)

kit.write()
